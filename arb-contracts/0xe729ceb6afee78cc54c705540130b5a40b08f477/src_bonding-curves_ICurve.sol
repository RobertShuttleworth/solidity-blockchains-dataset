// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {Price} from "./src_lib_Types.sol";
import {ICurveLiquidity} from "./src_bonding-curves_ICurveLiquidity.sol";

abstract contract ICurve is ICurveLiquidity {
    function MAX_CURVE_ATTRIBUTES() external view virtual returns (uint8 value);

    /**
        @notice Validates if a delta value is valid for the curve. The criteria for
        validity can be different for each type of curve, for instance ExponentialCurve
        requires delta to be greater than 1.
        @param curveAttributes all attributes belong to specific curve.
        @return valid True if delta is valid, false otherwise
     */
    function validateCurveAttributes(
        uint128[] calldata curveAttributes
    ) external pure virtual returns (bool valid);

    /**
        @notice Given the current state of the pair and the trade, computes how much the user
        should pay to purchase an NFT from the pair, the new spot price, and other values.
        @param priceInputParams a tuple that contains all input arguments defined as
        see {Types-PriceInputParams}
        @return priceOutput quote output for buy with porotocl fee, royalty fee, error and pool value
    */
    function getBuyInfo(
        Price.PriceInputParams calldata priceInputParams
    ) external view virtual returns (Price.PriceOutput memory priceOutput);

    /**
        @notice Given the current state of the pair and the trade, computes how much the user
        should receive when selling NFTs to the pair, the new spot price, and other values.
        @param priceInputParams a tuple that contains all input arguments defined as
        see {Types-PriceInputParams}
        @return priceOutput quote output for sell with porotocl fee, royalty fee, error and pool value
    */
    function getSellInfo(
        Price.PriceInputParams calldata priceInputParams
    ) external view virtual returns (Price.PriceOutput memory priceOutput);

    function getLpfIssued(
        Price.LpInputParams calldata lpfInput
    ) external view virtual override returns (uint256);

    function getLpnIssued(
        Price.LpInputParams calldata lpfInput
    ) external view virtual override returns (uint256);

    function getPoolFeeShare(
        uint128[] memory curveAttributes,
        uint256 tokenAmount,
        uint128 sumRarity,
        uint256 poolFeeAccrued,
        uint256 poolValueWihoutFee
    ) external view virtual override returns (uint256);
}