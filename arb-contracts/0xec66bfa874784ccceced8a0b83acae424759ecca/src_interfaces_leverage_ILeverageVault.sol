// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ILeverageVault {
    function previewDeposit(uint256 assets) external view returns (uint256);
    function previewRedeem(uint256 shares) external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function totalAssets() external view returns (uint256);
    function totalSupply() external view returns (uint256);

    function burn(address account, uint256 shares) external;
    function mint(uint256 shares, address receiver) external;
}