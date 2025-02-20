// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";
import "./openzeppelin_contracts-upgradeable_proxy_utils_UUPSUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC20_extensions_ERC20PausableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC20_extensions_ERC20BurnableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_access_AccessControlUpgradeable.sol";

contract VitaeToken is
    Initializable,
    UUPSUpgradeable,
    ERC20PausableUpgradeable,
    ERC20BurnableUpgradeable,
    AccessControlUpgradeable
{
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // Replace constructor with initializer
    function initialize(uint256 initialSupply) public initializer {
        __ERC20_init("Vitae", "VTAE");
        __ERC20Pausable_init();
        __ERC20Burnable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        // Grant roles
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(MINTER_ROLE, _msgSender());
        _grantRole(PAUSER_ROLE, _msgSender());

        // Mint tokens
        _mint(_msgSender(), initialSupply);
    }

    // Authorize upgrades (UUPS)
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {}

    // Hooks (override `_beforeTokenTransfer` to include Pausable logic)
    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        virtual
        override(ERC20Upgradeable, ERC20PausableUpgradeable)
    {
        super._beforeTokenTransfer(from, to, amount);
    }

    // Custom methods
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function renounceRole(bytes32 role) public {
        _revokeRole(role, _msgSender());
    }
}