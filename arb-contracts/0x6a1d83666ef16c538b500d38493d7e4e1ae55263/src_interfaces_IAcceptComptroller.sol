// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/**
 * @title IAcceptComptroller
 * @notice Interface is used to provide the addresses with a way to call the
 * acceptComptroller function
 * @notice The acceptComptroller function is implemented accross all
 * Comptroller complient contracts and is used as a two step ownership transfer
 */
interface IAcceptComptroller {
  function acceptComptroller() external;
}