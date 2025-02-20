// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

library LibTypeCast {
    bytes32 private constant ADDRESS_GUARD_MASK = 0x0000000000000000000000000000000000000000ffffffffffffffffffffffff;

    function toAddress(bytes32 v) internal pure returns (address) {
        require(v & ADDRESS_GUARD_MASK == 0, "LibTypeCast::INVALID_ADDRESS");
        return address(bytes20(v));
    }

    function toBytes32(address v) internal pure returns (bytes32) {
        return bytes32(bytes20(v));
    }

    function toUint256(bytes32 v) internal pure returns (uint256) {
        return uint256(v);
    }

    function toUint256(int256 v) internal pure returns (uint256) {
        require(v >= 0, "LibTypeCast::UNDERFLOW");
        return uint256(v);
    }

    function toBytes32(int256 v) internal pure returns (bytes32) {
        return bytes32(uint256(v));
    }

    function toInt256(bytes32 v) internal pure returns (int256) {
        return int256(uint256(v));
    }

    function toBytes32(uint256 v) internal pure returns (bytes32) {
        return bytes32(v);
    }

    function toBoolean(bytes32 v) internal pure returns (bool) {
        uint256 n = toUint256(v);
        require(n == 0 || n == 1, "LibTypeCast::INVALID_BOOLEAN");
        return n == 1;
    }

    function toBytes32(bool v) internal pure returns (bytes32) {
        return toBytes32(v ? 1 : 0);
    }

    function toInt256(uint256 n) internal pure returns (int256) {
        require(n <= uint256(type(int256).max), "LibTypeCast::OVERFLOW");
        return int256(n);
    }

    function toUint96(uint256 n) internal pure returns (uint96) {
        require(n <= uint256(type(uint96).max), "LibTypeCast::OVERFLOW");
        return uint96(n);
    }

    function toUint64(uint256 n) internal pure returns (uint64) {
        require(n <= uint256(type(uint64).max), "LibTypeCast::OVERFLOW");
        return uint64(n);
    }

    function negInt256(int256 n) internal pure returns (uint256) {
        if (n >= 0) {
            return uint256(n);
        }
        require(n != type(int256).min, "LibTypeCast::UNDERFLOW");
        return uint256(-n);
    }
}