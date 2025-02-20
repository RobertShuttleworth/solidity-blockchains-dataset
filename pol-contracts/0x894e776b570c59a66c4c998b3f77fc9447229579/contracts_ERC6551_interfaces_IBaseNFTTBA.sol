// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import { IERC6551Registry } from "./contracts_ERC6551_interfaces_IERC6551Registry.sol";

interface IBaseNFTTBA is IERC6551Registry {
	// =============================================================
	//                         EXTERNAL WRITE
	// =============================================================

	function createAccount(
		address implementation,
		bytes32 salt,
		uint256 chainId,
		address tokenContract,
		uint256 tokenId
	) external returns (address account);

	// =============================================================
	//                         EXTERNAL VIEW
	// =============================================================

	/// @notice Checks if an account is registered
	/// @param contractAddress The contract address
	/// @param accountAddress The account address
	/// @return True if the account is registered, false otherwise
	function checkAccount(
		address contractAddress,
		address accountAddress
	) external view returns (bool);

	/// @notice Gets the account from the token ID
	/// @param contractAddress The contract address
	/// @param tokenId The token ID
	/// @return The account address
	function getAccountFromTokenId(
		address contractAddress,
		uint256 tokenId
	) external view returns (address);

	/// @notice Gets the token ID from the account
	/// @param contractAddress The contract address
	/// @param accountAddress The account address
	/// @return The token ID
	function getTokenIdFromAccount(
		address contractAddress,
		address accountAddress
	) external view returns (uint256);
}