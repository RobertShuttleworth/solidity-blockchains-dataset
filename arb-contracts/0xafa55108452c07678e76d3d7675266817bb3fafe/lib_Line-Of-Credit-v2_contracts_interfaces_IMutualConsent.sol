pragma solidity ^0.8.25;

interface IMutualConsent {
    function mutualConsentProposals(bytes32) external view returns (address);

    function proposalCount() external view returns (uint128);
}