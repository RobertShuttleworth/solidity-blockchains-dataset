// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// external
import { Initializable } from "./lib_openzeppelin-contracts-upgradeable_contracts_proxy_utils_Initializable.sol";
import { UUPSUpgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_proxy_utils_UUPSUpgradeable.sol";
import { AccessControlEnumerableUpgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_access_extensions_AccessControlEnumerableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_utils_ReentrancyGuardUpgradeable.sol";

// internal
import { WithdrawableUpgradeable } from "./src_internal_WithdrawableUpgradeable.sol";

// constants
import { Roles } from "./src_constants_RoleConstants.sol";

contract BaseUpgradeable is
    Initializable,
    UUPSUpgradeable,
    AccessControlEnumerableUpgradeable,
    ReentrancyGuardUpgradeable,
    WithdrawableUpgradeable
{
    function __BaseUpgradeable_init(address admin_) internal initializer {
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        __AccessControlEnumerable_init();
        __BaseUpgradeable_init_unchained(admin_);
    }

    function __BaseUpgradeable_init_unchained(address admin_) internal initializer {
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
    }

    /*//////////////////////////////////////////////////////////////
                    ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getRoleMembers(bytes32 role) external view virtual returns (address[] memory) {
        uint256 length = getRoleMemberCount(role);
        address[] memory members = new address[](length);

        for (uint256 i = 0; i < length; i++) {
            members[i] = getRoleMember(role, i);
        }

        return members;
    }

    function grantRoles(bytes32 role, address[] calldata accounts) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 length = accounts.length;

        for (uint256 i = 0; i < length; i++) {
            _grantRole(role, accounts[i]);
        }
    }

    function revokeRoles(bytes32 role, address[] calldata accounts) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 length = accounts.length;

        for (uint256 i = 0; i < length; i++) {
            _revokeRole(role, accounts[i]);
        }
    }

    /**
     * @notice Authorizes an upgrade to a new implementation.
     * @param newImplementation Address of the new implementation.
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(Roles.UPGRADER_ROLE) { }

    uint256[50] private __gap;
}