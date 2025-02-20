// SPDX-License-Identifier: BUSL-1.1

//     __                         _____
//    / /   ____ ___  _____  ____|__  /
//   / /   / __ `/ / / / _ \/ ___//_ <
//  / /___/ /_/ / /_/ /  __/ /  ___/ /
// /_____/\__,_/\__, /\___/_/  /____/
//             /____/

pragma solidity ^0.8.0;

import "./layerzerolabs_solidity-examples_contracts_token_onft_ONFT1155.sol";
import "./openzeppelin_contracts_token_ERC1155_ERC1155.sol";
import "./openzeppelin_contracts_access_AccessControl.sol";
import "./openzeppelin_contracts_token_ERC1155_extensions_ERC1155Burnable.sol";

contract L3ONFT1155 is ONFT1155, AccessControl {
  // name and contractURI makes the collection look nice on NFT marketplaces
  string public name;
  string public contractURI;

  // tokenURIs and nextTokenIdToMint are used to keep track of
  // all nfts in this collection
  mapping(uint256 => string) private tokenURIs;
  uint256 public nextTokenIdToMint;

  bytes32 public constant CREATOR_ROLE = keccak256("CREATOR_ROLE");
  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

  constructor(string memory _name, address _layerZeroEndpoint)
    ONFT1155("", _layerZeroEndpoint)
  {
    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _grantRole(CREATOR_ROLE, msg.sender);
    _grantRole(MINTER_ROLE, msg.sender);

    name = _name;
  }

  function setContractURI(string calldata _uri)
    external
    onlyRole(DEFAULT_ADMIN_ROLE)
  {
    contractURI = _uri;
  }

  function setTokenURI(uint256 _tokenId, string memory newuri)
    public
    onlyRole(CREATOR_ROLE)
  {
    tokenURIs[_tokenId] = newuri;
    emit URI(newuri, _tokenId);
  }

  function uri(uint256 _tokenId)
    public
    view
    override
    returns (string memory _tokenURI)
  {
    return tokenURIs[_tokenId];
  }

  function createNew(string memory _tokenURI)
    public
    onlyRole(CREATOR_ROLE)
    returns (uint256)
  {
    uint256 tokenId = nextTokenIdToMint;
    nextTokenIdToMint += 1;
    tokenURIs[tokenId] = _tokenURI;
    return tokenId;
  }

  function mintTo(
    address account,
    uint256 id,
    uint256 amount
  ) public onlyRole(MINTER_ROLE) {
    _mint(account, id, amount, "");
  }

  function supportsInterface(bytes4 interfaceId)
    public
    view
    override(ONFT1155, AccessControl)
    returns (bool)
  {
    return super.supportsInterface(interfaceId);
  }
}