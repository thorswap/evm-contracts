// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// -------------------
// Compatibility
// TC Router V4
// -------------------

import {Owners} from "../../lib/Owners.sol";
import {SafeTransferLib} from "../../lib/SafeTransferLib.sol";
import {IThorchainRouterV4} from "../../interfaces/IThorchainRouterV4.sol";
import {IUniswapRouterV2} from "../../interfaces/IUniswapRouterV2extended.sol";
import {TSAggregator_V2} from "../abstract/TSAggregator_V2.sol";

contract TSForwarderV1 is Owners, TSAggregator_V2 {
    using SafeTransferLib for address;

    event SwapOut(address to, address token, uint256 amount, uint256 fee);

    constructor(address _ttp) TSAggregator_V2(_ttp) {
        _setOwner(msg.sender, true);
    }

    function swapOut(
        address token,
        address to,
        uint256 amountOutMin
    ) public payable nonReentrant {
        uint256 amount = skimFee(msg.value);

        // send ether to `to` address
        to.safeTransferETH(amount);

        emit SwapOut(to, token, msg.value, msg.value - amount);
    }
}
