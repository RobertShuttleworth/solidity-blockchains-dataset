// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {IUniswapV3Oracle} from "./lib_Line-Of-Credit-v2_contracts_interfaces_IUniswapV3Oracle.sol";
import {Math} from "./lib_openzeppelin-contracts_contracts_utils_math_Math.sol";
import {IERC20Metadata} from "./lib_openzeppelin-contracts_contracts_token_ERC20_extensions_IERC20Metadata.sol";
import {INonFungiblePositionManager} from "./lib_Line-Of-Credit-v2_contracts_interfaces_INonFungiblePositionManager.sol";
import {IOracle} from "./lib_Line-Of-Credit-v2_contracts_interfaces_IOracle.sol";
import {LiquidityAmounts} from "./lib_Line-Of-Credit-v2_lib_v3-periphery_contracts_libraries_LiquidityAmounts.sol";
import {TickMath} from "./lib_Line-Of-Credit-v2_lib_v3-core_contracts_libraries_TickMath.sol";

/**
 * @title   - Uniswap V3 Oracle
 * @author  - Credit Cooperative
 * @notice  - simple contract that wraps the Uniswap V3 NFT Position Manager contract to get the USD value of a position
 *          - only makes request for USD prices and returns results in standard 8 decimals to match Chainlink USD feeds
 * @notice - this oracle DOES NOT take into account unclaimed fees when appraising the position
 * @notice - this oracle requires both tokens in the pair to have on chain price feeds or it cannot get correct value
 */
contract UniswapV3Oracle is IUniswapV3Oracle {
    /// @notice oracle - the address of the erc20 oracle contract
    address oracle;
    /// @notice nftPositionManager - the address of the Uniswap V3 NFT Position Manager contract
    address public nftPositionManager;
    /// @notice PRICE_DECIMALS - the normalized amount of decimals for returned prices in USD
    uint8 public constant PRICE_DECIMALS = 8;
    /// @notice NULL_PRICE - null price when asset price feed is deemed invalid
    uint256 public constant NULL_PRICE = 0;
    /// @notice owner - the address of the owner of the contract
    address public owner;

    constructor(address _oracle, address _nftPositionManager) {
        oracle = _oracle;
        nftPositionManager = _nftPositionManager;
        owner = msg.sender;
    }

    /**
     * @notice - takes a tokenId of a uniswap v3 position and finds the USD value based price of the two assets and liquidity within the position
     * @dev - will revert if value above 0 is not given for both token0 and token1
     * @dev - leverages several uniswap v3 libraries to calculate the value of the position including LiquidityAmounts.sol and TickMath.sol
     * @param _tokenId - the tokenId of a uniswap v3 position
     * @return - the USD value of the position
     * @return - the decimals of the token
     */
    function getLatestAnswer(uint256 _tokenId) external view returns (uint256, uint8) {
        INonFungiblePositionManager.Position memory position =
            INonFungiblePositionManager(nftPositionManager).positions(_tokenId);
        uint256 token0Price = uint256(IOracle(oracle).getLatestAnswer(position.token0));
        uint256 token1Price = uint256(IOracle(oracle).getLatestAnswer(position.token1));

        if (token0Price == 0 || token1Price == 0) {
            if (token0Price == 0) revert InvalidCollateral();
            if (token1Price == 0) revert InvalidCollateral();
        }

        uint8 token0Decimals = IERC20Metadata(position.token0).decimals();
        uint8 token1Decimals = IERC20Metadata(position.token1).decimals();

        if (token0Decimals == 0 || token1Decimals == 0) {
            if (token0Decimals == 0) revert InvalidCollateral();
            if (token1Decimals == 0) revert InvalidCollateral();
        }

        uint160 sqrtPriceX96 = _getSqrtPriceX96(token0Price, token1Price);

        int24 tick = getTick(sqrtPriceX96);
        (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
            TickMath.getSqrtRatioAtTick(tick),
            TickMath.getSqrtRatioAtTick(position.tickLower),
            TickMath.getSqrtRatioAtTick(position.tickUpper),
            position.liquidity
        );
        uint256 price = _calculatePrice(amount0, amount1, token0Decimals, token1Decimals, token0Price, token1Price);
        return (price, PRICE_DECIMALS);
    }

    /**
     * @notice - calculates the square root price of two assets
     * @param priceA - the price of asset A
     * @param priceB - the price of asset B
     * @return - the square root price of the two assets
     */
    function _getSqrtPriceX96(uint256 priceA, uint256 priceB) internal pure returns (uint160) {
        uint256 ratioX192 = (priceA << 192) / priceB;
        return uint160(Math.sqrt(ratioX192));
    }

    /**
     * @notice - calculates the price of two assets
     * @param amountA - the amount of asset A
     * @param amountB - the amount of asset B
     * @param decimalA - the decimals of asset A
     * @param decimalB - the decimals of asset B
     * @param priceA - the price of asset A
     * @param priceB - the price of asset B
     * @return price - the usd price of the entire position
     */
    function _calculatePrice(
        uint256 amountA,
        uint256 amountB,
        uint256 decimalA,
        uint256 decimalB,
        uint256 priceA,
        uint256 priceB
    ) internal pure returns (uint256 price) {
        price = (amountA * priceA) / (10 ** decimalA) + (amountB * priceB) / (10 ** decimalB);
    }

    /**
     * @notice - gets the tick of a square root price
     * @param sqrtPriceX96 - the square root price
     * @return tick - the tick of the square root price
     */
    function getTick(uint160 sqrtPriceX96) public view returns (int24 tick) {
        tick = TickMath.getTickAtSqrtRatio(sqrtPriceX96);
    }

    /**
     * @notice - sets the owner of the contract
     * @param _owner - the address of the new owner
     */
    function updateOwner(address _owner) external {
        require(msg.sender == owner, "only owner can call this function");
        owner = _owner;
    }

}