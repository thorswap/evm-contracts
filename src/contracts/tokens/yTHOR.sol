// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ERC20Vote} from "../../lib/ERC20Vote.sol";
import {IERC20} from "../../interfaces/IERC20.sol";
import {IERC4626} from "../../interfaces/IERC4626.sol";
import {SafeTransferLib} from "../../lib/SafeTransferLib.sol";
import {FixedPointMathLib} from "../../lib/FixedPointMathLib.sol";
import {ReentrancyGuard} from "../../lib/ReentrancyGuard.sol";

contract yTHOR is IERC4626, ERC20Vote, ReentrancyGuard {
    using SafeTransferLib for address;
    using FixedPointMathLib for uint256;

    IERC20 public immutable _asset; // underlying token
    IERC20 public immutable _rewardAsset; // reward token

    mapping(address => uint256) public accruedRewards; // track each user's accrued rewards
    address[] public holders; // array to track all holders
    mapping(address => bool) private isHolder; // mapping to simplify checking if an address is a holder

    event RewardClaimed(address indexed user, uint256 amount);
    event RewardsDeposited(uint256 amount);

    constructor(
        IERC20 asset_,
        IERC20 rewardAsset_
    ) ERC20Vote("YieldTHOR", "yTHOR", 18) {
        _asset = asset_;
        _rewardAsset = rewardAsset_;
    }

    function asset() public view returns (address) {
        return address(_asset);
    }

    function totalAssets() public view returns (uint256) {
        return _asset.balanceOf(address(this));
    }

    function convertToShares(uint256 assets) public view returns (uint256) {
        return
            totalSupply == 0
                ? assets
                : assets.mulDivDown(totalSupply, totalAssets());
    }

    function convertToAssets(uint256 shares) public view returns (uint256) {
        return
            totalSupply == 0
                ? shares
                : shares.mulDivDown(totalAssets(), totalSupply);
    }

    function previewDeposit(uint256 assets) public view returns (uint256) {
        return convertToShares(assets);
    }

    function previewMint(uint256 shares) public view returns (uint256) {
        return
            totalSupply == 0
                ? shares
                : shares.mulDivUp(totalAssets(), totalSupply);
    }

    function previewWithdraw(uint256 assets) public view returns (uint256) {
        return
            totalSupply == 0
                ? assets
                : assets.mulDivUp(totalSupply, totalAssets());
    }

    function previewRedeem(uint256 shares) public view returns (uint256) {
        return convertToAssets(shares);
    }

    function maxDeposit(address) public view returns (uint256) {
        return type(uint256).max;
    }

    function maxMint(address) external view returns (uint256) {
        return type(uint256).max;
    }

    function maxWithdraw(address owner) public view returns (uint256) {
        return convertToAssets(balanceOf[owner]);
    }

    function maxRedeem(address owner) public view returns (uint256) {
        return balanceOf[owner];
    }

    function deposit(
        uint256 assets,
        address receiver
    ) public nonReentrant returns (uint256 shares) {
        require((shares = convertToShares(assets)) != 0, "ZERO_SHARES");

        address(_asset).safeTransferFrom(msg.sender, address(this), assets);
        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function mint(
        uint256 shares,
        address receiver
    ) public nonReentrant returns (uint256 assets) {
        assets = previewMint(shares);
        address(_asset).safeTransferFrom(msg.sender, address(this), assets);
        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public nonReentrant returns (uint256 shares) {
        shares = convertToShares(assets);
        require(balanceOf[owner] >= shares, "INSUFFICIENT_BALANCE");

        if (msg.sender != owner) {
            uint256 allowed = allowance[owner][msg.sender];
            if (allowed != type(uint256).max)
                allowance[owner][msg.sender] = allowed - shares;
        }

        _burn(owner, shares);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);
        address(_asset).safeTransfer(receiver, assets);
    }

    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public nonReentrant returns (uint256 assets) {
        assets = convertToAssets(shares);
        require(balanceOf[owner] >= shares, "INSUFFICIENT_BALANCE");

        if (msg.sender != owner) {
            uint256 allowed = allowance[owner][msg.sender];
            if (allowed != type(uint256).max)
                allowance[owner][msg.sender] = allowed - shares;
        }

        _burn(owner, shares);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);
        address(_asset).safeTransfer(receiver, assets);
    }

    function claimRewards() public nonReentrant {
        uint256 userRewards = accruedRewards[msg.sender];
        require(userRewards > 0, "NO_REWARDS");

        accruedRewards[msg.sender] = 0;
        address(_rewardAsset).safeTransfer(msg.sender, userRewards);

        emit RewardClaimed(msg.sender, userRewards);
    }

    function depositRewards(uint256 rewardAssetAmount) external nonReentrant {
        require(totalSupply > 0, "NO_SHARES");

        // transfer rewards to the contract
        address(_rewardAsset).safeTransferFrom(
            msg.sender,
            address(this),
            rewardAssetAmount
        );

        // distribute rewards proportionally based on balance of yTHOR
        for (uint256 i = 0; i < holders.length; i++) {
            address user = holders[i];
            uint256 userShare = balanceOf[user].mulDivDown(
                rewardAssetAmount,
                totalSupply
            );
            accruedRewards[user] += userShare;
        }

        emit RewardsDeposited(rewardAssetAmount);
    }

    // override transfer to account for unclaimed rewards
    function transfer(
        address to,
        uint256 amount
    ) public override returns (bool) {
        _beforeTokenTransfer(msg.sender, to, amount);

        uint256 senderRewards = accruedRewards[msg.sender];
        uint256 rewardShare = senderRewards.mulDivDown(
            amount,
            balanceOf[msg.sender]
        );

        accruedRewards[msg.sender] -= rewardShare;
        accruedRewards[to] += rewardShare;

        return super.transfer(to, amount);
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool) {
        _beforeTokenTransfer(from, to, amount);

        uint256 senderRewards = accruedRewards[from];
        uint256 rewardShare = senderRewards.mulDivDown(amount, balanceOf[from]);

        accruedRewards[from] -= rewardShare;
        accruedRewards[to] += rewardShare;

        return super.transferFrom(from, to, amount);
    }

    // add/remove holders to track active participants
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        if (amount == 0) return;

        // add new holder
        if (to != address(0) && balanceOf[to] == 0 && !isHolder[to]) {
            holders.push(to);
            isHolder[to] = true;
        }

        // remove holder if balance goes to zero
        if (from != address(0) && balanceOf[from] == amount && isHolder[from]) {
            _removeHolder(from);
        }
    }

    function _removeHolder(address holder) internal {
        uint256 holderCount = holders.length;
        for (uint256 i = 0; i < holderCount; i++) {
            if (holders[i] == holder) {
                holders[i] = holders[holderCount - 1];
                holders.pop();
                isHolder[holder] = false;
                break;
            }
        }
    }
}
