// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {SafeTransferLib} from "../../lib/SafeTransferLib.sol";
import {ReentrancyGuard} from "../../lib/ReentrancyGuard.sol";
import {Owners} from "../../lib/Owners.sol";
import {TSAggregatorTokenTransferProxy} from "../misc/TSAggregatorTokenTransferProxy.sol";

abstract contract SKAggregator_V1 is Owners, ReentrancyGuard {
    using SafeTransferLib for address;

    event SKAddressSet(address skRecipient);
    event AddressAdded(address indexed addr);
    event AddressRemoved(address indexed addr);

    address public skRecipient;
    TSAggregatorTokenTransferProxy public tokenTransferProxy;

    mapping(address => bool) public knownAddresses;

    constructor(address _tokenTransferProxy) {
        _setOwner(msg.sender, true);
        tokenTransferProxy = TSAggregatorTokenTransferProxy(
            _tokenTransferProxy
        );
    }

    // Needed for the swap router to be able to send back ETH
    receive() external payable {}

    function setSKAddress(address _skRecipient) external isOwner {
        skRecipient = _skRecipient;
        emit SKAddressSet(_skRecipient);
    }

    function addAddress(address addr) external isOwner {
        require(addr != address(0), "invalid address");
        require(addr != address(tokenTransferProxy), "cannot add ttp");
        require(!knownAddresses[addr], "address already known");

        knownAddresses[addr] = true;
        emit AddressAdded(addr);
    }

    function removeAddress(address addr) external isOwner {
        require(knownAddresses[addr], "address not known");

        knownAddresses[addr] = false;
        emit AddressRemoved(addr);
    }

    function isAddressKnown(address addr) public view returns (bool) {
        return knownAddresses[addr];
    }

    function takeFeeGas(uint256 feeBps, uint256 amount) internal returns (uint256) {
        uint256 amountFee = getFee(feeBps, amount);
        if (amountFee > 0) {
            skRecipient.safeTransferETH(amountFee);
            amount -= amountFee;
        }
        return amount;
    }

    function takeFeeToken(
        uint256 feeBps,
        address token,
        uint256 amount
    ) internal returns (uint256) {
        uint256 amountFee = getFee(feeBps, amount);
        if (amountFee > 0) {
            token.safeTransfer(skRecipient, amountFee);
            amount -= amountFee;
        }
        return amount;
    }

    function getFee(uint256 feeBps, uint256 amount) internal view returns (uint256) {
        if (feeBps != 0 && skRecipient != address(0)) {
            return (amount * feeBps) / 10000;
        }
        return 0;
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
