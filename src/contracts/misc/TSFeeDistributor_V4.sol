// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Owners} from "../../lib/Owners.sol";
import {Executors} from "../../lib/Executors.sol";
import {SafeTransferLib} from "../../lib/SafeTransferLib.sol";
import {IERC20} from "../../interfaces/IERC20.sol";
import {IThorchainRouterV4} from "../../interfaces/IThorchainRouterV4.sol";

// Minimal interface to call depositRewards on uThor/yThor:
interface IRewardsReceiver {
    function depositRewards(uint256 amount) external;
}

/**
 * @title TSFeeDistributor_V4
 * @notice Two-phase distribution system to prevent double-dipping vulnerability
 * @dev Phase 1: swapToRune() prepares cross-chain swaps and stores distribution amounts
 *      Phase 2: distribute() executes atomic distribution using stored amounts
 */
contract TSFeeDistributor_V4 is Owners, Executors {
    using SafeTransferLib for address;

    // ------------------------------------------------------
    // External Contracts
    // ------------------------------------------------------
    IThorchainRouterV4 public tcRouter;
    IERC20 public feeAsset; // e.g., USDC
    IERC20 public thorToken; // THOR token, if needed for BPS calc
    IERC20 public uThorToken;
    IERC20 public yThorToken;
    IERC20 public vThorToken;
    address public treasuryWallet;

    // ------------------------------------------------------
    // Config
    // ------------------------------------------------------
    // "treasuryPreciseBps + communityPreciseBps = 10000000" (100%).
    uint32 public treasuryPreciseBps; // e.g. 2500bps = 2_500_000[1000bps] = 25%
    uint32 public communityPreciseBps; // e.g. 7500bps = 7_500_000[1000bps] = 75%

    // Dynamic community splits (calculated per distribution)
    uint32 public uThorPreciseBps;
    uint32 public yThorPreciseBps;
    uint32 public vThorPreciseBps;
    uint32 public thorPoolPreciseBps;

    // ------------------------------------------------------
    // Memory Management for Two-Phase Distribution
    // ------------------------------------------------------
    struct PendingDistribution {
        bool isActive;              // Whether a distribution is pending
        uint256 totalAmount;        // Total USDC amount being distributed
        uint256 treasuryAmount;     // USDC for treasury
        uint256 uThorAmount;        // USDC for uThor
        uint256 yThorAmount;        // USDC for yThor
        uint256 vThorAmount;        // Expected THOR for vThor (converted from USDC)
        uint256 thorPoolAmount;     // Expected RUNE for thorPool (converted from USDC)
        uint32 snapshotUThorBps;    // BPS at time of snapshot
        uint32 snapshotYThorBps;    // BPS at time of snapshot
        uint32 snapshotVThorBps;    // BPS at time of snapshot
        uint32 snapshotThorPoolBps; // BPS at time of snapshot
    }

    PendingDistribution public pendingDistribution;

    // ------------------------------------------------------
    // Events
    // ------------------------------------------------------
    event SwapToRuneInitiated(
        uint256 totalAmount,
        uint256 runeSwapAmount,
        uint256 thorSwapAmount,
        uint32 uThorBps,
        uint32 yThorBps,
        uint32 vThorBps,
        uint32 thorPoolBps
    );

    event Distribution(
        uint256 totalAmount,
        uint256 treasuryAmount,
        uint256 uThorAmount,
        uint256 yThorAmount,
        uint256 vThorAmount,
        uint256 thorPoolAmount
    );

    event PendingDistributionCancelled(uint256 timestamp);

    // ------------------------------------------------------
    // Constructor
    // ------------------------------------------------------
    constructor(
        address _tcRouterAddress,
        address _feeAsset,
        address _treasuryWallet,
        address _thorToken,
        address _uThorToken,
        address _vThorToken,
        address _yThorToken
    ) {
        // Initialize external references
        tcRouter = IThorchainRouterV4(_tcRouterAddress);
        feeAsset = IERC20(_feeAsset);
        thorToken = IERC20(_thorToken);
        uThorToken = IERC20(_uThorToken);
        vThorToken = IERC20(_vThorToken);
        yThorToken = IERC20(_yThorToken);

        // Default BPS (25% treasury / 75% community)
        treasuryPreciseBps = 2_500_000;
        communityPreciseBps = 7_500_000;

        // Approve Thorchain router to spend feeAsset
        feeAsset.approve(_tcRouterAddress, type(uint256).max);
        feeAsset.approve(_uThorToken, type(uint256).max);
        feeAsset.approve(_yThorToken, type(uint256).max);

        // Basic config
        treasuryWallet = _treasuryWallet;

        // Setup owners/executors
        _setOwner(msg.sender, true);
    }

    // ------------------------------------------------------
    // Owner Setters
    // ------------------------------------------------------
    function setTCRouter(address _tcRouterAddress) public isOwner {
        tcRouter = IThorchainRouterV4(_tcRouterAddress);
        feeAsset.approve(_tcRouterAddress, 0);
        feeAsset.approve(_tcRouterAddress, type(uint256).max);
    }

    /**
     * @notice Set the top-level treasury/community BPS split. Must total 10_000_000
     */
    function setShares(
        uint32 _treasuryPreciseBps,
        uint32 _communityPreciseBps
    ) external isOwner {
        require(
            _treasuryPreciseBps + _communityPreciseBps == 10_000_000,
            "Shares must add up to 10_000_000"
        );
        treasuryPreciseBps = _treasuryPreciseBps;
        communityPreciseBps = _communityPreciseBps;
    }

    function setTreasuryWallet(address _treasuryWallet) external isOwner {
        require(_treasuryWallet != address(0), "Invalid treasury wallet");
        treasuryWallet = _treasuryWallet;
    }

    /**
     * @notice Cancel a pending distribution if it's expired or stuck
     * @dev Can only be called by owner, resets pending state
     */
    function cancelPendingDistribution() external isOwner {
        require(pendingDistribution.isActive, "No pending distribution");
        delete pendingDistribution;
    }

    // ------------------------------------------------------
    // Internal Helper Functions
    // ------------------------------------------------------
    
    /**
     * @notice Calculate community splits based on current THOR token balances
     * @dev Updates the BPS allocation for each community component
     */
    function updateCommunitySplitsByTHORBalance() private {
        require(address(thorToken) != address(0), "THOR token not set");

        uint256 uBal = thorToken.balanceOf(address(uThorToken));
        uint256 vBal = thorToken.balanceOf(address(vThorToken));
        uint256 yBal = thorToken.balanceOf(address(yThorToken));
        uint256 pBal = thorToken.balanceOf(address(tcRouter));

        uint256 totalBalAssetAmount = (uBal + yBal + vBal + pBal);
        require(totalBalAssetAmount > 0, "No THOR balances found");

        uThorPreciseBps = uint32(
            ((uBal * communityPreciseBps) / totalBalAssetAmount)
        );
        yThorPreciseBps = uint32(
            ((yBal * communityPreciseBps) / totalBalAssetAmount)
        );
        vThorPreciseBps = uint32(
            ((vBal * communityPreciseBps) / totalBalAssetAmount)
        );
        thorPoolPreciseBps =
            communityPreciseBps -
            (uThorPreciseBps + yThorPreciseBps + vThorPreciseBps);
    }

    // ------------------------------------------------------
    // Phase 1: Swap feeAsset to RUNE
    // ------------------------------------------------------
    
    /**
     * @notice Phase 1: Initiate cross-chain swaps and store distribution parameters
     * @dev This function:
     *      1. Takes snapshot of current USDC balance and THOR allocations
     *      2. Calculates all distribution amounts
     *      3. Swaps required USDC to RUNE for LP donation
     *      4. Swaps required USDC to THOR for vThor rewards
     *      5. Stores all parameters for later atomic distribution
     * @param inboundAddress The Thorchain inbound address for cross-chain operations
     */
    function swapToRune(
        address inboundAddress
    ) external isExecutor {
        require(!pendingDistribution.isActive, "Distribution already pending");
        
        // 1. Check USDC balance
        uint256 balance = feeAsset.balanceOf(address(this));

        // 2. Update community splits based on current THOR balances
        updateCommunitySplitsByTHORBalance();

        uint32 preciseBps = 10_000_000;

        // 3. Calculate all distribution amounts
        uint256 treasuryAmount = (balance * treasuryPreciseBps) / preciseBps;
        uint256 uPortion = (balance * uThorPreciseBps) / preciseBps;
        uint256 yPortion = (balance * yThorPreciseBps) / preciseBps;
        uint256 vPortion = (balance * vThorPreciseBps) / preciseBps;
        uint256 poolPortion = (balance * thorPoolPreciseBps) / preciseBps;

        // 4. Store distribution parameters in memory
        pendingDistribution = PendingDistribution({
            isActive: true,
            totalAmount: balance,
            treasuryAmount: treasuryAmount,
            uThorAmount: uPortion,
            yThorAmount: yPortion,
            vThorAmount: vPortion,
            thorPoolAmount: poolPortion,
            snapshotUThorBps: uThorPreciseBps,
            snapshotYThorBps: yThorPreciseBps,
            snapshotVThorBps: vThorPreciseBps,
            snapshotThorPoolBps: thorPoolPreciseBps
        });

        // 5. Execute cross-chain swaps
        // Swap for THOR tokens (vThor rewards)
        if (vPortion + poolPortion > 0) {
            tcRouter.depositWithExpiry{value: 0}(
                payable(inboundAddress),
                address(feeAsset),
                vPortion + poolPortion,
                "=:r:t:0/1/0:t:0",
                type(uint256).max
            );
        }

        emit SwapToRuneInitiated(
            balance,
            poolPortion,
            vPortion,
            uThorPreciseBps,
            yThorPreciseBps,
            vThorPreciseBps,
            thorPoolPreciseBps
        );
    }

    // ------------------------------------------------------
    // Phase 2: Atomic Distribution
    // ------------------------------------------------------
    
    /**
     * @notice Phase 2: Execute atomic distribution using stored parameters
     * @dev This function distributes all rewards simultaneously:
     *      - USDC to treasury
     *      - USDC to uThor and yThor via depositRewards()
     *      - THOR to vThor via depositRewards() (from cross-chain swap)
     */
    function distribute() external isExecutor {
        require(pendingDistribution.isActive, "No pending distribution");
        PendingDistribution memory dist = pendingDistribution;

        // 1. Send treasury portion
        if (dist.treasuryAmount > 0) {
            feeAsset.transfer(treasuryWallet, dist.treasuryAmount);
        }

        // 2. Send USDC rewards to uThor and yThor simultaneously
        if (dist.uThorAmount > 0) {
            IRewardsReceiver(address(uThorToken)).depositRewards(dist.uThorAmount);
        }
        if (dist.yThorAmount > 0) {
            IRewardsReceiver(address(yThorToken)).depositRewards(dist.yThorAmount);
        }

        // 3. Send THOR rewards to vThor (assuming cross-chain swap completed)
        uint256 thorBalance = thorToken.balanceOf(address(this));
        if (thorBalance > 0 && dist.vThorAmount > 0) {
            thorToken.transfer(address(vThorToken), dist.vThorAmount);
        }

        // 4. Clear pending distribution state
        delete pendingDistribution;

        emit Distribution(
            dist.totalAmount,
            dist.treasuryAmount,
            dist.uThorAmount,
            dist.yThorAmount,
            thorBalance >= dist.vThorAmount ? dist.vThorAmount : thorBalance,
            dist.thorPoolAmount
        );
    }

    // ------------------------------------------------------
    // View Functions
    // ------------------------------------------------------
    
    /**
     * @notice Get current pending distribution details
     */
    function getPendingDistribution() external view returns (PendingDistribution memory) {
        return pendingDistribution;
    }

    /**
     * @notice Check if contract is ready for Phase 2 distribution
     * @dev Verifies THOR balance is sufficient for vThor rewards
     */
    function isReadyForDistribution() external view returns (bool ready, string memory reason) {
        if (!pendingDistribution.isActive) {
            return (false, "No pending distribution");
        }


        uint256 thorBalance = thorToken.balanceOf(address(this));
        if (thorBalance < pendingDistribution.vThorAmount) {
            return (false, "Insufficient THOR balance for vThor rewards");
        }

        return (true, "Ready for distribution");
    }

    /**
     * @notice Emergency function to recover stuck tokens
     * @dev Only callable by owner, only when no pending distribution
     */
    function emergencyRecoverToken(address token, uint256 amount) external isOwner {
        require(!pendingDistribution.isActive, "Cannot recover during pending distribution");
        IERC20(token).transfer(msg.sender, amount);
    }
}