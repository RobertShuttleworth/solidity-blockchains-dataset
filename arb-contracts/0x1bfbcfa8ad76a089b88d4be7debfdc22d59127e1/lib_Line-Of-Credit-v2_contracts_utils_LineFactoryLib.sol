// SPDX-License-Identifier: GPL-3.0
// Copyright: https://github.com/credit-cooperative/Line-Of-Credit-v2/blob/master/COPYRIGHT.md

pragma solidity 0.8.25;

import {SecuredLine} from "./lib_Line-Of-Credit-v2_contracts_modules_credit_SecuredLine.sol";
import {ILineOfCredit} from "./lib_Line-Of-Credit-v2_contracts_interfaces_ILineOfCredit.sol";
import {ISpigot} from "./lib_Line-Of-Credit-v2_contracts_interfaces_ISpigot.sol";
import {IEscrow} from "./lib_Line-Of-Credit-v2_contracts_interfaces_IEscrow.sol";

import {Clones} from "./lib_openzeppelin-contracts_contracts_proxy_Clones.sol";

interface IUpdatableLine {
    function updateOwner(address line) external returns (bool);
}

/**
 * @title   - LineFactoryLib
 * @author  - Credit Cooperative
 * @notice  - Core logic used by LineFactory contract for deploying SecuredLine contracts.
 */
library LineFactoryLib {
    struct SecuredLineDeploymentParams {
        address template;
        address oracle;
        address admin;
        address borrower;
        address uniV3Manager;
        bool recoveryEnabled;
        address s;
        address e;
        address c;
        ILineOfCredit.Fees fees;
    }

    using Clones for address;

    error ModuleTransferFailed(address line, address spigot, address escrow);
    error InitNewLineFailed(address line, address spigot, address escrow);

    /**
     * @notice  - transfer ownership of Spigot + Escrow contracts from factory to line contract after all 3 have been deployed
     * @param line    - the line to transfer modules to
     * @param spigot  - the module to be transferred to line
     * @param escrow  - the module to be transferred to line
     */
    function transferModulesToLine(address line, address spigot, address escrow) external {
        (bool success, bytes memory returnVal) =
            spigot.call(abi.encodeWithSignature("updateOwner(address)", address(line)));

        bytes memory updateOwnerCall = abi.encodeWithSignature("updateOwner(address)", line);
        (success, returnVal) = escrow.call(updateOwnerCall);

        if (IEscrow(escrow).owner() != line || ISpigot(spigot).owner() != line) {
            revert ModuleTransferFailed(line, spigot, escrow);
        }

        SecuredLine(payable(line)).init();
    }

    /**
     * @notice  - See SecuredLine.constructor(). Deploys a new SecuredLine contract with params provided by factory.
     * @dev     - Deploy from lib not factory so we can have multiple factories (aka marketplaces) built on same Line contracts
     * @return line   - address of newly deployed line
     */
    function deploySecuredLine(SecuredLineDeploymentParams memory params) external returns (address) {
        address line = params.template.clone();
        SecuredLine(payable(line)).initializeFromFactory(
            params.admin, params.borrower, params.recoveryEnabled, params.s, params.e, params.c, params.fees
        );
        return line;
    }
}