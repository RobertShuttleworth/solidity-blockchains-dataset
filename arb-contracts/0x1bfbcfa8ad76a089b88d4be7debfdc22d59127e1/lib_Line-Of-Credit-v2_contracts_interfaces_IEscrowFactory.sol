// SPDX-License-Identifier: GPL-3.0
// Copyright: https://github.com/credit-cooperative/Line-Of-Credit-v2/blob/master/COPYRIGHT.md

pragma solidity ^0.8.25;

import {ILineFactory} from "./lib_Line-Of-Credit-v2_contracts_interfaces_ILineFactory.sol";

interface IEscrowFactory {
    event DeployedEscrow(address indexed deployedAt, uint32 indexed minCRatio, address indexed owner);
    event SetLineFactory(address lineFactory);

    error CallerAccessDenied();
    error LineFactoryAlreadySet();

    function escrowTemplate() external view returns (address);
    function laaSEscrowTemplate() external view returns (address);
    function oracle() external view returns (address);
    function uniV3Oracle() external view returns (address);

    function deployEscrow(
        uint32 minCRatio,
        address owner,
        address borrower,
        address uniV3Manager,
        ILineFactory.SmartEscrowParams calldata smartEscrowParams
    ) external returns (address);

    event DeployedEscrow(
        address indexed deployedAt, uint32 indexed minCRatio, address oracle, address uniV3Oracle, address owner
    );
}