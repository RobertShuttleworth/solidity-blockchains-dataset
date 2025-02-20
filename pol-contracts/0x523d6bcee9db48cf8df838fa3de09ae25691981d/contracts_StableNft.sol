// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { ERC1155 } from "./openzeppelin_contracts_token_ERC1155_ERC1155.sol";
import { ERC1155Burnable } from "./openzeppelin_contracts_token_ERC1155_extensions_ERC1155Burnable.sol";
import { ERC1155Supply } from "./openzeppelin_contracts_token_ERC1155_extensions_ERC1155Supply.sol";
import { Strings } from "./openzeppelin_contracts_utils_Strings.sol";
import { Ownable, Ownable2Step } from "./openzeppelin_contracts_access_Ownable2Step.sol";

/// @title StableNft
/// @notice The contract implements ERC1155 nft

contract StableNft is ERC1155, ERC1155Supply, ERC1155Burnable, Ownable2Step {
    using Strings for uint256;
    /// @notice The address of market place contract
    address public immutable nftMarketPlace;

    /// @notice The name of the NFT collection
    string public name;

    /// @notice Thrown when updating an address with zero address
    error ZeroAddress();

    /// @notice Thrown when caller is not market place
    error CallerInvalid();

    /// @dev Constructor
    /// @param baseUri The uri for all token types
    /// @param marketPlace The address of marketplace contract
    /// @param creator The address of collection creator
    /// @param collectionName The address of collection creator
    constructor(
        string memory baseUri,
        address marketPlace,
        address creator,
        string memory collectionName
    ) ERC1155(baseUri) Ownable(creator) {
        if (address(marketPlace) == address(0)) {
            revert ZeroAddress();
        }

        nftMarketPlace = marketPlace;
        name = collectionName;
    }

    /// @notice The function is used to mint nfts
    /// @param to The recipient of the nft
    /// @param tokenId The token id to mint
    /// @param amount The number of tokens of the tokenId to mint
    /// @param data Optional additional data for extra information
    function mint(address to, uint256 tokenId, uint256 amount, bytes memory data) external {
        if (msg.sender != nftMarketPlace) {
            revert CallerInvalid();
        }
        _mint(to, tokenId, amount, data);
    }

    /// @notice The function returns the metadata uri of a specific nft id
    /// @param tokenId The nft id
    function uri(uint256 tokenId) public view override returns (string memory) {
        string memory baseURI = super.uri(tokenId);
        return bytes(baseURI).length > 0 ? string.concat(baseURI, tokenId.toString()) : "";
    }

    /// @notice Sets `baseURI` as the `_baseURI` for all tokens
    /// @param baseUri The base uri
    function setBaseURI(string memory baseUri) external onlyOwner {
        _setURI(baseUri);
    }

    ///@inheritdoc ERC1155
    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal virtual override(ERC1155, ERC1155Supply) {
        super._update(from, to, ids, values);
    }
}