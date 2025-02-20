// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "./node_modules_openzeppelin_contracts_token_ERC20_IERC20.sol";

interface IXStakingPool {
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

    event TokenSwap(
        address token,
        uint256 tokenAmount,
        uint256 baseTokenAmount
    );

    event TokensAmounts(address[] tokens, uint256[] tokenAmounts);

    event Volume(uint256 amount);

    event PoolCapitalization(address pool, uint256 capitalization);

    event UserCapitalization(
        address pool,
        address user,
        uint256 capitalization
    );

    event Deposit(
        address pool,
        address depositor,
        uint256 amount,
        uint256[] userTokenAmounts
    );

    event Withdraw(
        address pool,
        address depositor,
        uint256 amount,
        uint256[] userTokenAmounts
    );

    event DepositStatusUpdated(bool isPaused);

    function initialize(
        uint256 _poolId,
        address _poolOwner,
        uint256 _capitalizationCap,
        address[] memory _tokens,
        uint256[] memory _allocations,
        uint256 _profitSharingFeeNumerator,
        uint256[] memory _tokensAmounts,
        address initialDepositToken,
        uint256 initialBaseTokenAmount
    ) external;

    function deposit(
        address depositToken,
        uint256 baseTokenAmount,
        bytes[] calldata oneInchSwapData
    ) external returns (uint256);

    function depositTo(
        address depositToken,
        address to,
        uint256 baseTokenAmount,
        bytes[] calldata oneInchSwapData
    ) external returns (uint256);

    function withdraw(
        address depositToken,
        uint256 amountLP,
        bytes[] calldata oneInchSwapData
    ) external returns (uint256);
}