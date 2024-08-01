// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IERC20} from "../../interfaces/IERC20.sol";
import {Owners} from "../../lib/Owners.sol";

abstract contract PaymentGated is Owners {
    address public feeToken;
    uint256 public feeAmount; // fee amount per 30 day periods

    mapping(address => uint256) private paidUsers; // Stores the accessExpiry timestamp

    event PaymentReceived(address indexed user, uint256 amount, uint256 expiry);
    event AccessGranted(address indexed user, uint256 expiry);

    constructor(address _feeToken, uint256 _feeAmount) {
        feeToken = _feeToken;
        feeAmount = _feeAmount;
    }

    function updateFeeAmount(uint256 newFeeAmount) external isOwner {
        feeAmount = newFeeAmount;
    }

    function pay(address clientAddress) external {
        require(clientAddress != address(0), "Invalid client address");
        require(feeAmount > 0, "Fee amount not set");
        
        IERC20 token = IERC20(feeToken);
        uint256 amount = feeAmount;

        // Ensure the fee amount is a multiple of the fee amount
        require(amount % feeAmount == 0, "Amount must be a multiple of the fee amount");

        // Transfer fee from client to contract
        token.transferFrom(msg.sender, address(this), amount);

        // Calculate new access expiry
        uint256 periods = amount / feeAmount;
        uint256 newExpiry = block.timestamp + (periods * 30 days);

        paidUsers[clientAddress] = newExpiry;

        emit PaymentReceived(clientAddress, amount, newExpiry);
    }

    function grantAccess(address user, uint256 accessExpiry) external isOwner {
        require(user != address(0), "Invalid user address");
        require(accessExpiry > block.timestamp, "Expiry must be in the future");

        paidUsers[user] = accessExpiry;

        emit AccessGranted(user, accessExpiry);
    }

    modifier isPaidUser(address user) {
        require(paidUsers[user] >= block.timestamp, "Access not paid or expired");
        _;
    }

    function getAccessExpiry(address user) external view returns (uint256) {
        return paidUsers[user];
    }

    function withdraw(address recipient) external isOwner {
        IERC20 token = IERC20(feeToken);
        token.transfer(recipient, token.balanceOf(address(this)));
    }
}
