// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "./contracts_interfaces_IProxyBetting.sol";

interface IStakingThalesBettingProxy is IProxyBetting {
    function preConfirmLiveTrade(bytes32 requestId, uint _buyInAmount) external;
    function confirmLiveTrade(bytes32 requestId, address _createdTicket, uint _buyInAmount) external;
}