//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IuTHOR {
    function claimRewards() external;
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function claimable(address user) external view returns (uint256);
}

/**
 * @title xTHOR Individual Vesting Contract
 * @notice Single beneficiary vesting contract for uTHOR tokens with independent USDC reward claiming
 * @dev Each contract is deployed for one individual beneficiary
 */
contract xTHORIndividualVesting is Ownable, ReentrancyGuard {
    
    // The uTHOR token contract
    IuTHOR public immutable uTHOR;
    
    // The USDC reward token contract  
    IERC20 public immutable rewardToken;
    
    // The beneficiary who can claim tokens and rewards
    address public beneficiary;
    
    // Vesting parameters
    uint256 public immutable totalAmount;      // Total uTHOR tokens to vest
    uint256 public immutable startTime;       // Vesting start time
    uint256 public immutable cliffDuration;   // Cliff period in seconds
    uint256 public immutable vestingDuration; // Total vesting duration in seconds
    
    // Amount of uTHOR already released to beneficiary
    uint256 public released;

    // Amount of uTHOR withdrawn by owner in emergency (reduces effective total)
    uint256 public emergencyWithdrawn;

    // Whether claiming is enabled
    bool public claimingEnabled;
    
    // Whether vesting has been revoked
    bool public revoked;
    
    event TokensReleased(uint256 amount);
    event RewardsClaimed(uint256 amount);
    event ClaimingEnabled();
    event VestingRevoked(address indexed beneficiary, uint256 unvestedAmount);
    event EmergencyWithdrawUTHOR(uint256 amount);
    event EmergencyWithdrawUSDC(uint256 amount);
    event BeneficiaryUpdated(address indexed oldBeneficiary, address indexed newBeneficiary);
    
    modifier onlyBeneficiary() {
        require(msg.sender == beneficiary, "xTHOR: Not beneficiary");
        _;
    }
    
    constructor(
        address _uTHOR,
        address _rewardToken,
        address _beneficiary,
        uint256 _totalAmount,
        uint256 _startTime,
        uint256 _cliffDuration,
        uint256 _vestingDuration
    ) {
        require(_beneficiary != address(0), "xTHOR: Beneficiary cannot be zero address");
        require(_totalAmount > 0, "xTHOR: Total amount must be greater than 0");
        require(_vestingDuration > 0, "xTHOR: Vesting duration must be greater than 0");
        require(_cliffDuration <= _vestingDuration, "xTHOR: Cliff duration cannot exceed vesting duration");
        
        uTHOR = IuTHOR(_uTHOR);
        rewardToken = IERC20(_rewardToken);
        beneficiary = _beneficiary;
        totalAmount = _totalAmount;
        startTime = _startTime;
        cliffDuration = _cliffDuration;
        vestingDuration = _vestingDuration;
        claimingEnabled = false;
        revoked = false;
        emergencyWithdrawn = 0;
    }
    
    /**
     * @notice Claim all USDC rewards earned by the uTHOR held in this contract
     * @dev Beneficiary can claim all rewards regardless of vesting status
     */
    function claimRewards() external onlyBeneficiary nonReentrant {
        _claimRewardsInternal();
    }
    
    /**
     * @notice Internal function to claim USDC rewards
     * @dev Used by both claimRewards() and claimVested()
     */
    function _claimRewardsInternal() internal {
        uint256 balanceBefore = rewardToken.balanceOf(address(this));
        
        // 1. Harvest all USDC rewards owed to this contract from uTHOR
        uTHOR.claimRewards();
        
        // 2. Calculate actual rewards received (protect against manipulation)
        uint256 balanceAfter = rewardToken.balanceOf(address(this));
        uint256 newRewards = balanceAfter - balanceBefore;
        
        // 3. Transfer only the newly received USDC to beneficiary
        if (newRewards > 0) {
            require(rewardToken.transfer(beneficiary, newRewards), "xTHOR: USDC transfer failed");
            emit RewardsClaimed(newRewards);
        }
    }
    
    /**
     * @notice Claim vested uTHOR tokens
     * @dev Claims any pending USDC rewards FIRST, then transfers vested uTHOR
     * This is critical because once uTHOR is transferred, we lose claim to its rewards
     */
    function claimVested() external onlyBeneficiary nonReentrant {
        require(claimingEnabled, "xTHOR: Claiming not enabled");

        // Calculate vested uTHOR tokens
        uint256 vested = _vestedAmount(block.timestamp);
        uint256 unreleased = vested > released ? vested - released : 0;
		uint256 available = unreleased - emergencyWithdrawn;


        require(available > 0, "xTHOR: No vested tokens available");

        // Limit transfer to actual contract balance (accounts for emergency withdrawals)
        uint256 contractBalance = uTHOR.balanceOf(address(this));
        uint256 toTransfer = available > contractBalance ? contractBalance : available;

        require(toTransfer > 0, "xTHOR: No tokens available for transfer");

        // CRITICAL: Claim all USDC rewards BEFORE transferring uTHOR
        // Once uTHOR leaves the contract, we lose claim to future rewards from those tokens
        _claimRewardsInternal();

        // Final balance check with detailed error message
        uint256 currentBalance = uTHOR.balanceOf(address(this));
        require(currentBalance >= toTransfer, string(abi.encodePacked(
            "xTHOR: Contract balance insufficient. Balance: ",
            _toString(currentBalance),
            ", Trying to transfer: ",
            _toString(toTransfer),
            ", Vested: ",
            _toString(vested),
            ", Released: ",
            _toString(released),
            ", Emergency withdrawn: ",
            _toString(emergencyWithdrawn)
        )));

        // Now transfer the available uTHOR tokens
        released += toTransfer;
        require(uTHOR.transfer(beneficiary, toTransfer), "xTHOR: uTHOR transfer failed");
        emit TokensReleased(toTransfer);
    }
    
    /**
     * @notice Get the amount of uTHOR tokens currently claimable
     * @dev Accounts for emergency withdrawals by limiting claimable to available balance
     */
    function claimableAmount() external view returns (uint256) {
        uint256 vested = _vestedAmount(block.timestamp);
        uint256 unreleased = vested > released ? vested - released : 0;

        // Limit claimable amount to actual contract balance
        uint256 contractBalance = uTHOR.balanceOf(address(this));
        return unreleased > contractBalance ? contractBalance : unreleased;
    }
    
    /**
     * @notice Get the amount of USDC rewards currently claimable
     * @dev Returns pending rewards from uTHOR (rewards go directly to beneficiary when claimed)
     */
    function claimableRewards() external view returns (uint256) {
        // Pending rewards that can be claimed from uTHOR contract
        // Note: Claimed rewards go directly to beneficiary, not to this contract
        return uTHOR.claimable(address(this));
    }
    
    /**
     * @notice Calculate vested amount at given time
     */
    function _vestedAmount(uint256 timestamp) internal view returns (uint256) {
        if (timestamp < startTime) {
            return 0;
        }
        
        // If we're before cliff, no tokens are vested
        if (timestamp < startTime + cliffDuration) {
            return 0;
        }
        
        // If vesting is complete, return total amount
        if (timestamp >= startTime + vestingDuration) {
            return totalAmount;
        }
        
        // Calculate linear vesting between cliff and end
        uint256 timeFromStart = timestamp - startTime;
        uint256 vestedFromLinear = (totalAmount * timeFromStart) / vestingDuration;
        
        return vestedFromLinear;
    }
    
    /**
     * @notice Owner can revoke the vesting schedule and reclaim unvested tokens
     * @dev This stops all future vesting and allows owner to withdraw unvested uTHOR
     */
    function revokeVesting() external onlyOwner {
        require(totalAmount > 0, "xTHOR: No vesting schedule exists");
        
        // Calculate how much has been vested so far
        uint256 vestedAmount = _vestedAmount(block.timestamp);
        uint256 unvestedAmount = totalAmount - vestedAmount;
        
        // Claim any pending USDC rewards for beneficiary first (internal call to avoid access control)
        if (rewardToken.balanceOf(address(this)) > 0) {
            _claimRewardsInternal(); // ← Use internal function, not external claimRewards()
        }
        
        // Transfer unvested uTHOR back to owner (handle edge case where contract has less than expected)
        uint256 contractBalance = uTHOR.balanceOf(address(this));
        uint256 toWithdraw = unvestedAmount > contractBalance ? contractBalance : unvestedAmount;
        
        if (toWithdraw > 0) {
            require(uTHOR.transfer(owner(), toWithdraw), "xTHOR: uTHOR transfer failed");
        }
        
        // Disable further claiming and mark as revoked
        claimingEnabled = false;
        revoked = true;
        
        emit VestingRevoked(beneficiary, toWithdraw);
    }
    
    /**
     * @notice Owner can enable claiming
     */
    function enableClaiming() external onlyOwner {
        claimingEnabled = true;
        emit ClaimingEnabled();
    }
    
    /**
     * @notice Owner can update the beneficiary address
     */
    function updateBeneficiary(address newBeneficiary) external onlyOwner {
        require(newBeneficiary != address(0), "xTHOR: New beneficiary cannot be zero address");
        address oldBeneficiary = beneficiary;
        beneficiary = newBeneficiary;
        emit BeneficiaryUpdated(oldBeneficiary, newBeneficiary);
    }

    /**
     * @notice Owner can deposit uTHOR tokens to this contract
     */
    function depositUTHOR(uint256 amount) external onlyOwner {
        require(uTHOR.transferFrom(msg.sender, address(this), amount), "xTHOR: uTHOR transfer failed");
    }
    
    /**
     * @notice Emergency function for owner to withdraw all tokens
     * @dev Claims pending USDC rewards first, withdraws all USDC, then withdraws all uTHOR
     */
    function emergencyWithdraw() external onlyOwner {
        // First claim any pending USDC rewards from uTHOR contract
        uTHOR.claimRewards();

        // Withdraw all USDC balance to owner
        uint256 usdcBalance = rewardToken.balanceOf(address(this));
        if (usdcBalance > 0) {
            require(rewardToken.transfer(owner(), usdcBalance), "xTHOR: USDC transfer failed");
            emit EmergencyWithdrawUSDC(usdcBalance);
        }

        // Then withdraw all uTHOR balance to owner
        uint256 uthorBalance = uTHOR.balanceOf(address(this));
        if (uthorBalance > 0) {
            require(uTHOR.transfer(owner(), uthorBalance), "xTHOR: uTHOR transfer failed");
            emit EmergencyWithdrawUTHOR(uthorBalance);
        }

        require(usdcBalance > 0 || uthorBalance > 0, "xTHOR: No tokens to withdraw");
    }
    
    
    /**
     * @notice Get vesting schedule information
     */
    function getVestingInfo() external view returns (
        uint256 _totalAmount,
        uint256 _startTime,
        uint256 _cliffDuration,
        uint256 _vestingDuration,
        uint256 _released,
        uint256 _emergencyWithdrawn,
        bool _claimingEnabled,
        bool _revoked
    ) {
        return (
            totalAmount,
            startTime,
            cliffDuration,
            vestingDuration,
            released,
            emergencyWithdrawn,
            claimingEnabled,
            revoked
        );
    }

    /**
     * @notice Helper function to convert uint256 to string
     */
    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}
