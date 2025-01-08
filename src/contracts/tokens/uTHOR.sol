// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {yieldTHOR} from "./yieldTHOR.sol";

contract uTHOR is yieldTHOR {
    constructor(
        address asset,
        address reward
    ) yieldTHOR("UsdcTHOR", "uTHOR", asset, reward) {}
}
