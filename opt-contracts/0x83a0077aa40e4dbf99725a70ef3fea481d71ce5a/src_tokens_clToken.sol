// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "./external_openzeppelin_contracts-upgradeable_token_ERC20_ERC20Upgradeable.sol";
import "./external_openzeppelin_contracts-upgradeable_token_ERC20_extensions_ERC20BurnableUpgradeable.sol";
import "./external_openzeppelin_contracts-upgradeable_token_ERC20_extensions_ERC20PausableUpgradeable.sol";
import "./external_openzeppelin_contracts-upgradeable_access_AccessControlUpgradeable.sol";
import "./external_openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";

contract CLToken is
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    ERC20PausableUpgradeable,
    AccessControlUpgradeable
{
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    constructor() {
        /// @custom:oz-upgrades-unsafe-allow constructor
        _disableInitializers();
    }

    function initialize(
        string memory name,
        string memory symbol,
        address defaultAdmin,
        address pauser
    ) public initializer {
        __ERC20_init(name, symbol);
        __ERC20Burnable_init();
        __ERC20Pausable_init();
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(PAUSER_ROLE, pauser);
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
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