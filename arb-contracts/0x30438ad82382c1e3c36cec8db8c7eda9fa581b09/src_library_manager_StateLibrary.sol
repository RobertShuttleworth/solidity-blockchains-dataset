// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "./src_interfaces_IPoolPartyPositionManager.sol";

// aderyn-ignore-next-line(reused-contract-name)
library StateLibrary {
    bytes32 public constant SLOT = bytes32(uint256(0));

    function getPositionByInvestorAndId(
        IPoolPartyPositionManager _pppm,
        PositionId _positionId,
        address _investor
    ) internal view returns (address position) {
        bytes32 slot = bytes32(uint256(SLOT) + 15);
        bytes32 key1Hash = keccak256(abi.encode(_investor, slot));
        bytes32 key2Hash = keccak256(abi.encode(_positionId, key1Hash));

        bytes32 positionByInvestorAndIdSlot = _pppm.extsload(key2Hash);

        assembly ("memory-safe") {
            position := and(
                positionByInvestorAndIdSlot,
                0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
            )
        }
    }

    function getPositionsByInvestor(
        IPoolPartyPositionManager _pppm,
        address _investor
    ) internal view returns (address[] memory _positions) {
        uint256 slot = uint256(SLOT) + 14;
        bytes32 keyHash = keccak256(abi.encode(_investor, slot));
        bytes32 mapSlot = _pppm.extsload(keyHash);

        uint256 len = 0;
        assembly ("memory-safe") {
            len := mapSlot
            // Store length of array
            mstore(_positions, len)
        }

        uint256 h = uint256(keccak256(abi.encode(keyHash)));
        for (uint256 i = 0; i <= len; i++) {
            bytes32 positionsByInvestorSlot = _pppm.extsload(bytes32(h + i));
            assembly ("memory-safe") {
                mstore(
                    add(_positions, mul(add(i, 1), 0x20)),
                    and(
                        positionsByInvestorSlot,
                        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
                    )
                )
            }
        }

        assembly ("memory-safe") {
            // Update free memory pointer
            mstore(0x40, add(_positions, mul(add(len, 1), 0x20)))
        }
    }

    function getOperatorByPositionId(
        IPoolPartyPositionManager _pppm,
        PositionId _positionId
    ) internal view returns (address operator) {
        uint256 slot = uint256(SLOT) + 13;
        bytes32 keyHash = keccak256(abi.encode(_positionId, slot));
        bytes32 operatorByPositionIdSlot = _pppm.extsload(keyHash);
        assembly ("memory-safe") {
            operator := and(
                operatorByPositionIdSlot,
                0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
            )
        }
    }

    function getTotalInvestorsByPosition(
        IPoolPartyPositionManager _pppm,
        PositionId _positionId
    ) internal view returns (uint256 investors) {
        uint256 slot = uint256(SLOT) + 18;
        bytes32 keyHash = keccak256(abi.encode(_positionId, slot));
        bytes32 totalInvestorsByPositionSlot = _pppm.extsload(keyHash);
        assembly ("memory-safe") {
            investors := totalInvestorsByPositionSlot
        }
    }

    function getPositions(
        IPoolPartyPositionManager _pppm
    ) internal view returns (address[] memory _positions) {
        bytes32 slot = bytes32(uint256(SLOT) + 21);
        bytes32 arrSlot = _pppm.extsload(slot);
        uint256 len = 0;
        assembly ("memory-safe") {
            len := arrSlot
            // Store length of arr
            mstore(_positions, len)
        }

        for (uint256 i = 0; i <= len; i++) {
            bytes32 arrHash = bytes32(uint256(keccak256(abi.encode(slot))) + i);
            bytes32 positionSlot = _pppm.extsload(arrHash);
            assembly ("memory-safe") {
                mstore(
                    add(_positions, mul(add(i, 1), 0x20)),
                    and(
                        positionSlot,
                        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
                    )
                )
            }
        }

        assembly ("memory-safe") {
            // Update free memory pointer
            mstore(0x40, add(_positions, mul(add(len, 1), 0x20)))
        }
    }

    function getFeatureSettings(
        IPoolPartyPositionManager _pppm,
        PositionId _positionId
    )
        internal
        view
        returns (
            IPoolPartyPositionManagerStructs.FeatureSettings
                memory featureSettings
        )
    {
        bytes32 slot;
        bytes32 slot_1;
        bytes32 slot_2;
        bytes32 slot_3;
        {
            bytes32 featureSettingsStorage = keccak256(
                abi.encode(_positionId, (uint256(SLOT) + 16))
            );

            bytes32 featureSettingsStorage1 = bytes32(
                uint256(featureSettingsStorage) + 1
            );
            bytes32 featureSettingsStorage2 = bytes32(
                uint256(featureSettingsStorage) + 2
            );
            bytes32 featureSettingsStorage3 = bytes32(
                uint256(featureSettingsStorage) + 3
            );

            slot = _pppm.extsload(featureSettingsStorage);
            slot_1 = _pppm.extsload(featureSettingsStorage1);
            slot_2 = _pppm.extsload(featureSettingsStorage2);
            slot_3 = _pppm.extsload(featureSettingsStorage3);
        }
        {
            bytes32 name;
            bytes32 description;
            assembly ("memory-safe") {
                name := slot
                description := slot_1
                mstore(add(featureSettings, 0x40), and(slot_2, 0xFFFFFF)) // operatorFee

                mstore(add(featureSettings, 0x80), and(shr(0x00, slot_3), 0xFF)) // hiddenFields.showPriceRange

                mstore(add(featureSettings, 0xa0), and(shr(0x08, slot_3), 0xFF)) // hiddenFields.showTokenPair

                mstore(add(featureSettings, 0xc0), and(shr(0x10, slot_3), 0xFF)) // hiddenFields.showInOutRange
            }
            featureSettings.name = string(abi.encode(name));
            featureSettings.description = string(abi.encode(description));
        }
    }

    function isDestroyed(
        IPoolPartyPositionManager _pppm
    ) internal view returns (bool destroyed) {
        bytes32 slot = _pppm.extsload(bytes32(uint256(SLOT) + 23));
        assembly ("memory-safe") {
            destroyed := and(shr(0x10, slot), 0xFF)
        }
    }
}