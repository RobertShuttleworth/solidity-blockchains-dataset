// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.28;

import {ERC20Upgradeable} from "./openzeppelin_contracts-upgradeable_token_ERC20_ERC20Upgradeable.sol";
import {ERC20BurnableUpgradeable} from "./openzeppelin_contracts-upgradeable_token_ERC20_extensions_ERC20BurnableUpgradeable.sol";
import {ERC20FlashMintUpgradeable} from "./openzeppelin_contracts-upgradeable_token_ERC20_extensions_ERC20FlashMintUpgradeable.sol";
import {ERC20PausableUpgradeable} from "./openzeppelin_contracts-upgradeable_token_ERC20_extensions_ERC20PausableUpgradeable.sol";
import {ERC20PermitUpgradeable} from "./openzeppelin_contracts-upgradeable_token_ERC20_extensions_ERC20PermitUpgradeable.sol";
import {Initializable} from "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";
import {OwnableUpgradeable} from "./openzeppelin_contracts-upgradeable_access_OwnableUpgradeable.sol";

contract DovCoin is
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    ERC20PausableUpgradeable,
    OwnableUpgradeable,
    ERC20PermitUpgradeable,
    ERC20FlashMintUpgradeable
{
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner) public initializer {
        __ERC20_init("DovCoin", "DOV");
        __ERC20Burnable_init();
        __ERC20Pausable_init();
        __Ownable_init(initialOwner);
        __ERC20Permit_init("DovCoin");
        __ERC20FlashMint_init();
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    // The following functions are overrides required by Solidity.

    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20Upgradeable, ERC20PausableUpgradeable) {
        super._update(from, to, value);
    }
}