// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract MockRewardsReceiver {
    uint256 public totalRewardsReceived;

    function depositRewards(uint256 amount) external {
        totalRewardsReceived += amount;
    }
}
