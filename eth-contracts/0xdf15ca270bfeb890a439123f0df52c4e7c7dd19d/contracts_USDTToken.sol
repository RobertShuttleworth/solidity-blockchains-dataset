// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./openzeppelin_contracts_token_ERC20_ERC20.sol";
import "./openzeppelin_contracts_access_Ownable.sol";
import "./chainlink_contracts_src_v0.8_interfaces_AggregatorV3Interface.sol";

/**
 * @title USDTToken
 * @dev ERC20 token mimicking the real USDT with USD value integration.
 */
contract USDTToken is ERC20, Ownable {
    AggregatorV3Interface internal priceFeed;

    /**
     * @dev Constructor initializes the token and sets the Chainlink price feed.
     * @param _priceFeedAddress Address of the Chainlink price feed for USDT/USD.
     */
    constructor(address _priceFeedAddress) ERC20("USDT", "USDT") Ownable(msg.sender) {
        priceFeed = AggregatorV3Interface(_priceFeedAddress);
    }

    /**
     * @dev Override decimals to 6 as per USDT standard
     */
    function decimals() public pure override returns (uint8) {
        return 6;
    }

    /**
     * @dev Mints tokens to a specified address. Callable only by the owner.
     * @param to Address to mint tokens to.
     * @param amount Amount of tokens to mint (with decimals).
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /**
     * @dev Burns tokens from a specified address. Callable only by the owner.
     * @param from Address to burn tokens from.
     * @param amount Amount of tokens to burn (with decimals).
     */
    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }

    /**
     * @dev Fetches the current price of USDT in USD from the Chainlink price feed.
     * @return price Price of 1 USDT in USD (8 decimals).
     */
    function getPrice() public view returns (int256) {
        (, int256 price, , , ) = priceFeed.latestRoundData();
        return price; // Price with 8 decimals
    }

    /**
     * @dev Converts token balance to USD value using the price feed.
     * @param account Address to fetch USD value for.
     * @return usdValue USD value of the token balance.
     */
    function getBalanceInUSD(address account) public view returns (uint256) {
        uint256 tokenBalance = balanceOf(account); // Token balance in 6 decimals
        int256 price = getPrice(); // Price in 8 decimals
        require(price > 0, "Invalid price data");

        // Convert balance to USD (18 decimals for consistency)
        return (tokenBalance * uint256(price)) / 10**6;
    }
}