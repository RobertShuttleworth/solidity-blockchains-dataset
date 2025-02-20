// @author Daosourced.
// @date June 16th, 2021
pragma solidity ^0.8.0;

import './openzeppelin_contracts-upgradeable_token_ERC721_extensions_IERC721MetadataUpgradeable.sol';
import './openzeppelin_contracts-upgradeable_token_ERC721_IERC721ReceiverUpgradeable.sol';

import './contracts_IERC1967.sol';
import './contracts_IRecordStorage.sol';
import './contracts_IKeywordStorage.sol';
import './contracts_IReverseRegistry.sol';
import './contracts_IRootRegistry.sol';
import './contracts_maticnetwork_IChildToken.sol';

interface IHDNSRegistry is
    IERC1967,
    IERC721MetadataUpgradeable,
    IERC721ReceiverUpgradeable,
    IKeywordStorage,
    IRecordStorage,
    IReverseRegistry,
    IRootRegistry,
    IChildToken
{
    event NewURI(uint256 indexed tokenId, string uri);

    event NewURIPrefix(string prefix);
    
    event SetDependencies(address mintingManager, address keywordStakingManager);

    /**
     * @dev Function to set the token URI Prefix for all tokens.
     * @param prefix string URI to assign
     */
    function setTokenURIPrefix(string calldata prefix) external;

    /**
     * @dev Returns whether the given spender can transfer a given token ID.
     * @param spender address of the spender to query
     * @param tokenId uint256 ID of the token to be transferred
     * @return bool whether the msg.sender is approved for the given token ID,
     * is an operator of the owner, or is the owner of the token
     */
    function isApprovedOrOwner(address spender, uint256 tokenId) external view returns (bool);

    /**
     * @dev Gets the resolver of the specified token ID.
     * @param tokenId uint256 ID of the token to query the resolver of
     * @return address currently marked as the resolver of the given token ID
     */
    function resolverOf(uint256 tokenId) external view returns (address);

    /**
     * @dev Provides namehashe of the provided domain labels.
     * @param labels array of domain labels splitted by '.' (for `aaa.bbb.crypto` it will be [`aaa`, `bbb`, `crypto`])
     */
    function namehash(string[] calldata labels) external pure returns (uint256);

    /**
     * @dev Existence of token.
     * @param tokenId uint256 ID of the token
     */
    function exists(uint256 tokenId) external view override returns (bool);

    /**
     * @dev Transfer domain ownership without resetting domain records.
     * @param to address of new domain owner
     * @param tokenId uint256 ID of the token to be transferred
     */
    function setOwner(address to, uint256 tokenId) external;

    /**
     * @dev Burns `tokenId`. See {ERC721-_burn}.
     *
     * Requirements:
     *
     * - The caller must own `tokenId` or be an approved operator.
     */
    function burn(uint256 tokenId) external;

    /**
     * @dev Mints root token.
     * @param tokenId id of TLD token.
     * @param uri TLD URI.
     */
    function mintTLD(uint256 tokenId, string calldata uri) external;

    /**
     * @dev (Deprecated) mints token with records
     * @param to address to mint the new SLD or subdomain to
     * @param labels array of SLD or subdomain name labels splitted by '.' to mint.
     * @param keys New record keys
     * @param values New record values
     */
    function mintWithRecords(
        address to,
        string[] calldata labels,
        string[] calldata keys,
        string[] calldata values
    ) external;

    /**
     * @dev mints token with records
     * @param to address to mint the new SLD or subdomain to
     * @param labels array of SLD or subdomain name labels splitted by '.' to mint.
     * @param keys New record keys
     * @param values New record values
     * @param withReverse Flag whether to install reverse resolution
     */
    function mintWithRecords(
        address to,
        string[] calldata labels,
        string[] calldata keys,
        string[] calldata values,
        bool withReverse
    ) external;

    /**
     * @dev Adds ProxyReader address
     * @param addr address of ProxyReader
     */
    function addProxyReader(address addr) external;

    /**
     * @notice burns the tokenId if it is expired and grace period is reached 
     * @param tokenId the token of the domain
     */
    function repoDeadDomain(uint256 tokenId) external;
    
    /**
     * @notice burns the tokenId if it is expired and grace period is reached 
     * @param tokenId the token of the domain
     * @param newExpiration new expiration timestamp of the the hashtag
     */
    function extendDeadman(uint256 tokenId, string memory newExpiration) external;

    /**
     * @notice sets the minting manager and the keyword staking manager as dependencies on the registry
     * @param mintingManager the token of the domain
     * @param keywordStakingManager new expiration timestamp of the the hashtag
     */
    function setDependencies(address mintingManager, address keywordStakingManager) external;
    
    /**
     * @notice returns the dependencies of the registry
     */
    function dependencies() external view returns (address mintingManager, address keywordStakingManager);
}