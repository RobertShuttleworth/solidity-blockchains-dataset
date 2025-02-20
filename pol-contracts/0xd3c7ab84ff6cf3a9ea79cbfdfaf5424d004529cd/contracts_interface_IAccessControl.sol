// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

interface IAccessControl {
    
    /**
     * @dev Returns the access status of an account.
     */
    function whitelisted(address account) external view returns (bool);
}