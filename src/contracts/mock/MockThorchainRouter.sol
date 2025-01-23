// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract MockThorchainRouter {
    event DepositWithExpiry(
        address payable vault,
        address asset,
        uint256 amount,
        string memo,
        uint256 expiration
    );

    function depositWithExpiry(
        address payable vault,
        address asset,
        uint256 amount,
        string calldata memo,
        uint256 expiration
    ) external payable {
        // For the test, just emit an event so we can see something happened
        emit DepositWithExpiry(vault, asset, amount, memo, expiration);
    }
}
