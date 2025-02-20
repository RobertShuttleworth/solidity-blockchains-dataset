// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./openzeppelin_contracts_token_ERC721_ERC721.sol";
import "./openzeppelin_contracts_token_ERC721_extensions_ERC721Enumerable.sol";
import "./openzeppelin_contracts_token_ERC721_extensions_ERC721URIStorage.sol";
import "./openzeppelin_contracts_token_ERC721_extensions_ERC721Pausable.sol";
import "./openzeppelin_contracts_access_Ownable.sol";
import "./openzeppelin_contracts_token_ERC721_extensions_ERC721Burnable.sol";

contract Kefirium is ERC721, ERC721Enumerable, ERC721URIStorage, ERC721Pausable, Ownable, ERC721Burnable {
  uint256 private _nextTokenId;
  address private _creator;
  string public baseURI;

  constructor(address initialOwner, string memory cname, string memory csymbol, string memory baseTokenURI)
  ERC721(cname, csymbol)
  Ownable(initialOwner)
  {
    _creator = msg.sender;
    _nextTokenId = 1;
    baseURI = baseTokenURI;
  }

  function pause() public onlyOwner {
    _pause();
  }

  function unpause() public onlyOwner {
    _unpause();
  }

  function mint(address to, string memory uri)
  public onlyOwner
  returns (uint256)
  {
    return _mint(to, uri);
  }

  function creatorMint(address to, string memory uri)
  public onlyCreator
  returns (uint256)
  {
    return _mint(to, uri);
  }

  function _mint(address to, string memory uri)
  private
  returns (uint256)
  {
    uint256 tokenId = _nextTokenId++;
    _safeMint(to, tokenId);
    _setTokenURI(tokenId, uri);
    return tokenId;
  }

  function updateContractURI(string calldata newBaseURI) external onlyOwner
  {
    baseURI = newBaseURI;
  }

  function updateTokenURI(uint256 tokenId, string calldata newTokenURI) external onlyOwner
  {
    _setTokenURI(tokenId, newTokenURI);
  }

  /// @notice Provides OpenSea contract metadata
  /// @return A string representing a JSON metadata for OpenSea
  function contractURI() public view returns (string memory)
  {
    return baseURI;
  }

  modifier onlyCreator {
    require(msg.sender == _creator, "Only for contract creator");
    _;
  }

  // The following functions are overrides required by Solidity.

  function _update(address to, uint256 tokenId, address auth)
  internal
  override(ERC721, ERC721Enumerable, ERC721Pausable)
  returns (address)
  {
    return super._update(to, tokenId, auth);
  }

  function _increaseBalance(address account, uint128 value)
  internal
  override(ERC721, ERC721Enumerable)
  {
    super._increaseBalance(account, value);
  }

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
  override(ERC721, ERC721Enumerable, ERC721URIStorage)
  returns (bool)
  {
    return super.supportsInterface(interfaceId);
  }
}