// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// -------------------
// Compatibility
// TC Router V4
// -------------------

import {Owners} from "../../lib/Owners.sol";
import {Executors} from "../../lib/Executors.sol";
import {SafeTransferLib} from "../../lib/SafeTransferLib.sol";
import {IERC20} from "../../interfaces/IERC20.sol";
import {IThorchainRouterV4} from "../../interfaces/IThorchainRouterV4.sol";

contract TSFeeDistributor_V1 is Owners, Executors {
    using SafeTransferLib for address;

    IThorchainRouterV4 public tcRouter;

    IERC20 public feeAsset;
    uint256 private _communityDistribution;

    uint32 public treasuryBps;
    uint32 public communityBps;
    uint32 public treasuryIndex;
    uint32 public communityIndex;

    // add transfer option for erc20s instead of tcRouter.depositWithExpiry

    mapping(uint32 => string) public memoTreasury;
    mapping(uint32 => string) public memoCommunity;

    event TreasuryDistribution(uint256 amount, string memo);
    event CommunityDistribution(uint256 amount, string memo);

    constructor(address _tcRouterAddress, address _feeAsset) {
        treasuryBps = 2500;
        communityBps = 7500;
        _communityDistribution = 0;
        
        tcRouter = IThorchainRouterV4(_tcRouterAddress);
        feeAsset = IERC20(_feeAsset);

        _feeAsset.safeApprove(_tcRouterAddress, 0);
        _feeAsset.safeApprove(_tcRouterAddress, type(uint256).max);

        _setOwner(msg.sender, true);
    }

    function setTCRouter(address _tcRouterAddress) external isOwner {
        tcRouter = IThorchainRouterV4(_tcRouterAddress);
    }

    function setShares(uint32 treasury, uint32 community) external isOwner {
        require(treasury + community == 10000, "Shares must add up to 10000");
        treasuryBps = treasury;
        communityBps = community;
    }

    function getMemoTreasury(uint32 id) external view returns (string memory) {
        return memoTreasury[id];
    }

    function setMemoTreasury(uint32 id, string memory memo) external isOwner {
        memoTreasury[id] = memo;
    }

    function setTreasuryIndex(uint32 index) external isOwner {
        treasuryIndex = index;
    }

    function getMemoCommunity(uint32 id) external view returns (string memory) {
        return memoCommunity[id];
    }

    function setMemoCommunity(uint32 id, string memory memo) external isOwner {
        memoCommunity[id] = memo;
    }

    function setCommunityIndex(uint32 index) external isOwner {
        communityIndex = index;
    }

    function distributeTreasury(address inboundAddress) public isExecutor {
        require(_communityDistribution == 0, "It's the community's turn to receive distribution");
        uint256 balance = feeAsset.balanceOf(address(this));

        uint256 treasuryAmount = balance * treasuryBps / 10000;
        _communityDistribution = balance - treasuryAmount;

        tcRouter.depositWithExpiry{value: 0}(
            payable(inboundAddress),
            address(feeAsset),
            treasuryAmount,
            memoTreasury[treasuryIndex],
            type(uint256).max
        );

        emit TreasuryDistribution(treasuryAmount, memoTreasury[treasuryIndex]);
    }

    function distributeCommunity(address inboundAddress) public isExecutor {
        require(_communityDistribution > 0, "No community distribution available");
        require(_communityDistribution <= feeAsset.balanceOf(address(this)), "Community distribution exceeds balance");

        tcRouter.depositWithExpiry{value: 0}(
            payable(inboundAddress),
            address(feeAsset),
            _communityDistribution,
            memoCommunity[communityIndex],
            type(uint256).max
        );

        emit CommunityDistribution(_communityDistribution, memoCommunity[communityIndex]);

        _communityDistribution = 0;
    }
}
