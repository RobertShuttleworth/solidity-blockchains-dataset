// SPDX-License-Identifier: UNLICENSED

// Copyright (c) 2024 JonesDAO - All rights reserved
// Jones DAO: https://www.jonesdao.io/

// Check https://docs.jonesdao.io/jones-dao/other/bounty for details on our bounty program.

pragma solidity ^0.8.26;

import {UpgradeableGovernable} from "./src_governance_UpgradeableGovernable.sol";

abstract contract UpgradeableKeepable is UpgradeableGovernable {
    /**
     * @notice Keeper role
     */
    bytes32 public constant KEEPER = bytes32("KEEPER");

    /**
     * @notice Modifier if msg.sender has not KEEPER role revert.
     */
    modifier onlyKeeper() {
        if (!hasRole(KEEPER, msg.sender)) {
            revert CallerIsNotKeeper();
        }

        _;
    }

    /**
     * @notice Only msg.sender with KEEPER or GOVERNOR role can call the function.
     */
    modifier onlyGovernorOrKeeper() {
        if (!hasRole(GOVERNOR, msg.sender) && hasRole(KEEPER, msg.sender)) {
            revert CallerIsNotAllowed();
        }

        _;
    }

    /**
     * @notice Grant KEEPER role to _newKeeper.
     */
    function addKeeper(address _newKeeper) external onlyGovernor {
        _grantRole(KEEPER, _newKeeper);

        emit KeeperAdded(_newKeeper);
    }

    /**
     * @notice Remove Keeper role from _keeper.
     */
    function removeKeeper(address _keeper) external onlyGovernor {
        _revokeRole(KEEPER, _keeper);

        emit KeeperRemoved(_keeper);
    }

    event KeeperAdded(address _newKeeper);
    event KeeperRemoved(address _operator);

    error CallerIsNotKeeper();
    error CallerIsNotAllowed();
}