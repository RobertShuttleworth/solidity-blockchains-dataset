// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./solvprotocol_contracts-v3-sft-abilities_contracts_issuable_ISFTIssuableDelegate.sol";

interface ISFTValueIssuableDelegate is ISFTIssuableDelegate {
    function mintValueOnlyIssueMarket(address txSender, address currency, uint256 tokenId, uint256 mintValue) external payable;
    function burnOnlyIssueMarket(uint256 tokenId, uint256 burnValue) external;
}