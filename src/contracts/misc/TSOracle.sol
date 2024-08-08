// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// -------------------
// Compatibility
// TC Router V4
// -------------------

import {Owners} from "../../lib/Owners.sol";
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

    address private routerAddress;
    mapping(string => uint64) private poolsAPY;
    mapping(string => uint64) private saversAPY;
    mapping(string => VaultInformation) private vaults;

    uint256 public routerAddressUpdatedAt;
    uint256 public poolsAPYUpdatedAt;
    uint256 public saversAPYUpdatedAt;

    event VaultsUpdated(string[] chains, uint256 timestamp);
    event ExpirationChanged(uint32 newExpiration);

    constructor(
        address _feeAsset,
        uint256 price
    ) TSPaymentGated(_feeAsset, price) {
        expiration = 259200; // 3 days
        _setOwner(msg.sender, true);
    }

    // add router address
    function updateRouterAddress(address _tcRouterAddress) external isOwner {
        routerAddress = _tcRouterAddress;
        routerAddressUpdatedAt = block.timestamp;
    }

    function getRouterAddress() external view isPaidUser returns (address) {
        return routerAddress;
    }

    function updatePoolsAPY(
        string[] memory chains,
        uint64[] memory apys
    ) external isOwner {
        require(
            chains.length == apys.length,
            "Input arrays must have the same length"
        );

        for (uint256 i = 0; i < chains.length; i++) {
            poolsAPY[chains[i]] = apys[i];
        }

        poolsAPYUpdatedAt = block.timestamp;
    }

    function getPoolsAPY(
        string memory chain
    ) external view isPaidUser returns (uint64) {
        return poolsAPY[chain];
    }

    function updateSaversAPY(
        string[] memory chains,
        uint64[] memory apys
    ) external isOwner {
        require(
            chains.length == apys.length,
            "Input arrays must have the same length"
        );

        for (uint256 i = 0; i < chains.length; i++) {
            saversAPY[chains[i]] = apys[i];
        }

        saversAPYUpdatedAt = block.timestamp;
    }

    function getSaversAPY(
        string memory chain
    ) external view isPaidUser returns (uint64) {
        return saversAPY[chain];
    }

    function updateVaults(
        string[] memory chains,
        string[] memory newAddresses,
        bool[] memory tradingStatuses
    ) external isOwner {
        require(
            chains.length == newAddresses.length &&
                chains.length == tradingStatuses.length,
            "Input arrays must have the same length"
        );

        for (uint256 i = 0; i < chains.length; i++) {
            VaultInformation storage vaultInfo = vaults[chains[i]];
            vaultInfo.updatedAt = block.timestamp;
            vaultInfo.vaults[chains[i]] = newAddresses[i];
            vaultInfo.tradingEnabled = tradingStatuses[i];
        }

        emit VaultsUpdated(chains, block.timestamp);
    }

    function getInboundAddress(
        string memory chain
    ) external view isPaidUser returns (string memory) {
        VaultInformation storage vaultInfo = vaults[chain];
        require(vaultInfo.tradingEnabled, "Trading is disabled for this chain");
        require(
            vaultInfo.updatedAt + expiration >= block.timestamp,
            "Vault information expired"
        );
        return vaultInfo.vaults[chain];
    }

    function changeExpiration(uint32 newExpiration) external isOwner {
        expiration = newExpiration;
        emit ExpirationChanged(newExpiration);
    }
}
