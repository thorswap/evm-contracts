// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Owners} from "../../../lib/Owners.sol";
import {SafeTransferLib} from "../../../lib/SafeTransferLib.sol";
import {IChainflipReceiver} from "../../../interfaces/IChainflipReceiver.sol";
import {IHyperLiquidBridge2} from "../../../interfaces/IHyperLiquidBridge2.sol";
import {IERC20} from "../../../interfaces/IERC20.sol";

// version 0.1


contract SKChainflipHyperLiquidAggregator_V1 is Owners, IChainflipReceiver {
    using SafeTransferLib for address;
    using SafeTransferLib for IERC20;

    IHyperLiquidBridge2 public hyperLiquidBridge;

    /// @notice ee enforce a particular token address that we expect (e.g. USDC).
    IERC20 public immutable transferAsset;

    /**
     * @notice Data structure for cross-chain message to handle depositWithPermit.
     *         This matches the data we must pass to `batchedDepositWithPermit`.
     */
    struct CCMHyperLiquid {
        address user;
        IHyperLiquidBridge2.Signature sig;
    }

    event ChainflipToHyperLiquidWithPermit(
        uint32 srcChain,
        bytes srcAddress,
        address user,
        uint256 usd
    );

    constructor(address _bridge, address _transferAsset) {
        _setOwner(msg.sender, true);
        hyperLiquidBridge = IHyperLiquidBridge2(_bridge);
        transferAsset = IERC20(_transferAsset);
    }

    function cfReceive(
        uint32 srcChain,
        bytes calldata srcAddress,
        bytes calldata message,
        address token,
        uint256 amount
    ) external payable override {
        require(token == address(transferAsset), "Invalid transfer asset");

        // Decode the cross-chain message into our deposit-with-permit parameters
        CCMHyperLiquid memory hlPayload = decodeMessage(message);

        // transfer the tokens to the user's address
        // this is required because HL's bridge will use a permit from the user's address
        transferAsset.transfer(hlPayload.user, amount);

        // Construct a single-element array for the batched deposit-with-permit
        IHyperLiquidBridge2.DepositWithPermit[] memory deposits = 
            new IHyperLiquidBridge2.DepositWithPermit[](1);

        deposits[0] = IHyperLiquidBridge2.DepositWithPermit({
            user: hlPayload.user,
            usd: uint64(amount),
            deadline: uint64(block.timestamp + 1),
            signature: hlPayload.sig
        });

        // Call the bridging contract
        hyperLiquidBridge.batchedDepositWithPermit(deposits);

        emit ChainflipToHyperLiquidWithPermit(
            srcChain,
            srcAddress,
            hlPayload.user,
            amount
        );
    }

    function decodeMessage(bytes calldata message)
        public
        pure
        returns (CCMHyperLiquid memory)
    {
        return abi.decode(message, (CCMHyperLiquid));
    }
}
