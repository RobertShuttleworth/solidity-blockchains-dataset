// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "./openzeppelin_contracts_access_AccessControl.sol";
import "./openzeppelin_contracts_utils_structs_EnumerableSet.sol";

// Uncomment this line to use console.log
// import "hardhat/console.sol";

contract WINUsersWhitelist is AccessControl {
    bytes32 public constant OWNER_ADMIN = keccak256("OWNER_ADMIN");

    using EnumerableSet for EnumerableSet.AddressSet;
    EnumerableSet.AddressSet private WHITELIST;

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function editWhitelist(address[] calldata _users, bool _add) external {
        require(
            hasRole(OWNER_ADMIN, msg.sender),
            "WINUsersWhitelist: Restricted to OWNER_ADMIN role"
        );
        require(
            _users.length <= 100,
            "WINUsersWhitelist: batch size must be equal or less than 100 users"
        );

        if (_add) {
            for (uint i = 0; i < _users.length; i++) {
                require(
                    _users[i] != address(0),
                    "_user can't be the zero address"
                );

                WHITELIST.add(_users[i]);
            }
        } else {
            for (uint i = 0; i < _users.length; i++) {
                WHITELIST.remove(_users[i]);
            }
        }
    }

    function getWhitelistStatus(address _user) external view returns (bool) {
        require(_user != address(0), "_user can't be the zero address");

        return WHITELIST.contains(_user);
    }
}