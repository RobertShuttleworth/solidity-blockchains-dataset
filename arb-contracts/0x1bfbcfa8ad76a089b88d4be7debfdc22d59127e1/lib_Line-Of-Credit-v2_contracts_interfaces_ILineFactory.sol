// SPDX-License-Identifier: GPL-3.0
// Copyright: https://github.com/credit-cooperative/Line-Of-Credit-v2/blob/master/COPYRIGHT.md

pragma solidity ^0.8.25;

import {ILineOfCredit} from "./lib_Line-Of-Credit-v2_contracts_interfaces_ILineOfCredit.sol";

interface ILineFactory {
    enum EscrowTypes {
        ESCROW,
        LAAS
    }

    struct SmartEscrowParams {
        EscrowTypes escrowType;
        address pool;
    }

    struct CoreLineParams {
        address borrower;
        address operator;
        address uniV3Manager;
        bool recoveryEnabled;
        uint32 minCratio;
        SmartEscrowParams smartEscrowParams;
        ILineOfCredit.Fees fees;
    }

    event DeployedSecuredLine(
        address indexed deployedAt,
        address indexed escrow,
        address indexed spigot,
        address creditPositionToken,
        address swapTarget
    );

    event UpdateAdmin(address indexed newAdmin);
    event UpdateServicer(address indexed newServicer);
    event UpdateSwapTarget(address indexed newSwapTarget);
    event UpdateProtocolTreasury(address indexed newTreasury);
    event FactoryOperatorSet(address indexed sender, address indexed operator, bool indexed approved);

    error CallerAccessDenied();
    error ModuleTransferFailed(address line, address spigot, address escrow);
    error CannotBeZeroAddress();

    function admin() external view returns (address);
    function protocolTreasury() external view returns (address);
    function creditPositionToken() external view returns (address);
    function oracle() external view returns (address);
    function securedLineTemplate() external view returns (address);

    function deployEscrow(
        uint32 minCRatio,
        address owner,
        address borrower,
        address uniV3Manager,
        SmartEscrowParams memory smartEscrowParams
    ) external returns (address);
    function deploySpigot(address operator) external returns (address);
    function deploySecuredLineWithConfig(CoreLineParams calldata coreParams) external returns (address);

    function updateAdmin(address newAdmin) external returns (bool);
    function updateProtocolTreasury(address newTreasury) external returns (bool);
    function setFactoryOperator(address operator, bool approved) external returns (bool);

    function getEscrowFactory() external view returns (address);
    function getSpigotFactory() external view returns (address);

    function isLine(address) external view returns (bool);
    function swapTarget() external view returns (address payable);
}