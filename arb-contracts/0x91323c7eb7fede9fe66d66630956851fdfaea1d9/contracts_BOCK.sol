// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {ERC20Upgradeable} from "./openzeppelin_contracts-upgradeable_token_ERC20_ERC20Upgradeable.sol";
import {ERC20BurnableUpgradeable} from "./openzeppelin_contracts-upgradeable_token_ERC20_extensions_ERC20BurnableUpgradeable.sol";
import {Initializable} from "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";
import {OwnableUpgradeable} from "./openzeppelin_contracts-upgradeable_access_OwnableUpgradeable.sol";
import {ERC20PermitUpgradeable} from "./openzeppelin_contracts-upgradeable_token_ERC20_extensions_ERC20PermitUpgradeable.sol";

/// @custom:security-contact mugi@onchainaustria.at
contract BOCK is
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    OwnableUpgradeable,
    ERC20PermitUpgradeable
{
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner) public initializer {
        __ERC20_init("onchainaustria.at", "BOCK");
        __ERC20Burnable_init();
        __Ownable_init(initialOwner);
        __ERC20Permit_init("onchainaustria.at");
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}