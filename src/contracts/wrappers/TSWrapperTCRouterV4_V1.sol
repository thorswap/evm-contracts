// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// -------------------
// Compatibility
// TC Router V4
// -------------------

import {Owners} from "../../lib/Owners.sol";
import {SafeTransferLib} from "../../lib/SafeTransferLib.sol";
import {IERC20} from "../../interfaces/IERC20.sol";
import {IThorchainRouterV4} from "../../interfaces/IThorchainRouterV4.sol";
import {TSAggregator_V3} from "../abstract/TSAggregator_V3.sol";

contract TSWrapperTCRouterV4_V1 is Owners, TSAggregator_V3 {
    using SafeTransferLib for address;

    IThorchainRouterV4 public tcRouter;

    constructor(address _ttp, address _tcRouter) TSAggregator_V3(_ttp) {
        tcRouter = IThorchainRouterV4(_tcRouter);
        _setOwner(msg.sender, true);
    }

    function wrapDeposit(
        address payable vault,
        address asset,
        uint amount,
        string memory memo,
        uint expiration
    ) public payable nonReentrant {
        uint safeAmount;
        if (asset == address(0)) {
            safeAmount = takeFeeGas(msg.value);
        } else {
            safeAmount = takeFeeToken(asset, amount);
        }

        tcRouter.depositWithExpiry{value: asset == address(0) ? safeAmount : 0}(
            vault,
            asset,
            safeAmount,
            memo,
            expiration
        );
    }

    // TCRouterV4 only support swapOut with gas assets
    function swapOut(
        address token,
        address to,
        uint256 amountOutMin
    ) public payable nonReentrant {
        uint256 safeAmount = takeFeeGas(msg.value);
        to.safeTransferETH(safeAmount);
    }
}
