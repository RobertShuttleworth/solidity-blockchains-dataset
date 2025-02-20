// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.28;

interface ISpectra {
    function burnFrom(address account, uint256 amount) external;
    function mint(address account, uint256 amount) external returns (bool);
}