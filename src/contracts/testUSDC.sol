// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract testUSDC is ERC20 {
    constructor() ERC20("Usdc", "USDC") {
        _mint(msg.sender, 1000e6);
    }

    function mint(address user, uint256 amount) external {
        _mint(user, amount);
    }

    function burn(address user, uint256 amount) external {
        _burn(user, amount);
    }
}
