// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./contracts_core_ERC20.sol";
import "./openzeppelin_contracts_proxy_utils_Initializable.sol";

/**
 * @title Standard Token (ERC20)
 * @author Factory: CoinFactory.app
 */
contract StandardToken is Initializable, ERC20 {
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _owner,
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint256 _initialSupply
    ) external initializer {
        uint256 _supply = _initialSupply * 10 ** _decimals;
        ERC20.init(
            _name,
            _symbol,
            _decimals,
            _supply
        );
        _mint(_owner, _supply);
    }
}