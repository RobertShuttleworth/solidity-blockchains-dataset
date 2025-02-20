// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

contract Errors {
    /// @notice Error thrown when an address is the zero address.
    error Address0();
    /// @notice Error thrown when the caller is not an EOA.
    error OnlyEOA();

    /// @notice Error thrown when an amount is zero.
    error Amount0();

    /// @notice Error thrown when an operation is attempted after the specified deadline.
    error Expired();

    /// @notice Error thrown when one value is greater than another.
    /// @param a The first value that is greater than the second value.
    /// @param b The second value which is smaller or equal to the first value.
    error GreaterThan(uint256 a, uint256 b);

    /**
     * @notice Modifier to ensure the first value is not greater than the second.
     * @dev Throws a `GreaterThan` error if `b` is smaller than `a`.
     * @param a The first value to be compared.
     * @param b The second value to be compared.
     */
    modifier notGt(uint256 a, uint256 b) {
        require(b >= a, GreaterThan(a, b));
        _;
    }

    /**
     * @notice Modifier to prevent operations when the caller is not an EOA.
     * @dev Throws an `OnlyEOA` error if the caller is not an EOA.
     */
    modifier onlyEOA() {
        require(msg.sender.code.length == 0 && tx.origin == msg.sender, OnlyEOA());
        _;
    }

    modifier notAmount0(uint256 a) {
        _notAmount0(a);
        _;
    }

    modifier notExpired(uint32 _deadline) {
        if (block.timestamp > _deadline) revert Expired();
        _;
    }

    modifier notAddress0(address a) {
        _notAddress0(a);
        _;
    }

    function _notAddress0(address a) internal pure {
        if (a == address(0)) revert Address0();
    }

    function _notAmount0(uint256 a) internal pure {
        if (a == 0) revert Amount0();
    }
}