// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Owners} from "./Owners.sol";

abstract contract Executors is Owners {
    event ExecutorSet(address indexed executor, bool active);

    mapping(address => bool) public executors;

    modifier isExecutor() {
        require(executors[msg.sender], "Unauthorized");
        _;
    }

    function _setExecutor(address executor, bool active) internal virtual {
        executors[executor] = active;
        emit ExecutorSet(executor, active);
    }

    function setExecutor(address owner, bool active) external virtual isOwner {
        _setExecutor(owner, active);
    }
}
