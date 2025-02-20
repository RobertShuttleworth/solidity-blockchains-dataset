// SPDX-License-Identifier: ISC
pragma solidity 0.8.27;

// Importing OpenZeppelin and custom libraries
import {ERC721EnumerableUpgradeable} from "./lib_openzeppelin-contracts-upgradeable_contracts_token_ERC721_extensions_ERC721EnumerableUpgradeable.sol";
import {AccessControlUpgradeable} from "./lib_openzeppelin-contracts-upgradeable_contracts_access_AccessControlUpgradeable.sol";
import {Initializable} from "./lib_openzeppelin-contracts-upgradeable_contracts_proxy_utils_Initializable.sol";
import {LibString} from "./lib_solady_src_utils_LibString.sol";
import {BonusErrors} from "./src_libraries_BonusErrors.sol";
import {BonusEvents} from "./src_libraries_BonusEvents.sol";

/**
 * @title BonusBooster
 * @notice ERC721-based minting contract for managing user boosts. Designed for upgradeability via Transparent Proxy.
 */
contract BonusBooster is ERC721EnumerableUpgradeable, AccessControlUpgradeable {
    using LibString for uint256; // String conversion utilities

    // Role definitions
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    // Storage variables
    string private baseUri;                  // Base URI for token metadata
    address public minterAddress;                // The only user that is allowed to mint and boost (besides admin)
    mapping(address => bool) public mintStatusOf; // Tracks if a user has minted
    mapping(address => uint8) public boostsOf;    // Tracks the number of boosts per user
    uint256 private currentIndex;           // Current token index

    // Version and upgradeability
    uint256 public constant VERSION = 1;    // Contract version
    uint256[50] private __gap;              // Reserved storage for upgrades

    /**
     * @notice Initializes the contract.
     * @param _baseUri Base URI for token metadata.
     * @param _minterAddress The minter address
     */
    function initialize(string memory _baseUri, address _minterAddress) public initializer {
        __ERC721_init("BonusBooster", "BB");
        __ERC721Enumerable_init();
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, _minterAddress);

        minterAddress = _minterAddress;
        baseUri = _baseUri;
        currentIndex = 1;
    }


    /**
     * @notice Updates the minter address
     * @param _minterAddress The minter address
     */
    function updatePublicKey(address _minterAddress) external onlyRole(DEFAULT_ADMIN_ROLE)  {
        if (hasRole(DEFAULT_ADMIN_ROLE, _minterAddress)) revert BonusErrors.CANNOT_REVOKE_FROM_ADMIN();
        _revokeRole(MINTER_ROLE, minterAddress);
        _grantRole(MINTER_ROLE, _minterAddress);
        emit BonusEvents.MinterAddressUpdated(minterAddress, _minterAddress);
        minterAddress = _minterAddress;
    }

    /**
     * @notice Mints a booster token for the user.
     * @param userAddress Address of the user.
     */
    function mintBooster(address userAddress) external onlyRole(MINTER_ROLE) {
        // Validation checks
        if (mintStatusOf[userAddress]) revert BonusErrors.ALREADY_MINTED();
        mintStatusOf[userAddress] = true;
        _safeMint(userAddress, currentIndex++);
    }

    /**
     * @notice Uses a booster token for boosting.
     * @param _id Token ID to be used.
     * @param userAddress Address of the user.
     */
    function boost(uint256 _id, address userAddress) external onlyRole(MINTER_ROLE) {
        // Validation checks
        if (balanceOf(userAddress) < 1) revert BonusErrors.USER_DOESNT_OWN_ANY_BOOSTER();
        if (ownerOf(_id) != userAddress) revert BonusErrors.NOT_AN_OWNER();

        boostsOf[userAddress]++;
        _burn(_id);

        emit BonusEvents.Boost(userAddress, boostsOf[userAddress], _id);
    }

    /**
     * @notice Updates the base URI.
     * @param _newBaseUri New base URI.
     */
    function resetBaseUri(string memory _newBaseUri) external onlyRole(DEFAULT_ADMIN_ROLE) {
        baseUri = _newBaseUri;
        emit BonusEvents.BaseUriUpdated(_newBaseUri);
    }

    /**
     * @notice Returns the base URI for token metadata.
     * @return Base URI string.
     */
    function _baseURI() internal view override returns (string memory) {
        return baseUri;
    }

    /**
     * @notice Returns the token URI for a given token ID.
     * @param id Token ID.
     * @return Token URI.
     */
    function tokenURI(uint256 id) public view override returns (string memory) {
        // Concatenating strings, designed this way in order to having the baseUri upgradable
        return string.concat(baseUri, "/", id.toString());
    }

    // Override the supportsInterface function to handle both base contracts
    function supportsInterface(bytes4 interfaceId) public view virtual override(AccessControlUpgradeable, ERC721EnumerableUpgradeable) returns (bool) {
        return AccessControlUpgradeable.supportsInterface(interfaceId) || ERC721EnumerableUpgradeable.supportsInterface(interfaceId);
    }
}