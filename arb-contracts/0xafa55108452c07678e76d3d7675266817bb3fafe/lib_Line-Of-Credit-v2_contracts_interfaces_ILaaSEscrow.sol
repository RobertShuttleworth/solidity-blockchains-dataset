// SPDX-License-Identifier: GPL-3.0
// Copyright: https://github.com/credit-cooperative/Line-Of-Credit-v2/blob/master/COPYRIGHT.md
import {IEscrow} from "./lib_Line-Of-Credit-v2_contracts_interfaces_IEscrow.sol";

pragma solidity ^0.8.25;

interface ILaaSEscrow is IEscrow {
    event LiquidityPositionAdded(uint256 indexed index, ILaaSEscrow.LiquidityPosition indexed lpData);
    event LiquidityPositionUpdated(uint256 indexed index, ILaaSEscrow.LiquidityPosition indexed lpData);
    event LiquidityPositionRemoved(uint256 indexed index);

    error NoLiquidityPosition();
    error ApronNotBreached();
    error LPNotLiquidated();
    error LineIsLiquidatable();
    error BadIndex();
    error UseUniswapV3();
    error NotUniV3();

    /**
     * @param componentTokens the different tokens needed for the liquidity position
     * @param componentTokenAmounts the amount of each token needed for the LP position
     * @param LpToken the token we get after providing liquidity. will serve as collateral in the escrow contract
     * @param liquidityProvisionData calldata for adding liquidity
     * @param removeLiquidityData the calldata for removing liquidity
     * @param liquidityProvisionFunc the function called to add liquidity
     * @param removeLiquidityFunc the function called to remove liquidity
     * @param apron is added on top of the mincratio. If this combined threshold is breached, partial liquidation is allowed
     * @param isDelayOnLiquidityRemoval is there a delay when liquidty is removed
     * @param isUniswapV3 is this strategy a uniswap v3 strategy?
     */
    struct LiquidityPosition {
        address[] componentTokens; // wont ever be more than 4 i think?  Curve pools
        uint256[] componentTokenAmounts;
        address LpToken;
        bytes liquidityProvisionData;
        bytes removeLiquidityData;
        bytes4 liquidityProvisionFunc;
        bytes4 removeLiquidityFunc;
        uint32 apron;
        bool isDelayOnLiquidityRemoval;
        bool isUniswapV3;
    }

    function initializeFromFactory(
        uint32 _minimumCollateralRatio,
        address _line,
        address _borrower,
        address _pool,
        address _nftPositionManager,
        address _univ3Manager
    ) external;

    function updatePoolAddress(address _pool) external;
    function updateLiquidityPositionData(uint256 index, ILaaSEscrow.LiquidityPosition calldata lpData) external;
    function removeLiquidityPosition(uint256 index) external;
    function updateMinimumCollateralRatioAfterDrawdown(uint32 _minimumCollateralRatio) external;
    function drawDownAndCreateLP(uint256 id, uint256 amount, uint256 index, uint256 minimumCollateralValue) external;
}