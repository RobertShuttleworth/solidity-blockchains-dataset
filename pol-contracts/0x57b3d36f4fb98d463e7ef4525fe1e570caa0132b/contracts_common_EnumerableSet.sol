// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

/**
 * @title EnumerableSet
 * @dev Library for managing sets of addresses and integers with efficient enumeration.
 */
library EnumerableSet {
    struct Set {
        bytes32[] _values;
        mapping(bytes32 => uint256) _indexes;
    }

    /**
     * @dev Adds a value to the set.
     * @param set The set to add the value to.
     * @param value The value to add.
     * @return Whether the value was added.
     */
    function _add(Set storage set, bytes32 value) private returns (bool) {
        if (!_contains(set, value)) {
            set._values.push(value);
            set._indexes[value] = set._values.length;
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Removes a value from the set.
     * @param set The set to remove the value from.
     * @param value The value to remove.
     * @return Whether the value was removed.
     */
    function _remove(Set storage set, bytes32 value) private returns (bool) {
        uint256 valueIndex = set._indexes[value];
        if (valueIndex != 0) {
            uint256 toDeleteIndex = valueIndex - 1;
            uint256 lastIndex = set._values.length - 1;
            bytes32 lastvalue = set._values[lastIndex];
            set._values[toDeleteIndex] = lastvalue;
            set._indexes[lastvalue] = toDeleteIndex + 1;
            set._values.pop();
            delete set._indexes[value];
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Checks if a value is in the set.
     * @param set The set to check.
     * @param value The value to check.
     * @return Whether the value is in the set.
     */
    function _contains(Set storage set, bytes32 value) private view returns (bool) {
        return set._indexes[value] != 0;
    }

    /**
     * @dev Returns the length of the set.
     * @param set The set to get the length of.
     * @return The length of the set.
     */
    function _length(Set storage set) private view returns (uint256) {
        return set._values.length;
    }

    /**
     * @dev Returns the value at a specific index in the set.
     * @param set The set to get the value from.
     * @param index The index of the value to get.
     * @return The value at the specified index.
     */
    function _at(Set storage set, uint256 index) private view returns (bytes32) {
        require(set._values.length > index, "EnumerableSet: index out of bounds");
        return set._values[index];
    }

    struct AddressSet {
        Set _inner;
    }

    /**
     * @dev Adds an address to the set.
     * @param set The set to add the address to.
     * @param value The address to add.
     * @return Whether the address was added.
     */
    function add(AddressSet storage set, address value) internal returns (bool) {
        return _add(set._inner, bytes32(uint256(value)));
    }

    /**
     * @dev Removes an address from the set.
     * @param set The set to remove the address from.
     * @param value The address to remove.
     * @return Whether the address was removed.
     */
    function remove(AddressSet storage set, address value) internal returns (bool) {
        return _remove(set._inner, bytes32(uint256(value)));
    }

    /**
     * @dev Checks if an address is in the set.
     * @param set The set to check.
     * @param value The address to check.
     * @return Whether the address is in the set.
     */
    function contains(AddressSet storage set, address value) internal view returns (bool) {
        return _contains(set._inner, bytes32(uint256(value)));
    }

    /**
     * @dev Returns the length of the address set.
     * @param set The set to get the length of.
     * @return The length of the address set.
     */
    function length(AddressSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the address at a specific index in the set.
     * @param set The set to get the address from.
     * @param index The index of the address to get.
     * @return The address at the specified index.
     */
    function at(AddressSet storage set, uint256 index) internal view returns (address) {
        return address(uint256(_at(set._inner, index)));
    }

    struct UintSet {
        Set _inner;
    }

    /**
     * @dev Adds an integer to the set.
     * @param set The set to add the integer to.
     * @param value The integer to add.
     * @return Whether the integer was added.
     */
    function add(UintSet storage set, uint256 value) internal returns (bool) {
        return _add(set._inner, bytes32(value));
    }

    /**
     * @dev Removes an integer from the set.
     * @param set The set to remove the integer from.
     * @param value The integer to remove.
     * @return Whether the integer was removed.
     */
    function remove(UintSet storage set, uint256 value) internal returns (bool) {
        return _remove(set._inner, bytes32(value));
    }

    /**
     * @dev Checks if an integer is in the set.
     * @param set The set to check.
     * @param value The integer to check.
     * @return Whether the integer is in the set.
     */
    function contains(UintSet storage set, uint256 value) internal view returns (bool) {
        return _contains(set._inner, bytes32(value));
    }

    /**
     * @dev Returns the length of the integer set.
     * @param set The set to get the length of.
     * @return The length of the integer set.
     */
    function length(UintSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the integer at a specific index in the set.
     * @param set The set to get the integer from.
     * @param index The index of the integer to get.
     * @return The integer at the specified index.
     */
    function at(UintSet storage set, uint256 index) internal view returns (uint256) {
        return uint256(_at(set._inner, index));
    }
}