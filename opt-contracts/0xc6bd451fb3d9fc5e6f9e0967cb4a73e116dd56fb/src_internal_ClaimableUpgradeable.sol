// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { IClaimable } from "./src_interfaces_internal_IClaimable.sol";
import { BitMapsUpgradeable } from "./src_libraries_BitMapsUpgradeable.sol";
import { AlreadyClaimed, InvalidNonce } from "./src_errors_Errors.sol";

/**
 * @title ClaimableUpgradeable
 * @notice This contract provides functionality for marking addresses as having claimed a token distribution.
 * @dev Uses BitMaps to efficiently track claimed addresses.
 */
abstract contract ClaimableUpgradeable is IClaimable {
    using BitMapsUpgradeable for BitMapsUpgradeable.BitMap;

    /// @notice Bitmap to track claimed addresses.
    BitMapsUpgradeable.BitMap internal _hasClaimed;
    mapping(bytes32 userId => uint256 nonce) internal _nonces;

    function hasClaimed(bytes32 claimId_) public view override returns (bool) {
        return _hasClaimed.get(uint256(claimId_));
    }

    function getCurrentNonce(bytes32 userId_) external view returns (uint256) {
        return _nonces[userId_] + 1; // Reserve nonce 0 and label it as 'error'
    }

    function _setNonce(bytes32 userId_, uint256 nonce_) internal {
        if (nonce_ != ++_nonces[userId_]) revert InvalidNonce();
    }

    function _setClaimed(bytes32 claimId_) internal {
        if (hasClaimed(claimId_)) revert AlreadyClaimed();

        _hasClaimed.set(uint256(claimId_));
    }

    uint256[48] private __gap;
}