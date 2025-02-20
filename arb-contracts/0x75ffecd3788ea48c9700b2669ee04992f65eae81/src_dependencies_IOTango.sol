// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {IERC20} from "./lib_openzeppelin-contracts_contracts_token_ERC20_IERC20.sol";
import {IERC20Permit} from "./lib_openzeppelin-contracts_contracts_token_ERC20_extensions_IERC20Permit.sol";

interface IOTango is IERC20, IERC20Permit {
    error InvalidFloorPrice(int256 floorPrice);
    error PRBMath_MulDiv18_Overflow(uint256 x, uint256 y);
    error PRBMath_MulDiv_Overflow(uint256 x, uint256 y, uint256 denominator);
    error PRBMath_SD59x18_Div_InputTooSmall();
    error PRBMath_SD59x18_Div_Overflow(int256 x, int256 y);
    error PRBMath_SD59x18_IntoUint256_Underflow(int256 x);
    error PRBMath_SD59x18_Log_InputTooSmall(int256 x);
    error PRBMath_SD59x18_Mul_InputTooSmall();
    error PRBMath_SD59x18_Mul_Overflow(int256 x, int256 y);
    error SlippageCheck(int256 max, int256 actual);
    error StaleOraclePrice(uint256 timestamp, uint256 price);
    error ZeroCost();
    error ZeroDestination();
    error ZeroPayer();
    error ZeroPrice();

    event Exercised(
        address indexed account, int256 amount, int256 tangoPrice, int256 discount, int256 strikePrice, uint256 cost
    );

    function previewExercise(int256 amount)
        external
        view
        returns (int256 tangoPrice_, int256 discount, int256 strikePrice, uint256 cost);

    function increaseAllowance(address spender, uint256 addedValue) external returns (bool);
    function exercise(int256 amount, int256 maxPrice)
        external
        returns (int256 tangoPrice_, int256 discount, int256 strikePrice, uint256 cost);

    function tangoPrice() external view returns (int256);
}