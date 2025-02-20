// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

abstract contract EoaExecutorWithDataProvider {
    /**
     * @dev function to execute an action on an adapter used in an EOA.
     * @param precedingAdapter Address of the preceding adapter.
     * @param succeedingAdapter Address of the succeeding adapter.
     * @param data inputs data.
     * @return tokens to be refunded to user at the end of tx.
     */
    function execute(
        address precedingAdapter,
        address succeedingAdapter,
        bytes calldata data
    ) external payable virtual returns (address[] memory tokens);
}

abstract contract EoaExecutorWithoutDataProvider {
    /**
     * @dev function to execute an action on an adapter used in an EOA.
     * @param data inputs data.
     * @return tokens to be refunded to user at the end of tx.
     */
    function execute(
        bytes calldata data
    ) external payable virtual returns (address[] memory tokens);
}