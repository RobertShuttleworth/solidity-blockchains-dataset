// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import "./contracts_ERC721C_utils_TransferPolicy.sol";

interface ITransferValidator {
	function applyCollectionTransferPolicy(
		address caller,
		address from,
		address to
	) external view;
}