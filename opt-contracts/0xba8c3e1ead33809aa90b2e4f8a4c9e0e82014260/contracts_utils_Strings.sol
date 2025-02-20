// @author Daosourced
// @date August 21 2023

pragma solidity ^0.8.0;
import "./openzeppelin_contracts_utils_math_Math.sol";


library Strings {
    struct Slice {
        uint256 _len;
        uint256 _ptr;
    }

    /**
     * @dev Returns a slice containing the entire string.
     * @param self The string to make a slice from.
     * @return A newly allocated slice containing the entire string.
     */
    function toSlice(string memory self) internal pure returns (Slice memory) {
        uint256 ptr;
        /* solium-disable-next-line security/no-inline-assembly */
        assembly {
            ptr := add(self, 0x20)
        }
        return Slice(bytes(self).length, ptr);
    }

    /**
     * @dev Returns the keccak-256 hash of the slice.
     * @param self The slice to hash.
     * @return ret The hash of the slice.
     */
    function keccak(Slice memory self) internal pure returns (bytes32 ret) {
        /* solium-disable-next-line security/no-inline-assembly */
        assembly {
            ret := keccak256(mload(add(self, 32)), mload(self))
        }
    }

    /**
     * @dev Returns the slice of the original slice.
     * @param self The slice to hash.
     * @param index The index of original slice for slice ptr.
     * @param len The sub slice length.
     * @return The slice of the original slice.
     */
    function slice(
        Slice memory self,
        uint256 index,
        uint256 len
    ) internal pure returns (Slice memory) {
        return Slice(len, self._ptr + index);
    }

    function st2Num(string memory numString) internal pure returns(uint256) {
        uint  val=0;
        bytes   memory stringBytes = bytes(numString);
        for (uint  i =  0; i<stringBytes.length; i++) {
            uint exp = stringBytes.length - i;
            bytes1 ival = stringBytes[i];
            uint8 uval = uint8(ival);
           uint256 jval = uval - uint256(0x30);
   
           val +=  (uint256(jval) * (10**(exp-1))); 
        }
      return val;
    }

    bytes16 private constant _SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        unchecked {
            uint256 length = Math.log10(value) + 1;
            string memory buffer = new string(length);
            uint256 ptr;
            /// @solidity memory-safe-assembly
            assembly {
                ptr := add(buffer, add(32, length))
            }
            while (true) {
                ptr--;
                /// @solidity memory-safe-assembly
                assembly {
                    mstore8(ptr, byte(mod(value, 10), _SYMBOLS))
                }
                value /= 10;
                if (value == 0) break;
            }
            return buffer;
        }
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        unchecked {
            return toHexString(value, Math.log256(value) + 1);
        }
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), _ADDRESS_LENGTH);
    }

    function keyHash(string memory keyword) internal pure returns (uint256 _keyHash) {
        _keyHash = uint256(keccak256(abi.encodePacked(keyword)));
    }
    function concat(string memory left, string memory right) internal pure returns (string memory) {
        return string(abi.encodePacked(left, right));
    }
}