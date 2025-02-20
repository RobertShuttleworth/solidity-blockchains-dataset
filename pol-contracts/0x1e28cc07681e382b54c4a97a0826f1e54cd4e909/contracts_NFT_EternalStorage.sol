// UNLICENSED : Solidity follows the npm recommendation.
pragma solidity ^0.8.9;

import "./openzeppelin_contracts_token_ERC721_ERC721.sol";
import "./openzeppelin_contracts_token_ERC721_extensions_ERC721Enumerable.sol";
import "./openzeppelin_contracts_token_ERC721_extensions_ERC721URIStorage.sol";
import "./openzeppelin_contracts_security_Pausable.sol";
import "./openzeppelin_contracts_access_Ownable.sol";
import "./openzeppelin_contracts_token_ERC721_extensions_ERC721Burnable.sol";
import "./openzeppelin_contracts_utils_Counters.sol";
import "./openzeppelin_contracts_token_common_ERC2981.sol";
import "./openzeppelin_contracts_metatx_ERC2771Context.sol";

abstract contract EternalStorage is
  ERC2771Context,
  ERC721,
  ERC721Enumerable,
  ERC721URIStorage,
  ERC2981,
  Pausable,
  Ownable
{
  constructor(
    string memory _name,
    string memory _symbol,
    address _forwarder
  ) ERC2771Context(_forwarder) ERC721(_name, _symbol) {}

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 tokenId
  ) internal override(ERC721, ERC721Enumerable) whenNotPaused {
    super._beforeTokenTransfer(from, to, tokenId);
  }

  // The following functions are overrides required by Solidity.

  function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
    super._burn(tokenId);
  }

  /**
   * @notice Get Token URI
   * @param tokenId NFT TokenID for getting tokenURI
   * @return string return metadata of NFT token by tokenId
   */
  function tokenURI(uint256 tokenId)
    public
    view
    override(ERC721, ERC721URIStorage)
    returns (string memory)
  {
    return super.tokenURI(tokenId);
  }

  function supportsInterface(bytes4 interfaceId)
    public
    view
    override(ERC721, ERC721Enumerable, ERC2981)
    returns (bool)
  {
    return super.supportsInterface(interfaceId);
  }

  function _msgData() internal view override(ERC2771Context, Context) returns (bytes calldata) {
    return ERC2771Context._msgData();
  }

  function _msgSender() internal view override(ERC2771Context, Context) returns (address sender) {
    return ERC2771Context._msgSender();
  }
}