// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface ICompounder2 {
  function claimAndCompound(address user, bool isCrossChain) external payable;

  function setDefaultConfigs(
    address[] memory _defaultPools,
    address[][] memory _defaultRewarders,
    uint256 _defaultStartEpochTimestamp
  ) external;

  function setOApp(address _oApp) external;

  function setBridgeTokenLzEids(address[] memory _tokens, uint16[] memory _lzEids) external;

  function addDestinationLzEid(uint16[] memory _lzEids) external;

  function setGasForDestinationLzReceive(uint256 gasLimit) external;
}