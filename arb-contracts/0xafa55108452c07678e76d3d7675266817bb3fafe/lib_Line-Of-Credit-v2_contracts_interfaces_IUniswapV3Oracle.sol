pragma solidity ^0.8.25;

interface IUniswapV3Oracle {
    /**
     * current price for token asset. denominated in USD
     */
    function getLatestAnswer(uint256 tokenId) external view returns (uint256, uint8);

    error InvalidCollateral();
}