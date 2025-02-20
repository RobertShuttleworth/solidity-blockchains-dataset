// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "./openzeppelin_contracts-upgradeable_token_ERC1155_ERC1155Upgradeable.sol";
import "./openzeppelin_contracts-upgradeable_access_AccessControlUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC1155_extensions_ERC1155PausableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC1155_extensions_ERC1155BurnableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC1155_extensions_ERC1155SupplyUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";
import "./openzeppelin_contracts-upgradeable_proxy_utils_UUPSUpgradeable.sol";

/// @custom:security-contact devs@syrax.io
contract NFT is Initializable, ERC1155Upgradeable, AccessControlUpgradeable, ERC1155PausableUpgradeable, ERC1155BurnableUpgradeable, ERC1155SupplyUpgradeable, UUPSUpgradeable {
    bytes32 public constant URI_SETTER_ROLE = keccak256("URI_SETTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // Builder Badges
    uint256 public constant BRONZE = 1;
    uint256 public constant SILVER = 2;
    uint256 public constant GOLD = 3;
    uint256 public constant PLATINUM = 4;
    uint256 public constant DIAMOND = 5;

    // User Badges
    uint256 public constant WHITE = 6;
    uint256 public constant YELLOW = 7;
    uint256 public constant ORANGE = 8;
    uint256 public constant RED = 9;
    uint256 public constant PURPLE = 10;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address defaultAdmin, address pauser, address minter, address upgrader)
        initializer public
    {
        __ERC1155_init("https://syrax.io/api/token/{id}");
        __AccessControl_init();
        __ERC1155Pausable_init();
        __ERC1155Burnable_init();
        __ERC1155Supply_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(PAUSER_ROLE, pauser);
        _grantRole(MINTER_ROLE, minter);
        _grantRole(UPGRADER_ROLE, upgrader);
    }

    function setURI(string memory newuri) public onlyRole(URI_SETTER_ROLE) {
        _setURI(newuri);
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function mint(address account, uint256 id, uint256 amount, bytes memory data)
        public
        onlyRole(MINTER_ROLE)
    {
        _mint(account, id, amount, data);
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        public
        onlyRole(MINTER_ROLE)
    {
        _mintBatch(to, ids, amounts, data);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyRole(UPGRADER_ROLE)
        override
    {}

    // The following functions are overrides required by Solidity.

    function _update(address from, address to, uint256[] memory ids, uint256[] memory values)
        internal
        override(ERC1155Upgradeable, ERC1155PausableUpgradeable, ERC1155SupplyUpgradeable)
    {
        super._update(from, to, ids, values);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}