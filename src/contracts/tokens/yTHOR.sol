// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {yieldTHOR} from "./yieldTHOR.sol";

contract yTHOR is yieldTHOR, Ownable {
    bool public canWithdraw = false;

    constructor(
        address asset,
        address reward,
        address owner
    ) yieldTHOR("YieldTHOR", "yTHOR", asset, reward) {
        _transferOwnership(owner);
    }

    function setCanWithdraw(bool _canWithdraw) external onlyOwner {
        canWithdraw = _canWithdraw;
    }

    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public override nonReentrant returns (uint256) {
        require(canWithdraw, "NOT_SUPPORTED");
        return super.withdraw(assets, receiver, owner);
    }

    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public override nonReentrant returns (uint256) {
        require(canWithdraw, "NOT_SUPPORTED");
        return super.redeem(shares, receiver, owner);
    }
}
