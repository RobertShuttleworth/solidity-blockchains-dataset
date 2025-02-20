// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { IContractIdentifier } from './axelar-network_axelar-gmp-sdk-solidity_contracts_interfaces_IContractIdentifier.sol';

interface IImplementation is IContractIdentifier {
    error NotProxy();

    function setup(bytes calldata data) external;
}