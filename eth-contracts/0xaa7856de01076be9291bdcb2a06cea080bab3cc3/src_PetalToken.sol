// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./lib_openzeppelin-contracts-upgradeable_contracts_token_ERC20_ERC20Upgradeable.sol";
import "./lib_openzeppelin-contracts-upgradeable_contracts_access_OwnableUpgradeable.sol";
import "./lib_openzeppelin-contracts-upgradeable_contracts_token_ERC20_extensions_ERC20PermitUpgradeable.sol";
import "./lib_openzeppelin-contracts-upgradeable_contracts_token_ERC20_extensions_ERC20BurnableUpgradeable.sol";
import "./lib_openzeppelin-contracts-upgradeable_contracts_token_ERC20_extensions_ERC20VotesUpgradeable.sol";
import "./lib_openzeppelin-contracts-upgradeable_contracts_proxy_utils_Initializable.sol";
import "./lib_openzeppelin-contracts-upgradeable_contracts_proxy_utils_UUPSUpgradeable.sol";

/// @title PetalToken - An ownable ERC20 Token with upgradeable, burnable, permit, and voting functionalities
/// @notice The proxy and the token are both owned through OwnableUpgradeable.
/// @dev This contract implements the ERC20 token standard with additional features such as voting, burning, permits, and upgradeability.
///      Additionally the contract is owned through Open Zeppelin Ownable standard. Token functions and upgrade functions are protected through `onlyOwner` modifier.
///      The contract uses OpenZeppelin libraries and is designed to be upgradeable using UUPS proxy pattern.
contract PetalToken is
    Initializable,
    ERC20Upgradeable,
    OwnableUpgradeable,
    ERC20PermitUpgradeable,
    ERC20VotesUpgradeable,
    ERC20BurnableUpgradeable,
    UUPSUpgradeable
{
    /// @notice Constructor that prevents the implementation contract from being initialized.
    /// @dev Disables the initializer to prevent the implementation contract from being initialized directly.
    ///      This is part of the UUPS proxy upgrade pattern.
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the Token contract with the given owner and mints initial supply.
    /// @dev This function initializes the contract, setting up the token name, symbol, and other features like permit, voting, and burnable functionality.
    ///      It also mints an initial supply of tokens to the deployer's address.
    /// @param initialOwner The address that will be set as the owner of the token and the proxy.
    function initialize(address initialOwner) public initializer {
        __ERC20_init("PETAL", "PET");
        __Ownable_init(initialOwner);
        __ERC20Permit_init("PETAL");
        __ERC20Burnable_init();
        __ERC20Votes_init();
        __UUPSUpgradeable_init();
    }

    /// @notice Mints new tokens to the specified address.
    /// @dev Only the owner can call this function to mint new tokens.
    /// @param to The address to which the newly minted tokens will be sent.
    /// @param amount The amount of tokens to be minted.
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    /// @notice Authorizes an upgrade to a new implementation of the contract.
    /// @dev This function is required by the UUPS upgradeable contract and ensures only the owner can authorize an upgrade.
    ///      This function is invoked through upgradeToAndCall(address newImplementation, bytes memory data)
    /// @param newImplementation The address of the new implementation contract.
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /// @notice Internal function to handle token transfer updates for voting purposes and standard ERC20 balance accounting.
    /// @dev This function overrides the _update function in both ERC20 and ERC20Votes, and is used to keep track of voting power changes when tokens are transferred.
    /// @param from The address from which tokens are transferred.
    /// @param to The address to which tokens are transferred.
    /// @param value The amount of tokens transferred.
    function _update(address from, address to, uint256 value)
        internal
        override(ERC20Upgradeable, ERC20VotesUpgradeable)
    {
        ERC20VotesUpgradeable._update(from, to, value);
    }

    /// @notice Returns the number of permit nonces for the given owner.
    /// @dev This function overrides the nonces function in both ERC20Permit and NoncesUpgradeable to return the correct nonce value for permits.
    /// @param owner The address of the token owner.
    /// @return The current nonce for the given owner.
    function nonces(address owner) public view override(ERC20PermitUpgradeable, NoncesUpgradeable) returns (uint256) {
        return NoncesUpgradeable.nonces(owner);
    }
}