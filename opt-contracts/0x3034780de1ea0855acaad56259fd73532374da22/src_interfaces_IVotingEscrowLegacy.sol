// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.28;

interface IVotingEscrowLegacy {
    function locked__amount(address account) external view returns (uint256);
    function locked__end(address account) external view returns (uint256);
}