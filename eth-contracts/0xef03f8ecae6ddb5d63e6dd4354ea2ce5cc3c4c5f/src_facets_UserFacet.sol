// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Modifiers } from "./src_shared_Modifiers.sol";
import { LibConstants as LC } from "./src_libs_LibConstants.sol";
import { LibAdmin } from "./src_libs_LibAdmin.sol";
import { LibHelpers } from "./src_libs_LibHelpers.sol";
import { LibObject } from "./src_libs_LibObject.sol";
import { LibEntity } from "./src_libs_LibEntity.sol";
import { EntityDoesNotExist } from "./src_shared_CustomErrors.sol";

/**
 * @title Users
 * @notice Utility functions for managing a user's entity.
 * @dev This contract includes functions to set and get user-entity relationships,
 *      and to convert wallet addresses to platform IDs and vice versa.
 */
contract UserFacet is Modifiers {
    /**
     * @notice Get the platform ID of `addr` account
     * @dev Convert address to platform ID
     * @param addr Account address
     * @return userId Unique platform ID
     */
    function getUserIdFromAddress(address addr) external pure returns (bytes32 userId) {
        return LibHelpers._getIdForAddress(addr);
    }

    /**
     * @notice Get the token address from ID of the external token
     * @dev Convert the bytes32 external token ID to its respective ERC20 contract address
     * @param _externalTokenId The ID assigned to an external token
     * @return tokenAddress Contract address
     */
    function getAddressFromExternalTokenId(bytes32 _externalTokenId) external pure returns (address tokenAddress) {
        tokenAddress = LibHelpers._getAddressFromId(_externalTokenId);
    }

    /**
     * @notice Set the entity for the user
     * @dev Assign the user an entity. The entity must exist in order to associate it with a user.
     * @param _userId Unique platform ID of the user account
     * @param _entityId Unique platform ID of the entity
     */
    function setEntity(bytes32 _userId, bytes32 _entityId) external assertPrivilege(LibAdmin._getSystemId(), LC.GROUP_SYSTEM_MANAGERS) {
        if (!LibEntity._isEntity(_entityId)) {
            revert EntityDoesNotExist(_entityId);
        }
        LibObject._setParent(_userId, _entityId);
    }

    /**
     * @notice Get the entity for the user
     * @dev Gets the entity related to the user
     * @param _userId Unique platform ID of the user account
     * @return entityId Unique platform ID of the entity
     */
    function getEntity(bytes32 _userId) external view returns (bytes32 entityId) {
        entityId = LibObject._getParent(_userId);
    }
}