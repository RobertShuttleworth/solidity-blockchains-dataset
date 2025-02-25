// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IAero} from "./contracts_interfaces_IAero.sol";
import {IVotingEscrow} from "./contracts_interfaces_IVotingEscrow.sol";
import {Ownable} from "./lib_openzeppelin-contracts_contracts_access_Ownable.sol";

interface IAirdropDistributor {
    error InvalidParams();
    error InsufficientBalance();

    event Airdrop(address indexed _wallet, uint256 _amount, uint256 _tokenId);

    /// @notice Interface of Aero.sol
    function aero() external view returns (IAero);

    /// @notice Interface of IVotingEscrow.sol
    function ve() external view returns (IVotingEscrow);

    /// @notice Distributes permanently locked NFTs to the desired addresses
    /// @param _wallets Addresses of wallets to receive the Airdrop
    /// @param _amounts Amounts to be Airdropped
    function distributeTokens(address[] memory _wallets, uint256[] memory _amounts) external;
}