// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { IOwnable } from './axelar-network_axelar-gmp-sdk-solidity_contracts_interfaces_IOwnable.sol';
import { IImplementation } from './axelar-network_axelar-gmp-sdk-solidity_contracts_interfaces_IImplementation.sol';

// General interface for upgradable contracts
interface IUpgradable is IOwnable, IImplementation {
    error InvalidCodeHash();
    error InvalidImplementation();
    error SetupFailed();

    event Upgraded(address indexed newImplementation);

    function implementation() external view returns (address);

    function upgrade(
        address newImplementation,
        bytes32 newImplementationCodeHash,
        bytes calldata params
    ) external;
}