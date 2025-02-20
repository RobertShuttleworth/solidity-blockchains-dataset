// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.24;

interface IVault {
    function isSupportedToken(address _token) external view returns (bool);

    function getTokenOracle(address _token) external view returns (address);

    function convertToUSDC(
        address _token,
        uint256 _amount
    ) external view returns (uint256);

    function strategist() external view returns (address);

    function universalOracle() external view returns (address);

    function blockExternalReceiver() external view returns (bool);
}