// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./solvprotocol_contracts-v3-sft-abilities_contracts_issuable_ISFTIssuableConcrete.sol";

interface ISFTValueIssuableConcrete is ISFTIssuableConcrete {
    function burnOnlyDelegate(uint256 tokenId, uint256 burnValue) external;
}