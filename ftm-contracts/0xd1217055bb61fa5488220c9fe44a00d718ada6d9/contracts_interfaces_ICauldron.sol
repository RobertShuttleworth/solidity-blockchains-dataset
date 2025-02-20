// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface ICauldron {
    function addCollateral(
        address to,
        bool skim,
        uint256 share
    ) external;
    function borrow(address to, uint256 amount) external returns (uint256 part, uint256 share);
    function repay(
        address to,
        bool skim,
        uint256 part
    ) external returns (uint256 amount);
    function removeCollateral(address to, uint256 share) external;
    function liquidate() external;
}