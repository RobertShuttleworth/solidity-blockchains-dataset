// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import { IEOARegistry } from "./contracts_mock_interfaces_IEOARegistry.sol";
import { ITransferSecurityRegistry } from "./contracts_mock_interfaces_ITransferSecurityRegistry.sol";
import { ITransferValidator } from "./contracts_mock_interfaces_ITransferValidator.sol";

interface ICreatorTokenTransferValidator is
	ITransferSecurityRegistry,
	ITransferValidator,
	IEOARegistry
{}