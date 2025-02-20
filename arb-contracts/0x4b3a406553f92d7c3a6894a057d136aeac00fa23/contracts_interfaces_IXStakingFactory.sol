// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./node_modules_openzeppelin_contracts_token_ERC20_IERC20.sol";

interface IXStakingFactory {
    /// @notice argument for oneInch swap function.
    struct SwapDescription {
        IERC20 srcToken;
        IERC20 dstToken;
        address payable srcReceiver;
        address payable dstReceiver;
        uint256 amount;
        uint256 minReturnAmount;
        uint256 flags;
    }

    struct Order {
        uint256 salt;
        address makerAsset;
        address takerAsset;
        address maker;
        address receiver;
        address allowedSender; // equals to Zero address on public orders
        uint256 makingAmount;
        uint256 takingAmount;
        uint256 offsets;
        bytes interactions; // concat(makerAssetData, takerAssetData, getMakingAmount, getTakingAmount, predicate, permit, preIntercation, postInteraction)
    }

    function FEE_DENOMINATOR() external view returns (uint256);

    function treasuryWallet() external view returns (address);

    function oneInchRouter() external view returns (address);

    function getDepositToken(uint8 index) external view returns (address);

    function getStakingFee() external view returns (uint256, uint256);

    function getUnstakingFee() external view returns (uint256, uint256);

    function getXStakingPools() external view returns (address[] memory);

    function isDepositToken(address token) external view returns (bool);

    function isXStakingPool(address pool) external view returns (bool);

    function decodeSwapData(bytes calldata data)
        external
        returns (address sender, address receiver, address srcToken, uint256 srcTokenAmount, uint256 minReturnAmount);

    function calculateFeeAmount(
        uint256 amount,
        bool isDeposit
    ) external view returns (uint256);

    event DeployPool(
        address deployer,
        address pool,
        uint256 poolId,
        address[] tokens,
        uint256[] allocations,
        string description,
        uint256 capitalizationCap,
        uint256 profitSharingFeeNumerator
    );
}