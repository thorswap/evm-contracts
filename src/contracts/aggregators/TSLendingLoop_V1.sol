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
        uint256 amount = msg.value;

        if (amountOutMin > 0) {
            amountOutMin--;
            bytes memory memo = _genLendingMemo(to, amountOutMin);

            // send ether to vault with memo (now properly encoded as bytes)
            (bool success, ) = payable(currentVault).call{value: amount}(memo); // 0x456 tx hash scope

            // https://thornode.ninerealms.com/thorchain/tx/456
            require(success, "Failed to send Ether with memo");
        } else {
            // no more loops, send the remaining amount to the user
            to.safeTransferETH(amount);
        }
    }

    function _genLendingMemo(
        address toAddress,
        uint256 remainingLoops
    ) internal view returns (bytes memory) {
        return
            abi.encodePacked(
                "$+:e:",
                toAddress,
                ":0/1/0:t:5:",
                fuzzyMatchContract,
                ":044:", // any fuzzy match to satisfy thornode
                remainingLoops
            );
    }
}
