// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract yieldTHOR is ERC20, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 private constant ACC_PRECISION = 1e12;
    IERC20 public immutable asset;
    IERC20 public immutable reward;
    uint256 public accRewardPerShare;
    mapping(address => int256) public rewardDebt;

    event Deposit(
        address indexed caller,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );
    event Withdraw(
        address indexed caller,
        address indexed receiver,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );
    event RewardClaimed(address indexed user, uint256 amount);
    event RewardsDeposited(uint256 amount);

    constructor(
        string memory name,
        string memory symbol,
        address _asset,
        address _reward
    ) ERC20(name, symbol) {
        asset = IERC20(_asset);
        reward = IERC20(_reward);
    }

    function totalAssets() public view returns (uint256) {
        return totalSupply();
    }

    function convertToShares(uint256 assets) public view returns (uint256) {
        return assets;
    }

    function convertToAssets(uint256 shares) public view returns (uint256) {
        return shares;
    }

    function previewDeposit(uint256 assets) public view returns (uint256) {
        return assets;
    }

    function previewMint(uint256 shares) public view returns (uint256) {
        return shares;
    }

    function previewWithdraw(uint256 assets) public view returns (uint256) {
        return assets;
    }

    function previewRedeem(uint256 shares) public view returns (uint256) {
        return shares;
    }

    function maxDeposit(address) public view returns (uint256) {
        return type(uint256).max;
    }

    function maxMint(address) public view returns (uint256) {
        return type(uint256).max;
    }

    function maxWithdraw(address owner) public view returns (uint256) {
        return balanceOf(owner);
    }

    function maxRedeem(address owner) public view returns (uint256) {
        return balanceOf(owner);
    }

    function deposit(
        uint256 assets,
        address receiver
    ) public nonReentrant returns (uint256 shares) {
        shares = convertToShares(assets);
        asset.safeTransferFrom(msg.sender, address(this), assets);
        _mint(receiver, shares);
        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function mint(
        uint256 shares,
        address receiver
    ) public nonReentrant returns (uint256 assets) {
        assets = previewMint(shares);
        asset.safeTransferFrom(msg.sender, address(this), assets);
        _mint(receiver, shares);
        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public virtual nonReentrant returns (uint256 shares) {
        shares = previewWithdraw(assets);
        require(balanceOf(owner) >= shares, "INSUFFICIENT_BALANCE");
        if (msg.sender != owner) {
            uint256 allowed = allowance(owner, msg.sender);
            if (allowed != type(uint256).max) {
                _approve(owner, msg.sender, allowed - shares);
            }
        }
        _burn(owner, shares);
        asset.safeTransfer(receiver, assets);
        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }

    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public virtual nonReentrant returns (uint256 assets) {
        assets = previewRedeem(shares);
        require(balanceOf(owner) >= shares, "INSUFFICIENT_BALANCE");
        if (msg.sender != owner) {
            uint256 allowed = allowance(owner, msg.sender);
            if (allowed != type(uint256).max) {
                _approve(owner, msg.sender, allowed - shares);
            }
        }
        _burn(owner, shares);
        asset.safeTransfer(receiver, assets);
        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }

    function depositRewards(uint256 amount) external nonReentrant {
        require(totalSupply() > 0, "NO_SHARES");
        reward.safeTransferFrom(msg.sender, address(this), amount);
        accRewardPerShare = accRewardPerShare + ((amount * ACC_PRECISION) / totalSupply());
        emit RewardsDeposited(amount);
    }

    function claimable(address user) external view returns (uint256) {
        int256 accumulated = int256((balanceOf(user) * accRewardPerShare) / ACC_PRECISION);
        return uint256(accumulated - rewardDebt[user]);
    }

    function claimRewards() external nonReentrant {
        int256 accumulated = int256((balanceOf(msg.sender) * accRewardPerShare) / ACC_PRECISION);
        uint256 pending = uint256(accumulated - rewardDebt[msg.sender]);
        rewardDebt[msg.sender] = accumulated;
        reward.safeTransfer(msg.sender, pending);
        emit RewardClaimed(msg.sender, pending);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override {
        if (from != address(0)) {
            rewardDebt[from] = rewardDebt[from] - int256((amount * accRewardPerShare) / ACC_PRECISION);
        }
        if (to != address(0)) {
            rewardDebt[to] = rewardDebt[to] + int256((amount * accRewardPerShare) / ACC_PRECISION);
        }
    }
}
