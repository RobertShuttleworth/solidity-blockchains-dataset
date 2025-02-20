// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AccessControlDefaultAdminRulesUpgradeable} from "./lib_openzeppelin-contracts-upgradeable_contracts_access_extensions_AccessControlDefaultAdminRulesUpgradeable.sol";
import {UUPSUpgradeable} from "./lib_openzeppelin-contracts-upgradeable_contracts_proxy_utils_UUPSUpgradeable.sol";
import {Errors} from "./src_library_Errors.sol";
import {Constants} from "./src_library_Constants.sol";
import "./src_interfaces_IPoolPartyPositionManagerView.sol";
import "./src_interfaces_IPoolPartyPositionManager.sol";
import "./src_interfaces_IPoolPartyPositionView.sol";

struct Storage {
    address i_poolPositionManager;
}

abstract contract PoolPartyPositionManagerViewStorage is
    IPoolPartyPositionManagerView,
    UUPSUpgradeable,
    AccessControlDefaultAdminRulesUpgradeable
{
    // slither-disable-next-line uninitialized-state,reentrancy-no-eth
    Storage internal s;

    // aderyn-ignore-next-line(state-variable-changes-without-events)
    function initialize(
        address _admin,
        address _upgrader,
        address _poolPositionManager
    ) public initializer {
        require(_admin != address(0), Errors.AddressIsZero());
        require(_upgrader != address(0), Errors.AddressIsZero());
        require(_poolPositionManager != address(0), Errors.AddressIsZero());

        __AccessControlDefaultAdminRules_init(3 days, _admin);

        s.i_poolPositionManager = _poolPositionManager;
        _grantRole(Constants.UPGRADER_ROLE, _upgrader);
    }
}