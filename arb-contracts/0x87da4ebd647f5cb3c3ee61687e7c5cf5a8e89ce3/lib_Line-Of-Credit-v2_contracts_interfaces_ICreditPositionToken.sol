// make a new interface for the lending position token

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IERC721} from "./lib_openzeppelin-contracts_contracts_token_ERC721_IERC721.sol";

interface ICreditPositionToken is IERC721 {
    struct PositionInfo {
        address line;
        uint256 id;
        uint256 deposit;
        uint256 principal;
        uint256 interestAccrued;
        uint256 interestRepaid;
        uint128 dRate;
        uint128 fRate;
        uint256 deadline;
        uint256 mincratio;
    }

    error OpenProposals();
    error CallerIsNotLine();
    error NotSupportedLineFactory();
    error PositionTokenTransferRestricted();


    event SupportedLineFactorySet(address indexed sender, address indexed lineFactory, bool supported);
    event UpdateAdmin(address indexed newAdmin);

    function admin() external view returns (address);

    function mint(address lineFactory, address to, address line, bool iRestricted) external returns (uint256);
    function approveTokenTransfer(uint256 tokenId, address to) external;
    function getPositionInfo(uint256 tokenId) external view returns (PositionInfo memory);
    function getCRatio(uint256 tokenId) external returns (uint256);
    function openProposal(uint256 tokenId) external;
    function closeProposal(uint256 tokenId) external;
    function setLineFactory(address lineFactory, bool supported) external returns (bool);
    function updateAdmin(address newAdmin) external returns (bool);
}