// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface ISavePayEx {
    function withdraw(address token, address payable to, uint256 amount) external;
    function depositFiat24Crypto(address _client, address _outputToken, uint256 _usdcAmount) external returns(uint256 outputAmount);
}