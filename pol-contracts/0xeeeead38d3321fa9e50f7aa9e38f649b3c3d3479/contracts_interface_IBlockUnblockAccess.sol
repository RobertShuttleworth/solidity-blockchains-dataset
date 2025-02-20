// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

interface IBlockUnblockAccess {
    
    /**
     * @dev Returns the access status of an account.
     */
    function blockedUsers(address account) external view returns (bool);
}