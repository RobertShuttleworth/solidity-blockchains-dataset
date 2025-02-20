// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "./contracts_libraries_Tax.sol";
import "./openzeppelin_contracts_token_ERC20_ERC20.sol";
import "./openzeppelin_contracts_token_ERC20_extensions_ERC20Burnable.sol";

contract Token is ERC20, ERC20Burnable {
    using Tax for uint256;

    uint256 private constant _swapTax = 5e16; // 5% swap tax
    address private _developer;
    address private _stake;
    address private _pair;

    constructor() ERC20("Test DeFiDog Token", "TDDOG") {
        _developer = msg.sender;
    }

    function setup(address stakeAddress) external {
        require(msg.sender == _developer, "Token: Unauthorized");
        require(_stake == address(0), "Token: stake already set");
        _stake = stakeAddress;
    }

    function setPair(address pairAddress) external {
        require(msg.sender == _stake, "Token: Unauthorized");
        require(_pair == address(0), "Token: pair already set");
        _pair = pairAddress;
    }

    function mint(address to, uint256 amount) external {
        require(msg.sender == _stake, "Token: Unauthorized");
        _mint(to, amount);
    }

    function _update(address sender, address recipient, uint256 amount) internal override {
        if (!isSwap(msg.sender, sender, recipient)) {
            super._update(sender, recipient, amount);
            return;
        }
        uint256 tax = amount.tax(_swapTax);
        super._update(sender, _stake, tax);
        super._update(sender, recipient, amount - tax);
    }

    function isSwap(address caller, address sender, address recipient) internal view returns (bool) {
        if (_pair == address(0)) return false;
        if (sender != _pair && recipient != _pair) return false;
        if (caller == _stake) return false;
        return true;
    }
}