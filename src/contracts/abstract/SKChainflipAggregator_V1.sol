// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {SafeTransferLib} from "../../lib/SafeTransferLib.sol";
import {Owners} from "../../lib/Owners.sol";
import {TSAggregatorTokenTransferProxy} from "../misc/TSAggregatorTokenTransferProxy.sol";

abstract contract SKChainflipAggregator_V1 is Owners {
    using SafeTransferLib for address;

    address public cfVault;

    constructor(address _cfVault) {
        cfVault = _cfVault;
    }

    function updateCfVault(address _cfVault) external isOwner {
        cfVault = _cfVault;
    }

   /// @dev Check that the sender is the Chainflip's Vault.
    modifier onlyCfVault() {
        require(msg.sender == cfVault, "CFReceiver: caller not Chainflip sender");
        _;
    }
}
