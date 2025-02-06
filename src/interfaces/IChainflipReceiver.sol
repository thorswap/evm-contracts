// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @dev Minimal interface for Chainflip vault or router to call cfReceive
 *      In practice, Chainflip's official interface will call this function
 *      on your contract, delivering the swapped tokens.
 */
interface IChainflipReceiver {
    function cfReceive(
        uint32 srcChain,
        bytes calldata srcAddress,
        bytes calldata message,
        address token,
        uint256 amount
    ) external payable;
}
