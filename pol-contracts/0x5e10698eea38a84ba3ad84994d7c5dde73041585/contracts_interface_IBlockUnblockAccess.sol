// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.20;

interface IBlockUnblockAccess {
    
    /**
     * @dev Returns the access status of an account.
     */
    function blockedUsers(address account) external view returns (bool);
}