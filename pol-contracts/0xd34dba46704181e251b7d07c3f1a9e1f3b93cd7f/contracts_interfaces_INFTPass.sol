// SPDX-License-Identifier: BSD 3-Clause

pragma solidity 0.8.9;

import "./openzeppelin_contracts-upgradeable_token_ERC721_IERC721Upgradeable.sol";

interface INFTPass is IERC721Upgradeable {
  function mint(address _owner, uint _quantity) external;
  function getOwnerNFTs(address _owner) external view returns(uint[] memory);
  function waitingList(address _user) external view returns (bool);
}