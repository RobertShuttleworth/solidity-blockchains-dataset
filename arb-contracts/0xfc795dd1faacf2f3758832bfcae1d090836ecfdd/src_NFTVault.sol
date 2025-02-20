// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./lib_openzeppelin-contracts_contracts_token_ERC721_IERC721.sol";
import "./lib_openzeppelin-contracts_contracts_token_ERC721_IERC721Receiver.sol";
import "./lib_openzeppelin-contracts_contracts_token_ERC1155_IERC1155.sol";
import "./lib_openzeppelin-contracts_contracts_interfaces_IERC1155Receiver.sol";
import "./lib_openzeppelin-contracts_contracts_access_AccessControl.sol";
import "./lib_openzeppelin-contracts_contracts_interfaces_IERC165.sol";

contract NFTVault is AccessControl, IERC721Receiver, IERC1155Receiver {
  bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

  event ERC721Received(address indexed operator, address indexed from, uint256 indexed tokenId, bytes data);
  event ERC1155Received(address indexed operator, address indexed from, uint256 indexed id, uint256 value, bytes data);
  event ERC1155BatchReceived(
    address indexed operator, address indexed from, uint256[] ids, uint256[] values, bytes data
  );

  constructor() {
    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _grantRole(MANAGER_ROLE, msg.sender);
  }

  function sendERC721(IERC721 token, address to, uint256 tokenId) external onlyRole(MANAGER_ROLE) {
    token.safeTransferFrom(address(this), to, tokenId);
  }

  function sendERC1155(IERC1155 token, address to, uint256 id, uint256 amount, bytes memory data)
    external
    onlyRole(MANAGER_ROLE)
  {
    token.safeTransferFrom(address(this), to, id, amount, data);
  }

  function batchSendERC1155(
    IERC1155 token,
    address to,
    uint256[] memory ids,
    uint256[] memory amounts,
    bytes memory data
  ) external onlyRole(MANAGER_ROLE) {
    token.safeBatchTransferFrom(address(this), to, ids, amounts, data);
  }

  function onERC721Received(address operator, address from, uint256 tokenId, bytes memory data)
    public
    virtual
    override
    returns (bytes4)
  {
    emit ERC721Received(operator, from, tokenId, data);
    return this.onERC721Received.selector;
  }

  function onERC1155Received(address operator, address from, uint256 id, uint256 value, bytes memory data)
    public
    virtual
    override
    returns (bytes4)
  {
    emit ERC1155Received(operator, from, id, value, data);
    return this.onERC1155Received.selector;
  }

  function onERC1155BatchReceived(
    address operator,
    address from,
    uint256[] memory ids,
    uint256[] memory values,
    bytes memory data
  ) public virtual override returns (bytes4) {
    emit ERC1155BatchReceived(operator, from, ids, values, data);
    return this.onERC1155BatchReceived.selector;
  }

  function supportsInterface(bytes4 interfaceId) public view virtual override(AccessControl, IERC165) returns (bool) {
    return interfaceId == type(IERC721Receiver).interfaceId || interfaceId == type(IERC1155Receiver).interfaceId
      || super.supportsInterface(interfaceId);
  }

  function grantManagerRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
    grantRole(MANAGER_ROLE, account);
  }

  function revokeManagerRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
    revokeRole(MANAGER_ROLE, account);
  }
}