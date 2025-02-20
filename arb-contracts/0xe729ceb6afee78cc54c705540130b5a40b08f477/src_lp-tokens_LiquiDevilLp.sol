// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;
import {ERC20BurnableUpgradeable} from "./openzeppelin_contracts-upgradeable_token_ERC20_extensions_ERC20BurnableUpgradeable.sol";
import {OwnableUpgradeable} from "./openzeppelin_contracts-upgradeable_access_OwnableUpgradeable.sol";
import "./openzeppelin_contracts_proxy_utils_Initializable.sol";

contract LiquiDevilLp is OwnableUpgradeable, ERC20BurnableUpgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        string memory name,
        string memory symbol
    ) public virtual initializer {
        __ERC20_init_unchained(name, symbol);
        __Ownable_init_unchained();
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}