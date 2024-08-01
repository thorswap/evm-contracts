// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// -------------------
// Compatibility
// TC Router V4
// -------------------

import {Owners} from "../../lib/Owners.sol";
import {IThorchainRouterV4} from "../../interfaces/IThorchainRouterV4.sol";
import {TSPaymentGated} from "../abstract/TSPaymentGated.sol";

contract TSOracle_V1 is Owners, TSPaymentGated {
    struct VaultInformation {
        uint256 updatedAt;
        // 1 address for each supported chain. Chain as per Thornode.
        // Example: BCH -> qr4mp5c8ucy0r24x7yuvsjhqwdhd9pcd9yn366ynm3
        mapping(string => string) vaults;
        // set to false if global or trading is halted
        bool tradingEnabled;
    }

    uint32 public expiration;
    mapping(string => VaultInformation) private vaults;

    event VaultsUpdated(string[] chains, uint256 timestamp);
    event ExpirationChanged(uint32 newExpiration);

    constructor(address _feeAsset, uint256 price) TSPaymentGated(_feeAsset, price) {
        expiration = 259200; // 3 days
        _setOwner(msg.sender, true);
    }

    // Function to update the vault information for multiple chains
    function updateVaults(string[] memory chains, string[] memory newAddresses, bool[] memory tradingStatuses) external isOwner {
        require(chains.length == newAddresses.length && chains.length == tradingStatuses.length, "Input arrays must have the same length");
        
        for (uint256 i = 0; i < chains.length; i++) {
            VaultInformation storage vaultInfo = vaults[chains[i]];
            vaultInfo.updatedAt = block.timestamp;
            vaultInfo.vaults[chains[i]] = newAddresses[i];
            vaultInfo.tradingEnabled = tradingStatuses[i];
        }

        emit VaultsUpdated(chains, block.timestamp);
    }

    // Function to get the inbound address of a specific chain
    function getInboundAddress(string memory chain) public view returns (string memory) {
        VaultInformation storage vaultInfo = vaults[chain];
        require(vaultInfo.tradingEnabled, "Trading is disabled for this chain");
        require(vaultInfo.updatedAt + expiration >= block.timestamp, "Vault information expired");
        return vaultInfo.vaults[chain];
    }

    // Function to change the expiration period
    function changeExpiration(uint32 newExpiration) external isOwner {
        expiration = newExpiration;
        emit ExpirationChanged(newExpiration);
    }
}
