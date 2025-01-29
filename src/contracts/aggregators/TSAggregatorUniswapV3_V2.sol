// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Owners} from "../../lib/Owners.sol";
import {SafeTransferLib} from "../../lib/SafeTransferLib.sol";
import {IWETH9} from "../../interfaces/IWETH9.sol";
import {IThorchainRouterV4} from "../../interfaces/IThorchainRouterV4.sol";
import {IUniswapRouterV3} from "../../interfaces/IUniswapRouterV3.sol";
import {TSAggregator_V5} from "../abstract/TSAggregator_V5.sol";

contract TSAggregatorUniswapV3_V2 is TSAggregator_V5 {
    using SafeTransferLib for address;

    IWETH9 public weth;
    uint24 public poolFee;
    IUniswapRouterV3 public swapRouter;

    event SwapIn(
        address from,
        address token,
        uint256 amount,
        uint256 out,
        uint256 fee,
        address vault,
        string memo
    );
    event SwapOut(address to, address token, uint256 amount, uint256 fee);

    constructor(
        address _ttp,
        address _weth,
        address _swapRouter,
        uint24 _poolFee
    ) TSAggregator_V5(_ttp) {
        weth = IWETH9(_weth);
        poolFee = _poolFee;
        swapRouter = IUniswapRouterV3(_swapRouter);
    }

    function swapIn(
        address router,
        address vault,
        string calldata memo,
        address token,
        uint amount,
        uint amountOutMin,
        uint deadline
    ) public nonReentrant {
        tokenTransferProxy.transferTokens(
            token,
            msg.sender,
            address(this),
            amount
        );
        token.safeApprove(address(swapRouter), 0); // USDT quirk
        token.safeApprove(address(swapRouter), amount);

        uint out = swapRouter.exactInputSingle(
            IUniswapRouterV3.ExactInputSingleParams({
                tokenIn: token,
                tokenOut: address(weth),
                fee: poolFee,
                recipient: address(this),
                deadline: deadline,
                amountIn: amount,
                amountOutMinimum: amountOutMin,
                sqrtPriceLimitX96: 0
            })
        );
        weth.withdraw(out);

        {
            uint256 outMinusFee = takeFeeGas(out);
            IThorchainRouterV4(router).depositWithExpiry{value: outMinusFee}(
                payable(vault),
                address(0),
                outMinusFee,
                memo,
                deadline
            );
        }
        emit SwapIn(
            msg.sender,
            token,
            amount,
            out + getFee(out),
            getFee(out),
            vault,
            memo
        );
    }

    function swapOut(
        address token,
        address to,
        uint256 amountOutMin
    ) public payable nonReentrant {
        uint256 amount = takeFeeGas(msg.value);
        weth.deposit{value: amount}();
        address(weth).safeApprove(address(swapRouter), amount);
        swapRouter.exactInputSingle(
            IUniswapRouterV3.ExactInputSingleParams({
                tokenIn: address(weth),
                tokenOut: token,
                fee: poolFee,
                recipient: to,
                deadline: type(uint).max,
                amountIn: amount,
                amountOutMinimum: amountOutMin,
                sqrtPriceLimitX96: 0
            })
        );
        emit SwapOut(to, token, msg.value, msg.value - amount);
    }
}
