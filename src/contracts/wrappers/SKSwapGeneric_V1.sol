// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {SafeTransferLib} from "../../lib/SafeTransferLib.sol";
import {SKAggregator_V1} from "../abstract/SKAggregator_V1.sol";
import {IERC20} from "../../interfaces/IERC20.sol";
import {TSAggregatorTokenTransferProxy} from "../misc/TSAggregatorTokenTransferProxy.sol";

contract SKSwapGeneric_V1 is SKAggregator_V1 {
    using SafeTransferLib for address;

    struct FeeConfig {
        uint256 feeBps; // Fee in basis points (e.g., 30 = 0.3%)
        bool feeOnInput; // true = take fee on input asset, false = take fee on output asset
        uint256 affiliateFeeBps; // Affiliate fee in basis points
        address affiliateRecipient; // Affiliate recipient address
    }

    event Swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        address recipient,
        uint256 fee,
        uint256 affiliateFee,
        bool feeOnInput
    );

    constructor(address _ttp) SKAggregator_V1(_ttp) {}

    function swap(
        address tokenIn,
        address tokenOut,
        address recipient,
        uint256 amountIn,
        address router,
        bytes calldata routerData,
        FeeConfig calldata feeConfig
    ) external payable nonReentrant returns (uint256) {
        require(isAddressKnown(router), "unknown router");
        require(recipient != address(0), "invalid recipient");
        require(amountIn > 0, "invalid amount");
        require(
            feeConfig.feeBps + feeConfig.affiliateFeeBps <= 10000,
            "fees too high"
        );

        // Process input and calculate swap amount
        uint256 swapAmount = _processInput(
            tokenIn,
            amountIn,
            router,
            feeConfig
        );

        // Snapshot balance before swap
        uint256 preBalance = tokenOut == address(0)
            ? address(this).balance
            : IERC20(tokenOut).balanceOf(address(this));

        // Execute the swap
        (bool success, ) = router.call{
            value: tokenIn == address(0) ? swapAmount : 0
        }(routerData);
        require(success, "swap failed");

        // Calculate actual output from swap
        uint256 postBalance = tokenOut == address(0)
            ? address(this).balance
            : IERC20(tokenOut).balanceOf(address(this));

        uint256 swapResult = postBalance - preBalance;
        require(swapResult > 0, "no output");

        // Process output and return final amount
        uint256 amountOut = _processOutput(
            tokenOut,
            recipient,
            swapResult,
            feeConfig
        );

        // Emit event with fee calculation
        _emitSwapEvent(
            tokenIn,
            tokenOut,
            recipient,
            amountIn,
            amountOut,
            swapResult,
            swapAmount,
            feeConfig
        );

        return amountOut;
    }

    function _processInput(
        address tokenIn,
        uint256 amountIn,
        address router,
        FeeConfig calldata feeConfig
    ) private returns (uint256 swapAmount) {
        swapAmount = amountIn;

        if (tokenIn == address(0)) {
            require(msg.value == amountIn, "ETH amount mismatch");
            if (feeConfig.feeOnInput) {
                swapAmount = _takeFeeSimple(address(0), amountIn, feeConfig);
            }
        } else {
            tokenTransferProxy.transferTokens(
                tokenIn,
                msg.sender,
                address(this),
                amountIn
            );
            if (feeConfig.feeOnInput) {
                swapAmount = _takeFeeSimple(tokenIn, amountIn, feeConfig);
            }
            _safeApprove(tokenIn, router, swapAmount);
        }
    }

    function _processOutput(
        address tokenOut,
        address recipient,
        uint256 swapResult,
        FeeConfig calldata feeConfig
    ) private returns (uint256 amountOut) {
        amountOut = swapResult;

        // Take fee on output if configured
        if (!feeConfig.feeOnInput) {
            amountOut = _takeFeeSimple(tokenOut, amountOut, feeConfig);
        }

        // Transfer to recipient
        if (tokenOut == address(0)) {
            payable(recipient).transfer(amountOut);
        } else {
            tokenOut.safeTransfer(recipient, amountOut);
        }

        return amountOut;
    }

    function _calcBps(
        uint256 bps,
        uint256 amount
    ) internal pure returns (uint256) {
        return bps == 0 ? 0 : (amount * bps) / 10000;
    }

    function _takeFeeSimple(
        address token,
        uint256 amount,
        FeeConfig calldata feeConfig
    ) private returns (uint256 amountAfterFees) {
        amountAfterFees = amount;

        // Take platform fee
        if (feeConfig.feeBps > 0) {
            if (token == address(0)) {
                amountAfterFees = takeFeeGas(feeConfig.feeBps, amountAfterFees);
            } else {
                amountAfterFees = takeFeeToken(
                    feeConfig.feeBps,
                    token,
                    amountAfterFees
                );
            }
        }

        // Take affiliate fee (independent of skRecipient)
        if (
            feeConfig.affiliateFeeBps > 0 &&
            feeConfig.affiliateRecipient != address(0)
        ) {
            uint256 affiliateFee = _calcBps(feeConfig.affiliateFeeBps, amount);
            if (token == address(0)) {
                feeConfig.affiliateRecipient.safeTransferETH(affiliateFee);
            } else {
                token.safeTransfer(feeConfig.affiliateRecipient, affiliateFee);
            }
            amountAfterFees -= affiliateFee;
        }

        return amountAfterFees;
    }

    function _safeApprove(
        address token,
        address spender,
        uint256 amount
    ) private {
        // This handles USDT and most standard tokens
        try IERC20(token).approve(spender, 0) {
            // If zero approval succeeds, set the actual amount
            token.safeApprove(spender, amount);
        } catch {
            // Zero approval failed (like ETH.BNB), handle it differently
            uint256 currentAllowance = IERC20(token).allowance(
                address(this),
                spender
            );

            // Only update approval if current allowance is insufficient
            if (currentAllowance < amount) {
                // Set the new approval amount
                token.safeApprove(spender, amount);
            }
        }
    }

    function _emitSwapEvent(
        address tokenIn,
        address tokenOut,
        address recipient,
        uint256 amountIn,
        uint256 amountOut,
        uint256 swapAmount,
        uint256 swapResult,
        FeeConfig calldata feeConfig
    ) private {
        uint256 feeAmount = 0;
        uint256 affiliateFeeAmount = 0;

        if (feeConfig.feeOnInput) {
            feeAmount = amountIn - swapAmount;
            if (feeConfig.affiliateFeeBps > 0) {
                affiliateFeeAmount = _calcBps(
                    feeConfig.affiliateFeeBps,
                    amountIn
                );
                feeAmount -= affiliateFeeAmount;
            }
        } else {
            // For output fees, we need to calculate based on the original output before fees
            if (feeConfig.feeBps > 0 || feeConfig.affiliateFeeBps > 0) {
                // Reverse calculate original amount before fees
                feeAmount = _calcBps(feeConfig.feeBps, swapResult);
                affiliateFeeAmount = _calcBps(
                    feeConfig.affiliateFeeBps,
                    swapResult
                );
            }
        }

        emit Swap(
            tokenIn,
            tokenOut,
            amountIn,
            amountOut,
            recipient,
            feeAmount,
            affiliateFeeAmount,
            feeConfig.feeOnInput
        );
    }
}
