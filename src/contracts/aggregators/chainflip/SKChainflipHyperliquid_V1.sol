// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Owners} from "../../../lib/Owners.sol";
import {SafeTransferLib} from "../../../lib/SafeTransferLib.sol";
import {IChainflipReceiver} from "../../../interfaces/IChainflipReceiver.sol";
import {IHyperLiquidBridge2} from "../../../interfaces/IHyperLiquidBridge2.sol";
import {IERC20} from "../../../interfaces/IERC20.sol";
import {TSAggregator_V5} from "../../abstract/TSAggregator_V5.sol";
import {SKChainflipAggregator_V1} from "../../abstract/SKChainflipAggregator_V1.sol";

contract SKChainflipHyperLiquid_V1 is
    Owners,
    IChainflipReceiver,
    TSAggregator_V5,
    SKChainflipAggregator_V1
{
    using SafeTransferLib for address;
    using SafeTransferLib for IERC20;

    IHyperLiquidBridge2 public hyperLiquidBridge;

    address feeAddress;

    /// @notice we enforce a particular token address that we expect (e.g. USDC).
    IERC20 public immutable transferAsset;

    /**
     * @notice Data structure for cross-chain message to handle depositWithPermit.
     *         This matches the data we must pass to `batchedDepositWithPermit`.
     */
    struct CCMHyperLiquid {
        address user;
    }

    event ChainflipToHyperLiquid(
        uint32 srcChain,
        bytes srcAddress,
        address user,
        uint256 usd
    );

    constructor(
        address _ttp,
        address _hlBridge,
        address _transferAsset,
        address _feeAddress,
        address _cfVault
    ) TSAggregator_V5(_ttp) SKChainflipAggregator_V1(_cfVault) {
        _setOwner(msg.sender, true);
        hyperLiquidBridge = IHyperLiquidBridge2(_hlBridge);
        transferAsset = IERC20(_transferAsset);
        feeAddress = _feeAddress;
        cfVault = _cfVault;
    }

    function cfReceive(
        uint32 srcChain,
        bytes calldata srcAddress,
        bytes calldata message,
        address token,
        uint256 amount
    ) external payable onlyCfVault {
        require(token == address(transferAsset), "Invalid transfer asset");

        CCMHyperLiquid memory hlPayload = decodeMessage(message);

        uint256 _amount = takeFeeToken(token, amount);
        transferAsset.transfer(hlPayload.user, _amount);

        transferAsset.transferFrom(
            hlPayload.user,
            address(hyperLiquidBridge),
            _amount
        );

        emit ChainflipToHyperLiquid(
            srcChain,
            srcAddress,
            hlPayload.user,
            _amount
        );
    }

    function decodeMessage(
        bytes calldata message
    ) public pure returns (CCMHyperLiquid memory) {
        return abi.decode(message, (CCMHyperLiquid));
    }
}
