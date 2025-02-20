// SPDX-License-Identifier: BSD 3-Clause

pragma solidity 0.8.9;

interface IVault {
  enum DepositType {
    vaultDeposit,
    swapUSDForToken,
    swapBuyDNO
  }

  function updateQualifiedLevel(address _user1Address, address _user2Address) external;
  function depositFor(address _userAddress, uint _amount, DepositType _depositType) external;
  function getUserInfo(address _user) external view returns (uint, uint);
  function getTokenPrice() external view returns (uint);
  function updateUserTotalClaimedInUSD(address _user, uint _usd) external;
  function airdrop(address _userAddress, uint _amount) external;
  function users(address _user) external view returns (uint, uint, uint, uint, uint, uint, uint, uint, uint, uint, uint, uint, uint, uint);
  function getUserLevel(address _user) external view returns (uint);
  function isAutoCompoundRunning(address _userAddress) external view returns (bool);
  function getUserIC(address _userAddress) external view returns (uint);
}