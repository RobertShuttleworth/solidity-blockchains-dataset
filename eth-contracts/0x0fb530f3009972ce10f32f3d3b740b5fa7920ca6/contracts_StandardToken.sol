// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./contracts_base_ERC20.sol";
import "./openzeppelin_contracts_proxy_utils_Initializable.sol";

contract StandardToken is Initializable, ERC20 {
    address public owner;

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _owner,
        string calldata _name,
        string calldata _symbol,
        uint8 _decimals,
        uint256 _initialSupply
    ) external initializer {
        uint256 _supply = _initialSupply * 10 ** _decimals;
        owner = _owner;
        ERC20.init(_name, _symbol, _decimals, _supply);
        _mint(_owner, _supply);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner is the zero address");
        owner = newOwner;
    }
}