// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// -------------------
// Compatibility
// TC Router V4
// TS Memo Generator V1
// -------------------

import {Owners} from "../../lib/Owners.sol";
import {SafeTransferLib} from "../../lib/SafeTransferLib.sol";
import {IERC20} from "../../interfaces/IERC20.sol";
import {IThorchainRouterV4} from "../../interfaces/IThorchainRouterV4.sol";
import {TSAggregator_V3} from "../abstract/TSAggregator_V3.sol";
import {TSMemoGenLedger_V1} from "../abstract/TSMemoGenLedger_V1.sol";

contract TSWrapperLedger_V1 is Owners, TSAggregator_V3, TSMemoGenLedger_V1 {
    using SafeTransferLib for address;

    IThorchainRouterV4 public tcRouter;

    constructor(address _ttp, address _tcRouter) TSAggregator_V3(_ttp) {
        tcRouter = IThorchainRouterV4(_tcRouter);
        _setOwner(msg.sender, true);
    }

    function swapExplicit(
        address payable vault,
        address inAsset,
        uint amount,
        uint expiration,
        string calldata outAsset,
        string calldata destinationAddress,
        string calldata limit,
        string calldata affiliate,
        string calldata memoFee
    ) public payable nonReentrant {
        string memory memo = swapMemo(
            outAsset,
            destinationAddress,
            limit,
            affiliate,
            memoFee
        );

        uint safeAmount;
        if (inAsset == address(0)) {
            safeAmount = takeFeeGas(msg.value);

            tcRouter.depositWithExpiry{value: safeAmount}(
                vault,
                inAsset,
                safeAmount,
                memo,
                expiration
            );
        } else {
            safeAmount = takeFeeToken(inAsset, amount);
            tcRouter.depositWithExpiry{value: 0}(
                vault,
                inAsset,
                safeAmount,
                memo,
                expiration
            );
        }
    }

    // TCRouterV4 only support swapOut with gas assets
    function swapOut(
        address token,
        address to,
        uint256 amountOutMin
    ) public payable nonReentrant {
        uint safeAmount = takeFeeGas(msg.value);
        to.safeTransferETH(safeAmount);
    }
}
