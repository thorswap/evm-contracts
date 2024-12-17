// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IChainflipVault {
    function xSwapNative(
        uint32 dstChain,
        bytes memory dstAddress, // 32 bytes expected by chainflip
        uint32 dstToken,
        bytes calldata cfParameters
    ) external payable;
}
