// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import { ICreatorTokenTransferValidator } from "./contracts_ERC721C_interfaces_ICreatorTokenTransferValidator.sol";
import "./contracts_ERC721C_utils_TransferPolicy.sol";

interface ICreatorToken {
	event TransferValidatorUpdated(address oldValidator, address newValidator);

	function getTransferValidator()
		external
		view
		returns (ICreatorTokenTransferValidator);
	function getSecurityPolicy()
		external
		view
		returns (CollectionSecurityPolicy memory);
	function getWhitelistedOperators() external view returns (address[] memory);
	function getPermittedContractReceivers()
		external
		view
		returns (address[] memory);
	function isOperatorWhitelisted(
		address operator
	) external view returns (bool);
	function isContractReceiverPermitted(
		address receiver
	) external view returns (bool);
	function isTransferAllowed(
		address caller,
		address from,
		address to
	) external view returns (bool);
}