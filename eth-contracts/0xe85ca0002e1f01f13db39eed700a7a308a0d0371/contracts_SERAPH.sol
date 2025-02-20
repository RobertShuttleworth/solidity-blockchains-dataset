// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Initializable} from "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC20_ERC20Upgradeable.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC20_extensions_ERC20BurnableUpgradeable.sol";

contract SERAPH is Initializable, ERC20Upgradeable, ERC20BurnableUpgradeable {
    constructor() {
        _disableInitializers();
    }

    function initialize(string memory name, string memory symbol, uint256 initialSupply, address owner) public virtual initializer {
        __ERC20_init(name, symbol);
        __ERC20Burnable_init();
        _mint(owner, initialSupply * (10 ** decimals()));
    }
}