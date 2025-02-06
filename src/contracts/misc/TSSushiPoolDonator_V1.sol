// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IWETH9} from "../../interfaces/IWETH9.sol";

interface IUniswapV2Pair {
    function sync() external;
}

contract TSSushiPoolDonator_V1 {
    address public wethAddress; // Address of the WETH token
    address public pairAddress; // Address of the UniswapV2Pair contract

    constructor(address _wethAddress, address _pairAddress) {
        wethAddress = _wethAddress;
        pairAddress = _pairAddress;
    }

    receive() external payable {
        // Wrap the received ETH into WETH
        IWETH9(wethAddress).deposit{value: msg.value}();

        // Transfer the WETH to the pair contract
        require(
            IWETH9(wethAddress).transfer(pairAddress, msg.value),
            "WETH transfer failed"
        );

        // Call sync on the pair contract
        IUniswapV2Pair(pairAddress).sync();
    }
}
