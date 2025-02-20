// @author Daosourced
// @date December 23rd, 2022
pragma solidity ^0.8.0;

interface IKeywordStorage {
    
    event SetKeyword(uint256 indexed tokenId, string keyword);
    
    event RemoveKeyword(uint256 indexed tokenId, string keyword);
    
    event NewKeyword(uint256 indexed tokenId, uint256 indexed keywordPresetId, string keyword);

    event ResetKeywords(uint256 tokenId);

    /**
    * @notice removes and exisiting keyword
    * @param tokenId tokenId the kewyword belongs to
    * @param keyword the string representation the keyword;
    */
    function removeKeyword(uint256 tokenId, string memory keyword) external;

    /**
    * @notice removes an existing list of keyword
    * @param tokenId tokenId the kewyword belongs to
    * @param keywords the string representation the keyword;
    */
    function removeKeywords(uint256 tokenId, string[] memory keywords) external;

    /**
    * @notice adds a new keyword 
    * @param tokenId tokenId belonging to the keyword
    * @param keyword string representation of the keyword
    */
    function addKeyword(uint256 tokenId, string memory keyword) external;
    
    /**
    * @notice  adds multiple keywords
    * @param tokenId tokenId belonging to the keyword
    * @param keywords list of string representation of keywords
    */
    function addKeywords(uint256 tokenId, string[] memory keywords) external;

    /**
    * @notice returns the keyword belonging to tokenId
    * @param tokenId the tokenId the keyword belongs
    * @param keyword the string representation of the keyword
    */
    function getKeyword(uint256 tokenId, string memory keyword) external view returns (string memory);
    
    /** 
    * @notice returns the keywords belonging to tokenId
    * @param tokenId containing the keywords record
    */
    function getKeywords(uint256 tokenId) external view returns (string[] memory);
}