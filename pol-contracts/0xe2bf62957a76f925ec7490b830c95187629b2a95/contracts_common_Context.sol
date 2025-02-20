// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

/**
 * @title Context
 * @dev Provides information about the current execution context, including the sender of the transaction and its data.
 */
abstract contract Context {
    /**
     * @dev Returns the address of the current caller.
     * @return The address of the caller.
     */
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    /**
     * @dev Returns the data payload sent with the transaction.
     * @return The data payload.
     */
    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}