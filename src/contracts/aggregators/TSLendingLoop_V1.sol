// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// -------------------
// Compatibility
// TC Router V4
// -------------------

import {Owners} from "../../lib/Owners.sol";
import {ReentrancyGuard} from "../../lib/ReentrancyGuard.sol";
import {SafeTransferLib} from "../../lib/SafeTransferLib.sol";
import {IThorchainRouterV4} from "../../interfaces/IThorchainRouterV4.sol";

contract TSLendingLoop_V1 is Owners, ReentrancyGuard {
    using SafeTransferLib for address;

    IThorchainRouterV4 public tcRouter;
    address public currentVault;
    string fuzzyMatchContract;

    constructor(address _tcRouter) {
        tcRouter = IThorchainRouterV4(_tcRouter);
        _setOwner(msg.sender, true);
    }

    function setVault(address _vault) external isOwner {
        currentVault = _vault;
    }

    function setFuzzyMatchContract(
        string calldata _fuzzyMatchContract
    ) external isOwner {
        fuzzyMatchContract = _fuzzyMatchContract;
    }

    function swapOut(
        address token,
        address to,
        uint256 amountOutMin // used as loop counter
    ) public payable nonReentrant {
        require(amountOutMin < 10, "Number must be between 1 and 9.");
        uint256 amount = msg.value;

        if (amountOutMin > 0) {
            amountOutMin--;
            string memory memo = _genLendingMemo(to, amountOutMin);

            tcRouter.depositWithExpiry{value: amount}(
                payable(currentVault),
                address(0),
                amount,
                memo,
                block.timestamp + 1
            );
        } else {
            // no more loops, send the remaining amount to the user
            to.safeTransferETH(amount);
        }
    }

    function _genLendingMemo(
        address toAddress,
        uint256 remainingLoops
    ) internal view returns (string memory) {
        string memory strAddress = _addressToString(toAddress);
        string memory strRemainingLoops = _uintToString(remainingLoops);

        return
            string(
                abi.encodePacked(
                    "$+:e:",
                    strAddress,
                    ":0/1/0:t:0:",
                    fuzzyMatchContract,
                    ":044:", // any fuzzy match to satisfy thornode
                    strRemainingLoops
                )
            );
    }

    function _addressToString(
        address _addr
    ) internal pure returns (string memory) {
        bytes memory alphabet = "0123456789abcdef";
        bytes20 value = bytes20(_addr);
        bytes memory str = new bytes(42); // 2 characters for '0x', and 40 characters for the address
        str[0] = "0";
        str[1] = "x";
        for (uint256 i = 0; i < 20; i++) {
            str[2 + i * 2] = alphabet[uint8(value[i] >> 4)];
            str[3 + i * 2] = alphabet[uint8(value[i] & 0x0f)];
        }
        return string(str);
    }

    function _uintToString(uint _num) public pure returns (string memory) {
        // Convert the single digit number to its ASCII character representation
        bytes memory bstr = new bytes(1);
        bstr[0] = bytes1(uint8(48 + _num));

        return string(bstr);
    }
}
