// @author Daosourced
// @date January 7th, 2023

pragma solidity ^0.8.0;

interface IMintingManager {

    struct BulkSLDIssueRequest {
        address to;
        string label;
        uint256 tld;
        string[] keys;
        string[] values;
    }

    struct BulkSubSLDIssueRequest {
        address to;
        string[] labels;
        uint256 tld;
        string[] keys;
        string[] values;
    }
    
    event NewTld(uint256 indexed tokenId, string tld);
    
    event RemoveTld(uint256 indexed tokenId);

    event ExtendDeadman(uint256 indexed tokenId, string indexed expiration);

    event CreateDomainResell(uint256 indexed tokenId, address indexed reseller, string price);
    
    event CancelResell(uint256 indexed tokenId, address indexed reseller);

    /**
     * @dev Adds new TLD
     */
    function addTld(string calldata tld) external;

    /**
     * @dev Removes TLD
     */
    function removeTld(uint256 tokenId) external;

    /**
     * @dev (Deprecated) Issues a domain with records.
     * @param to address to issue the new SLD or subdomain to.
     * @param labels array of SLD or subdomain name labels splitted by '.' to issue.
     * @param keys Record keys.
     * @param values Record values.
     */
    function issueWithRecords(
        address to,
        string[] calldata labels,
        string[] calldata keys,
        string[] calldata values
    ) external;

    /**
     * @dev Issues a domain with records.
     * @param to address to issue the new SLD or subdomain to.
     * @param labels array of SLD or subdomain name labels splitted by '.' to issue.
     * @param keys Record keys.
     * @param values Record values.
     * @param withReverse Flag indicating whether to install reverse resolution
     */
    function issueWithRecords(
        address to,
        string[] calldata labels,
        string[] calldata keys,
        string[] calldata values,
        bool withReverse
    ) external;

    /**
     * @dev Issues a SLD in bulk
     * @param requests List of requests for domains to issue
     */
    function bulkIssue(BulkSLDIssueRequest[] calldata requests) external;

    /**
     * @dev Function to set the token URI Prefix for all tokens.
     * @param prefix string URI to assign
     */
    function setTokenURIPrefix(string calldata prefix) external;
        
    /**
    * @notice gets the string representation of top level domain
    * @param tldId the integer the tld string is mapped to  
    */
    function getTLD(uint256 tldId) external view returns(string memory tld);

    /**
    * @notice extends deadman
    * @param tokenId token id of the hashtag in question
    * @param expiration switch date (tokenId expiry date) of the deadman
    */
    function extendDeadmanSwitch(uint256 tokenId, string calldata expiration) external;

    /**
    * @notice burns expired domain 
    * @param tokenId token id of the hashtag in question
    * @dev token will only be burned if the the grace period is met
    */
    function repoDeadDomain(uint256 tokenId) external;

    /**
     * @notice updates metadata on domain and transfers to minting manager for resell
     * @param tokenId the token of the domain
     * @param usdPrice usd price for resell
     */
    function createResell(uint256 tokenId, string memory usdPrice) external;
    
    /**
     * @notice cancels a resell request
     * @param tokenId the token of the domain
     */
    function cancelResell(uint256 tokenId) external;

    /**
     * @notice cancels resel request for tokenId
     * @param tokenId the token of the domain
     */
    function resell(uint256 tokenId, address buyer) external;

    /**
     * @notice pauses the contract
     */
    function pause() external;
    
    /**
     * @notice unpauses the contract
     */
    function unpause() external;

    /**
     * @notice sets dependencies on the registry contract
     * @param mintingManager address of the minting manager
     * @param keywordStakingManager address of the keyword staking manager
     */
    function setRegistryDependencies(address mintingManager, address keywordStakingManager) external; 
}