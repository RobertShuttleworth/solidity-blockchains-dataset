// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFiat24CryptoDeposit {
    function depositByWallet(address _client, address _outputToken, uint256 _usdcAmount) external returns(uint256);
    function minUsdcDepositAmount() external returns(uint256);
}