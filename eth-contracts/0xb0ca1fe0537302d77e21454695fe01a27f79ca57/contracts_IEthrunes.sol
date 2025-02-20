// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import "./openzeppelin_contracts_token_ERC1155_IERC1155.sol";

interface IEthrunes is IERC1155 {

	function transfer(
		address to,
		uint256 id,
		uint256 amount,
		bytes memory data
	) external payable;

  function batchTransfer(
    address to,
    uint256[] memory ids,
    uint256[] memory amounts,
    bytes memory data
  ) external payable;

  function deploy(
		string calldata tick,
		uint8 decimals,
		uint256 supply,
		uint256 limit
	) external;

  function deploy2(
		string calldata tick,
		uint8 decimals,
		uint256 supply,
		address to
	) external payable;

  function tokens(uint160 _id) external view returns(
  	uint160 id,
		uint8 decimals,
		uint256 supply,
		uint256 limit,
		string memory tick
	);

	function totalSupply(uint256 id) external view returns (uint256);
}