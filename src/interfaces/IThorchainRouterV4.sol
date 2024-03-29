// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IThorchainRouterV4 {
    function depositWithExpiry(
        address payable vault,
        address asset,
        uint amount,
        string memory memo,
        uint expiration
    ) external payable;
}
