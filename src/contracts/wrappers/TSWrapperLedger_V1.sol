// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// -------------------
// Compatibility
// TC Router V4
// TS Memo Generator Ledger V1
// -------------------

import {Owners} from "../../lib/Owners.sol";
import {SafeTransferLib} from "../../lib/SafeTransferLib.sol";
import {IERC20} from "../../interfaces/IERC20.sol";
import {IThorchainRouterV4} from "../../interfaces/IThorchainRouterV4.sol";
import {IUniswapRouterV2} from "../../interfaces/IUniswapRouterV2extended.sol";
import {TSAggregator_V3} from "../abstract/TSAggregator_V3.sol";
import {TSMemoGenLedger_V1} from "../abstract/TSMemoGenLedger_V1.sol";

contract TSWrapperLedger_V1 is Owners, TSAggregator_V3, TSMemoGenLedger_V1 {
    using SafeTransferLib for address;

    address public weth;
    IThorchainRouterV4 public tcRouter;
    IUniswapRouterV2 public swapRouter;

    mapping(address => bool) public taxedTokens;
    mapping(address => bool) public feeTokens;

    event SwapIn(
        address from,
        address token,
        uint256 amount,
        uint256 aggAmount,
        address vault,
        string memo
    );

    event SwapOut(address to, address token, uint256 amount);

    constructor(
        address _ttp,
        address _weth,
        address _swapRouter,
        address _tcRouter
    ) TSAggregator_V3(_ttp) {
        weth = _weth;
        tcRouter = IThorchainRouterV4(_tcRouter);
        swapRouter = IUniswapRouterV2(_swapRouter);
        _setOwner(msg.sender, true);
    }

    function setTaxedToken(address token, bool value) external isOwner {
        taxedTokens[token] = value;
    }

    function setFeeToken(address token, bool value) external isOwner {
        feeTokens[token] = value;
    }

    function thorchainSwap(
        address payable vault,
        address inAsset,
        uint amount,
        uint expiration,
        string calldata outAsset,
        string calldata destinationAddress,
        string calldata limit,
        string calldata affiliate
    ) public payable nonReentrant {
        string memory memo = swapMemo(
            outAsset,
            destinationAddress,
            limit,
            affiliate
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

    function thorchainSwapIn(
        address vault,
        address token,
        uint amount,
        uint amountOutMin,
        uint deadline,
        string calldata outAsset,
        string calldata destinationAddress,
        string calldata limit,
        string calldata affiliate
    ) public nonReentrant {
        tokenTransferProxy.transferTokens(
            token,
            msg.sender,
            address(this),
            amount
        );
        token.safeApprove(address(swapRouter), 0); // USDT quirk
        token.safeApprove(address(swapRouter), amount);

        string memory memo = swapMemo(
            outAsset,
            destinationAddress,
            limit,
            affiliate
        );

        address[] memory path = new address[](2);
        path[0] = token;
        path[1] = weth;

        if (taxedTokens[token]) {
            swapRouter.swapExactTokensForETH(
                amount,
                amountOutMin,
                path,
                address(this),
                deadline
            );
        } else {
            swapRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
                amount,
                amountOutMin,
                path,
                address(this),
                deadline
            );
        }

        {
            uint256 outMinusFee;
            if (feeTokens[token]) {
                outMinusFee = takeFeeGas(takeFeeGas(address(this).balance));
            } else {
                outMinusFee = address(this).balance;
            }

            tcRouter.depositWithExpiry{value: outMinusFee}(
                payable(vault),
                address(0),
                outMinusFee,
                memo,
                deadline
            );
            emit SwapIn(msg.sender, token, amount, outMinusFee, vault, memo);
        }
    }

    function swapOut(
        address token,
        address to,
        uint256 amountOutMin
    ) public payable nonReentrant {
        uint256 amount = takeFeeGas(msg.value);
        address[] memory path = new address[](2);
        path[0] = weth;
        path[1] = token;

        if (taxedTokens[token]) {
            swapRouter.swapExactETHForTokensSupportingFeeOnTransferTokens{
                value: amount
            }(
                _parseAmountOutMin(amountOutMin),
                path,
                to,
                type(uint).max // deadline
            );
        } else {
            swapRouter.swapExactETHForTokens{value: amount}(
                _parseAmountOutMin(amountOutMin),
                path,
                to,
                type(uint).max // deadline
            );
        }

        emit SwapOut(to, token, msg.value);
    }
}
