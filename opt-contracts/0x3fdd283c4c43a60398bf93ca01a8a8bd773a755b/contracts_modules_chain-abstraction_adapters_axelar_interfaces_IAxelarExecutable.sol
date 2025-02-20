// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {IAxelarGateway} from "./contracts_modules_chain-abstraction_adapters_axelar_interfaces_IAxelarGateway.sol";

interface IAxelarExecutable {
    error InvalidAddress();
    error NotApprovedByGateway();

    function gateway() external view returns (IAxelarGateway);

    function execute(bytes32 commandId, string calldata sourceChain, string calldata sourceAddress, bytes calldata payload) external;
}