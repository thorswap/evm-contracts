// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface ITSOracleV1 {
    function getRouterAddress() external view returns (address);

    function getPoolsAPY(string memory chain) external view returns (uint64);

    function getSaversAPY(string memory chain) external view returns (uint64);

    function getInboundAddress(
        string memory chain
    ) external view returns (string memory);
}
