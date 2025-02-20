// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import {ERC721EnumerableUpgradeable} from "./openzeppelin_contracts-upgradeable_token_ERC721_extensions_ERC721EnumerableUpgradeable.sol";
import {IERC721Upgradeable, ERC721Upgradeable} from "./openzeppelin_contracts-upgradeable_token_ERC721_ERC721Upgradeable.sol";
import {ERC721URIStorageUpgradeable} from "./openzeppelin_contracts-upgradeable_token_ERC721_extensions_ERC721URIStorageUpgradeable.sol";
import {IERC2981Upgradeable} from "./openzeppelin_contracts-upgradeable_interfaces_IERC2981Upgradeable.sol";
import {ICreatorToken} from "./contracts_interfaces_ICreatorToken.sol";

contract EarthmetaERC721V2 is ERC721EnumerableUpgradeable, ERC721URIStorageUpgradeable, ICreatorToken {
    address public earthmeta;

    /// @notice the operators allowed to transfer the NFTs.
    mapping(address => bool) public operators;
    address public validator;

    modifier onlyOwner() {
        require(msg.sender == earthmeta, "EMT: Caller is not Earthmeta");
        _;
    }

    function __init_EarthmetaERC721(address _earthmeta) internal {
        earthmeta = _earthmeta;
    }

    /// @notice Mint a token, only earthmeta can call this function..
    /// @param _tokenId token id.
    /// @param _to token owner.
    function mint(uint256 _tokenId, string memory _tokenUri, address _to) external onlyOwner {
        super._safeMint(_to, _tokenId);
        super._setTokenURI(_tokenId, _tokenUri);
    }

    function setTokenURI(uint256 _tokenId, string memory _tokenURI) external onlyOwner {
        _setTokenURI(_tokenId, _tokenURI);
    }

    /// @notice Burn the token, only the owner can call this function.
    /// @param _tokenId token id.
    function burn(uint256 _tokenId) external {
        require(_msgSender() == ownerOf(_tokenId) || _msgSender() == earthmeta, "EMT: Caller is not Earthmeta");
        _burn(_tokenId);
    }

    /// @notice Override _beforeTokenTransfer
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) internal virtual override(ERC721Upgradeable, ERC721EnumerableUpgradeable) {
        super._beforeTokenTransfer(from, to, firstTokenId, batchSize);
    }

    /// @notice Override _burn
    function _burn(uint256 tokenId) internal virtual override(ERC721Upgradeable, ERC721URIStorageUpgradeable) {
        super._burn(tokenId);
    }

    /// @notice Override tokenURI
    function tokenURI(
        uint256 tokenId
    ) public view virtual override(ERC721Upgradeable, ERC721URIStorageUpgradeable) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    /// @notice Override supportsInterface
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC721Upgradeable, ERC721EnumerableUpgradeable) returns (bool) {
        return interfaceId == type(IERC2981Upgradeable).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @notice Override isApprovedForAll
    function isApprovedForAll(
        address _owner,
        address _operator
    ) public view virtual override(IERC721Upgradeable, ERC721Upgradeable) returns (bool) {
        if (operators[_operator]) {
            return true;
        }
        return super.isApprovedForAll(_owner, _operator);
    }

    /// @notice Override _afterTokenTransfer
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) internal virtual override {
        super._afterTokenTransfer(from, to, firstTokenId, batchSize);
    }

    function royaltyInfo(uint256, uint256 _salePrice) public view returns (address, uint256) {
        uint256 mantissa = 10000;
        uint256 fee = 300;
        uint256 royaltyAmount = (_salePrice * fee) / mantissa;
        return (earthmeta, royaltyAmount);
    }

    function setOperator(address _operator, bool _status) external onlyOwner {
        operators[_operator] = _status;
    }

    function getTransferValidator() external view returns (address validator) {
        validator;
    }

    function getTransferValidationFunction() external view returns (bytes4 functionSignature, bool isViewFunction) {
        (0x7c1e14b4, true);
    }

    function setTransferValidator(address _validator) external onlyOwner {
        validator = _validator;
    }

    uint256[50] private __gap;
}