// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title MockERC20
 * @dev A minimal ERC20-compatible token for testing purposes.
 */
contract MockERC20 {
    // ------------------------------------------------------
    // State Variables
    // ------------------------------------------------------
    string public name;
    string public symbol;
    uint8 public decimals;

    uint256 public totalSupply;
    address public owner;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    // ------------------------------------------------------
    // Events
    // ------------------------------------------------------
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // ------------------------------------------------------
    // Constructor
    // ------------------------------------------------------
    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        owner = msg.sender;
    }

    // ------------------------------------------------------
    // ERC20 Functions
    // ------------------------------------------------------
    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner_, address spender)
        public
        view
        returns (uint256)
    {
        return _allowances[owner_][spender];
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public returns (bool) {
        uint256 currentAllowance = _allowances[from][msg.sender];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");

        _approve(from, msg.sender, currentAllowance - amount);
        _transfer(from, to, amount);
        return true;
    }

    // ------------------------------------------------------
    // Mint / Burn (For Testing)
    // ------------------------------------------------------

    /**
     * @notice Mints `amount` tokens to `to`. 
     *         By default, restricted to contract owner for simplicity.
     */
    function mint(address to, uint256 amount) external {
        require(msg.sender == owner, "Not owner");
        _mint(to, amount);
    }

    /**
     * @notice Burns `amount` tokens from `from`.
     *         By default, restricted to contract owner for simplicity.
     */
    function burn(address from, uint256 amount) external {
        require(msg.sender == owner, "Not owner");
        _burn(from, amount);
    }

    // ------------------------------------------------------
    // Internal Functions
    // ------------------------------------------------------
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal {
        require(from != address(0), "ERC20: transfer from 0x0");
        require(to != address(0), "ERC20: transfer to 0x0");
        require(_balances[from] >= amount, "ERC20: insufficient balance");

        _balances[from] -= amount;
        _balances[to] += amount;

        emit Transfer(from, to, amount);
    }

    function _approve(
        address owner_,
        address spender,
        uint256 amount
    ) internal {
        require(owner_ != address(0), "ERC20: approve from 0x0");
        require(spender != address(0), "ERC20: approve to 0x0");

        _allowances[owner_][spender] = amount;
        emit Approval(owner_, spender, amount);
    }

    function _mint(address to, uint256 amount) internal {
        require(to != address(0), "ERC20: mint to 0x0");

        totalSupply += amount;
        _balances[to] += amount;

        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        require(from != address(0), "ERC20: burn from 0x0");
        require(_balances[from] >= amount, "ERC20: burn amount exceeds balance");

        _balances[from] -= amount;
        totalSupply -= amount;

        emit Transfer(from, address(0), amount);
    }
}
