// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {SafeTransferLib} from "../../lib/SafeTransferLib.sol";
import {ReentrancyGuard} from "../../lib/ReentrancyGuard.sol";
import {Owners} from "../../lib/Owners.sol";
import {TSAggregatorTokenTransferProxy} from "../misc/TSAggregatorTokenTransferProxy.sol";

abstract contract TSAggregator_V4 is Owners, ReentrancyGuard {
    using SafeTransferLib for address;

    event FeeSet(uint256 fee, address feeRecipient);

    uint256 public fee;
    address public feeRecipient;
    TSAggregatorTokenTransferProxy public tokenTransferProxy;

    mapping(address => bool) public tokensWithTransferFee;

    constructor(address _tokenTransferProxy) {
        _setOwner(msg.sender, true);
        tokenTransferProxy = TSAggregatorTokenTransferProxy(
            _tokenTransferProxy
        );
    }

    // Needed for the swap router to be able to send back ETH
    receive() external payable {}

    function setFee(uint256 _fee, address _feeRecipient) external isOwner {
        require(_fee <= 1000, "fee can not be more than 10%");
        fee = _fee;
        feeRecipient = _feeRecipient;
        emit FeeSet(_fee, _feeRecipient);
    }

    function takeFeeGas(uint256 amount) internal returns (uint256) {
        uint256 amountFee = getFee(amount);
        if (amountFee > 0) {
            feeRecipient.safeTransferETH(amountFee);
            amount -= amountFee;
        }
        return amount;
    }

    function takeFeeToken(
        address token,
        uint256 amount
    ) internal returns (uint256) {
        uint256 amountFee = getFee(amount);
        if (amountFee > 0) {
            token.safeTransfer(feeRecipient, amountFee);
            amount -= amountFee;
        }
        return amount;
    }

    function getFee(uint256 amount) internal view returns (uint256) {
        if (fee != 0 && feeRecipient != address(0)) {
            return (amount * fee) / 10000;
        }
        return 0;
    }

    // Parse amountOutMin treating the last 2 digits as an exponent
    // So 1504 = 150000. This allows for compressed memos on chains
    // with limited space like Bitcoin
    function _parseAmountOutMin(
        uint256 amount
    ) internal pure returns (uint256) {
        return (amount / 100) * (10 ** (amount % 100));
    }

    function addTokenWithTransferFee(address token) external isOwner {
        tokensWithTransferFee[token] = true;
    }

    // Aggregator contracts are not meant to hold any funds
    // This is just in case assets get stuck in the contract
    function rescueFunds(
        address asset,
        uint256 amount,
        address destination
    ) public isOwner {
        if (asset == address(0)) {
            payable(destination).transfer(amount);
        } else {
            asset.safeTransfer(destination, amount);
        }
    }
}
