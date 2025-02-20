// SPDX-License-Identifier: FRAKTAL-PROTOCOL
pragma solidity 0.8.24;

/******************************************************************************\
* Author: Kryptokajun <kryptokajun@proton.me> (https://twitter.com/kryptokajun1)
*
* Implementation of a diamond.
/******************************************************************************/

import {LibDiamond, DiamondStorage} from "./contracts_shared_libraries_LibDiamond.sol";
import {IDiamondLoupe} from "./contracts_shared_interfaces_IDiamondLoupe.sol";
import {IDiamondCut} from "./contracts_shared_interfaces_IDiamondCut.sol";
import {IERC173} from "./contracts_shared_interfaces_IERC173.sol";
import {IERC165} from "./contracts_shared_interfaces_IERC165.sol";
import {IERC20Meta} from "./contracts_shared_interfaces_IERC20.sol";
import {IWETH} from "./contracts_shared_interfaces_IWETH.sol";
import {AppStore} from "./contracts_FraktalDeFiDAODiamond_AppStore.sol";

import {LibOZAccessControl} from "./contracts_shared_libraries_LibOZAccessControl.sol";
import {LibMeta} from "./contracts_shared_libraries_LibMeta.sol";
import {LibInitializer} from "./contracts_shared_libraries_LibInitializer.sol";

// It is expected that this contract is customized if you want to deploy your diamond
// with data from a deployment script. Use the init function to initialize state variables
// of your diamond. Add parameters to the init funciton if you need to.

contract FraktaDeFilDAODiamondInit {
    AppStore internal s;

    // You can add parameters to this function in order to pass in
    // data to set your own state variables
    function init(address _weth) external {
        // adding ERC165 data
        DiamondStorage storage ds = LibDiamond.diamondStorage();

        ds.supportedInterfaces[type(IERC165).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondCut).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
        ds.supportedInterfaces[type(IERC173).interfaceId] = true;
        // ds.supportedInterfaces[type(IERC20Meta).interfaceId] = true;  // UNCOMMENT TO ADD IERC20 SUPPORT

        // add your own state variables
        s.WETH = IWETH(_weth);
        // Initialize the RoleManager contract with the specified admin role
        bytes32 DEFAULT_ADMIN_ROLE = bytes32(0x00);
        bytes32 ROOT_ROLE = keccak256("ROOT_ROLE");
        bytes32 USER_ROLE = keccak256("USER_ROLE");
        bytes32 BOT_MANAGER_ROLE = keccak256("BOT_MANAGER_ROLE");
        bytes32 BOT_RUNNER_ROLE = keccak256("BOT_RUNNER_ROLE");

        LibOZAccessControl.setRoleAdmin(ROOT_ROLE, DEFAULT_ADMIN_ROLE);
        LibOZAccessControl.setRoleAdmin(USER_ROLE, ROOT_ROLE);
        LibOZAccessControl.setRoleAdmin(BOT_MANAGER_ROLE, ROOT_ROLE);
        LibOZAccessControl.setRoleAdmin(BOT_RUNNER_ROLE, ROOT_ROLE);

        LibOZAccessControl.grantRole(
            DEFAULT_ADMIN_ROLE,
            LibDiamond.contractOwner()
        );
        LibInitializer.initialize(LibDiamond.id());
        // EIP-2535 specifies that the `diamondCut` function takes two optional
        // arguments: address _init and bytes calldata _calldata
        // These arguments are used to execute an arbitrary function using delegatecall
        // in order to set state variables in the diamond during deployment or an upgrade
        // More info here: https://eips.ethereum.org/EIPS/eip-2535#diamond-interface
    }
}