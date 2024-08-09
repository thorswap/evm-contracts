// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IOracleV1 {
    function getRouterAddress() external view returns (address);

    function getPoolsAPY(string memory chain) external view returns (uint64);

    function getSaversAPY(string memory chain) external view returns (uint64);

    // Updated to match the new return type of getInboundAddress in the TSOracle_V1 contract
    function getInboundAddress(
        string memory chain
    ) external view returns (bytes memory, address);
}
