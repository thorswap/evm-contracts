// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// -------------------
// Compatibility
// TC Router V4
// -------------------

import {Owners} from "../../lib/Owners.sol";
import {Executors} from "../../lib/Executors.sol";
import {TSPaymentGated} from "../abstract/TSPaymentGated.sol";

contract TSOracle_V1 is Owners, Executors, TSPaymentGated {
    struct VaultInformation {
        uint256 updatedAt;
        bytes vault; // 1 address for each supported chain.
        bool tradingEnabled; // set to false if global or trading is halted
        bool isEvm;
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

    // add isExecutor modifier for updating info

    // add router address
    function updateRouterAddress(address _tcRouterAddress) external isExecutor {
        routerAddress = _tcRouterAddress;
        routerAddressUpdatedAt = block.timestamp;
    }

    function getRouterAddress() external view isPaidUser returns (address) {
        return routerAddress;
    }

    function updatePoolsAPY(
        string[] memory chains,
        uint64[] memory apys
    ) external isExecutor {
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
    ) external isExecutor {
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
        bytes[] memory newAddresses,
        bool[] memory tradingStatuses,
        bool[] memory isEvm
    ) external isExecutor {
        require(
            chains.length == newAddresses.length &&
                chains.length == tradingStatuses.length,
            "Input arrays must have the same length"
        );

        for (uint256 i = 0; i < chains.length; i++) {
            VaultInformation storage vaultInfo = vaults[chains[i]];
            vaultInfo.updatedAt = block.timestamp;
            vaultInfo.vault = newAddresses[i];
            vaultInfo.tradingEnabled = tradingStatuses[i];
            vaultInfo.isEvm = isEvm[i];
        }

        emit VaultsUpdated(chains, block.timestamp);
    }

    function getInboundAddress(
        string memory chain
    ) external view isPaidUser returns (bytes memory, address) {
        VaultInformation storage vaultInfo = vaults[chain];
        require(vaultInfo.tradingEnabled, "Trading is disabled for this chain");
        require(
            vaultInfo.updatedAt + expiration >= block.timestamp,
            "Vault information expired"
        );

        // Check if the vault address is for an EVM chain
        if (vaultInfo.isEvm) {
            // Convert bytes to an address and return both the bytes and the converted address
            return (vaultInfo.vault, bytesToAddress(vaultInfo.vault));
        } else {
            // Return the bytes and a zero address since it's not an EVM address
            return (vaultInfo.vault, address(0));
        }
    }

    function changeExpiration(uint32 newExpiration) external isOwner {
        expiration = newExpiration;
        emit ExpirationChanged(newExpiration);
    }

    //---------- Helpers ----------//
    // Convert bytes to an Ethereum address assuming the bytes are the right length (20 bytes)
    function bytesToAddress(bytes memory b) internal pure returns (address) {
        require(b.length == 20, "Invalid bytes length for address conversion");
        uint160 addr;
        assembly {
            addr := mload(add(b, 20))
        }
        return address(addr);
    }

    // Convert bytes to string (general purpose)
    function bytesToString(
        bytes memory data
    ) internal pure returns (string memory) {
        return string(data);
    }
}
