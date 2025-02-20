// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;
import {Price} from "./src_lib_Types.sol";

interface ICurveLiquidity {
    function getLiquidityInfo(
        Price.LiquidityInputParams calldata lpInput,
        bool isAddLiquidity
    ) external view returns (Price.LiquidityOutputParams memory lpOutput);

    function getLpnIssued(
        Price.LpInputParams calldata lpfInput
    ) external view returns (uint256);

    function getLpfIssued(
        Price.LpInputParams calldata lpfInput
    ) external view returns (uint256);

    function getPoolValue(
        uint128[] memory curveAttributes,
        uint256 tokenAmount,
        uint128 sumRarity
    ) external pure returns (uint256);

    function getPoolFeeShare(
        uint128[] memory curveAttributes,
        uint256 tokenAmount,
        uint128 sumRarity,
        uint256 poolFeeAccrued,
        uint256 poolValueWihoutFee
    ) external view returns (uint256);
}