// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

interface ILpCloner {
    function cloneLpTokens(
        string memory nftSymbol,
        address pool
    ) external returns (address, address);
}