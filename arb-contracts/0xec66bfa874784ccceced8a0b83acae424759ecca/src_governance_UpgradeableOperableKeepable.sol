// SPDX-License-Identifier: UNLICENSED

// Copyright (c) 2024 JonesDAO - All rights reserved
// Jones DAO: https://www.jonesdao.io/

// Check https://docs.jonesdao.io/jones-dao/other/bounty for details on our bounty program.

pragma solidity ^0.8.26;

import {UpgradeableGovernable} from "./src_governance_UpgradeableGovernable.sol";

abstract contract UpgradeableOperableKeepable is UpgradeableGovernable {
    bytes32 public constant OPERATOR = bytes32("OPERATOR");
    bytes32 public constant KEEPER = bytes32("KEEPER");

    modifier onlyOperator() {
        if (!hasRole(OPERATOR, msg.sender)) {
            revert CallerIsNotOperator();
        }

        _;
    }

    modifier onlyKeeper() {
        if (!hasRole(KEEPER, msg.sender)) {
            revert CallerIsNotKeeper();
        }

        _;
    }

    modifier onlyOperatorOrKeeper() {
        if (!hasRole(OPERATOR, msg.sender) && !hasRole(KEEPER, msg.sender)) {
            revert CallerIsNotAllowed();
        }

        _;
    }

    modifier onlyGovernorOrKeeper() {
        if (!hasRole(GOVERNOR, msg.sender) && hasRole(KEEPER, msg.sender)) {
            revert CallerIsNotAllowed();
        }

        _;
    }

    /**
     * @notice Only msg.sender with OPERATOR or GOVERNOR role can call the function.
     */
    modifier onlyGovernorOrOperator() {
        if (!hasRole(GOVERNOR, msg.sender) && hasRole(OPERATOR, msg.sender)) {
            revert CallerIsNotAllowed();
        }

        _;
    }

    function addOperator(address _newOperator) external onlyGovernor {
        _grantRole(OPERATOR, _newOperator);

        emit OperatorAdded(_newOperator);
    }

    function removeOperator(address _operator) external onlyGovernor {
        _revokeRole(OPERATOR, _operator);

        emit OperatorRemoved(_operator);
    }

    function addKeeper(address _newKeeper) external onlyGovernor {
        _grantRole(KEEPER, _newKeeper);

        emit KeeperAdded(_newKeeper);
    }

    function removeKeeper(address _keeper) external onlyGovernor {
        _revokeRole(KEEPER, _keeper);

        emit KeeperRemoved(_keeper);
    }

    event OperatorAdded(address _newOperator);
    event OperatorRemoved(address _operator);

    error CallerIsNotOperator();

    event KeeperAdded(address _newKeeper);
    event KeeperRemoved(address _operator);

    error CallerIsNotKeeper();

    error CallerIsNotAllowed();
}