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
    // "treasuryBps + communityBps = 10000" (100%).
    uint16 public treasuryBps; // e.g. 2500 = 25%
    uint16 public communityBps; // e.g. 7500 = 75%
    uint256 public rewardAmountThreshold;

    // Within the community portion, split among uThor, yThor, vThor, thorPool.
    // Example: If communityBps = 7500, and uThorBps=1000, yThorBps=3000, vThorBps=2000, thorPoolBps=1500,
    // that totals 7500.
    uint16 public uThorBps;
    uint16 public yThorBps;
    uint16 public vThorBps;
    uint16 public thorPoolBps;

    // ------------------------------------------------------
    // Events
    // ------------------------------------------------------
    event Distribution(
        uint256 amount,
        uint16 poolBps,
        uint16 uThorBps,
        uint16 vThorBps,
        uint16 yThorBps
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
        treasuryBps = 2500;
        communityBps = 7500;

        // Approve Thorchain router to spend feeAsset
        feeAsset.approve(_tcRouterAddress, type(uint256).max);
        feeAsset.approve(_uThorToken, type(uint256).max);
        feeAsset.approve(_yThorToken, type(uint256).max);

        // Basic config
        rewardAmountThreshold = 30_000_000_000; // 30k usdc
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
     * @notice Set the top-level treasury/community BPS split. Must total 10000.
     */
    function setShares(
        uint16 _treasuryBps,
        uint16 _communityBps
    ) external isOwner {
        require(
            _treasuryBps + _communityBps == 10000,
            "Shares must add up to 10000"
        );
        treasuryBps = _treasuryBps;
        communityBps = _communityBps;
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

        uint256 total = uBal + yBal + vBal + pBal;
        require(total > 0, "No THOR tokens in any recipient contract");

        uThorBps = uint16((uBal * communityBps) / total);
        yThorBps = uint16((yBal * communityBps) / total);
        vThorBps = uint16((vBal * communityBps) / total);
        thorPoolBps = communityBps - (uThorBps + yThorBps + vThorBps);
        require(thorPoolBps > 0, "ThorPool BPS must be > 0");
    }

    function distribute(address inboundAddress) public isExecutor {
        updateCommunitySplitsByTHORBalance();

        // 1. Check USDC balance and check its above threshold
        uint256 balance = feeAsset.balanceOf(address(this));
        require(balance >= rewardAmountThreshold, "Balance below threshold");

        // 2. Compute Treasury portion
        uint256 treasuryAmount = (balance * treasuryBps) / 10000;
        uint256 communityAmount = balance - treasuryAmount;

        // 3. Treasury transfer
        feeAsset.transfer(treasuryWallet, treasuryAmount);

        // 4. Split the community amount into sub-allocations
        uint256 uPortion = (communityAmount * uThorBps) / 10000;
        uint256 yPortion = (communityAmount * yThorBps) / 10000;
        uint256 vPortion = (communityAmount * vThorBps) / 10000;
        uint256 pPortion = (communityAmount * thorPoolBps) / 10000;
        uint256 swapBackToRunePortion = vPortion + pPortion; // single chunk for Thorchain

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
        emit Distribution(balance, thorPoolBps, uThorBps, vThorBps, yThorBps);
    }
}
