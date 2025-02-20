// SPDX-License-Identifier: BSD 3-Clause

pragma solidity 0.8.9;

interface ICitizen {
  function isCitizen(address _address) external view returns (bool);
  function getInviter(address _address) external returns (address);
  function defaultInviter() external returns (address);
  function isSameLine(address _from, address _to) external view returns (bool);
  function residents(address _address) external view returns (uint, string memory, address);
}