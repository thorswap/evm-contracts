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

contract TSFeeDistributor_V3 is Owners, Executors {
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
    uint256 public rewardAmountThreshold;
    uint32 public uThorPreciseBps;
    uint32 public yThorPreciseBps;
    uint32 public vThorPreciseBps;
    uint32 public thorPoolPreciseBps;

    // ------------------------------------------------------
    // Events
    // ------------------------------------------------------
    event Distribution(
        uint256 amount,
        uint32 poolBps,
        uint32 uThorBps,
        uint32 vThorBps,
        uint32 yThorBps
    );

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
        rewardAmountThreshold = 20_000_000_000; // 20k usdc
        treasuryWallet = _treasuryWallet;

        // Setup owners/executors
        _setOwner(msg.sender, true);
    }

    // ------------------------------------------------------
    // Owner Setters
    // ------------------------------------------------------
    function setThreshold(uint256 amount) external isOwner {
        rewardAmountThreshold = amount;
    }

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

    function updateCommunitySplitsByTHORBalance() private {
        require(address(thorToken) != address(0), "THOR token not set");

        uint256 uBal = thorToken.balanceOf(address(uThorToken));
        uint256 vBal = thorToken.balanceOf(address(vThorToken));
        uint256 yBal = thorToken.balanceOf(address(yThorToken));
        uint256 pBal = thorToken.balanceOf(address(tcRouter));

        uint256 totalBalAssetAmount = (uBal + yBal + vBal + pBal);

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

    function distribute(address inboundAddress) public isExecutor {
        updateCommunitySplitsByTHORBalance();
        uint32 preciseBps = 10_000_000;

        // 1. Check USDC balance and check its above threshold
        uint256 balance = feeAsset.balanceOf(address(this));
        require(balance >= rewardAmountThreshold, "Balance below threshold");

        // 2. Compute Treasury portion
        uint256 treasuryAmount = (balance * treasuryPreciseBps) / preciseBps;

        // 3. Treasury transfer
        feeAsset.transfer(treasuryWallet, treasuryAmount);

        // 4. Split the community amount into sub-allocations
        uint256 uPortion = (balance * uThorPreciseBps) / preciseBps;
        uint256 yPortion = (balance * yThorPreciseBps) / preciseBps;
        uint256 swapBackToRunePortion = balance -
            (treasuryAmount + uPortion + yPortion); // vPortion and pPortion combined

        // 5. Send USDC to uThor & yThor via depositRewards()
        IRewardsReceiver(address(uThorToken)).depositRewards(uPortion);
        IRewardsReceiver(address(yThorToken)).depositRewards(yPortion);

        // 6. Send the combined vThor + thorPool portion to Thorchain
        tcRouter.depositWithExpiry{value: 0}(
            payable(inboundAddress),
            address(feeAsset),
            swapBackToRunePortion,
            "=:r:t:0/1/0:t:0",
            type(uint256).max
        );

        // 7. Emit a single event summarizing the distribution
        emit Distribution(
            balance,
            thorPoolPreciseBps,
            uThorPreciseBps,
            vThorPreciseBps,
            yThorPreciseBps
        );
    }
}
