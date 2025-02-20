// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Denominations} from "./lib_chainlink_contracts_src_v0.8_Denominations.sol";
import {AggregatorV3Interface} from "./lib_chainlink_contracts_src_v0.8_shared_interfaces_AggregatorV3Interface.sol";
import {LineLib} from "./lib_Line-Of-Credit-v2_contracts_utils_LineLib.sol";
import {IOracle} from "./lib_Line-Of-Credit-v2_contracts_interfaces_IOracle.sol";
import {Math} from "./lib_openzeppelin-contracts_contracts_utils_math_Math.sol";

/**
 * @title   - Oracle
 * @author  - Credit Cooperative
 * @notice  - simple contract that allows tokens to be mapped to Chainlink price feeds when available and custom price feeds when not
 * @dev     - only makes request for USD prices and returns results in standard 8 decimals for Chainlink USD feeds
 */
contract Oracle is IOracle {
    using Math for uint256;
    /// @notice Price Feeds - mapping of token addresses to either chainlink price feeds or custom price feeds
    mapping(address => address) public priceFeed; // token => chainlink price feed
    /// @notice NULL_PRICE - null price when asset price feed is deemed invalid
    int256 public constant NULL_PRICE = 0;
    /// @notice PRICE_DECIMALS - the normalized amount of decimals for returned prices in USD
    uint8 public constant PRICE_DECIMALS = 8;
    /// @notice MAX_PRICE_LATENCY - amount of time between oracle responses until an asset is determined toxiz
    /// Assumes Chainlink updates price minimum of once every 24hrs and 1 hour buffer for network issues
    uint256 public constant MAX_PRICE_LATENCY = 25 hours;
    /// @notice owner - address of the owner of the contract
    address public owner;

    /**
     * @notice - constructor for the Oracle contract
     * @param _assets - array of token addresses
     * @param _priceFeeds - array of price feed addresses
     */
    constructor(address[] memory _assets, address[] memory _priceFeeds) {
        /// @dev - check that length of _assets and _priceFeeds are identical
        if (_assets.length != _priceFeeds.length) {
            revert InvalidInput();
        }

        for (uint256 i = 0; i < _assets.length; i++) {
            address feed = _priceFeeds[i];
            address asset = _assets[i];
            priceFeed[asset] = feed;
        }
        owner = msg.sender;
    }

    /**
     * @notice          - View function for oracle pricing that can be used off-chain.
     * @dev             - Can be used onchain for less gas than `getLatestAnswer` (no event emission).
     * @param token_     - ERC20 token to get USD price for
     * @return price    - the latest price in USD to 8 decimals
     */
    function getLatestAnswer(address token_) external view returns (int256) {

        if (priceFeed[token_] == address(0)) {
            return NULL_PRICE;
        }

        try AggregatorV3Interface(priceFeed[token_]).latestRoundData() returns (
            uint80, /* uint80 roundID */
            int256 _price,
            uint256, /* uint256 roundStartTime */
            uint256 answerTimestamp, /* uint80 answeredInRound */
            uint80
        ) {
            
            // no price for asset if price is stale. Asset is toxic
            if (answerTimestamp == 0 || block.timestamp - answerTimestamp > MAX_PRICE_LATENCY) {
                return NULL_PRICE;
            }
            if (_price <= NULL_PRICE) {
                return NULL_PRICE;
            }

            try AggregatorV3Interface(priceFeed[token_]).decimals() returns (uint8 decimals) {
                // if already at target decimals then return price
                if (decimals == PRICE_DECIMALS) return _price;
                // transform decimals to target value. disregard rounding errors
                return decimals < PRICE_DECIMALS
                    ? _price * int256(10 ** (PRICE_DECIMALS - decimals))
                    : _price / int256(10 ** (decimals - PRICE_DECIMALS));
            } catch (bytes memory) {
                return NULL_PRICE;
            }
            // another try catch for decimals call
        } catch (bytes memory) {
            return NULL_PRICE;
        }
    }

    /**
     * @notice Get the decimals of a given token_
     * @return - The number of decimals of a given token_
     */
    function decimals(address token_) external view returns (uint8) {
        if (priceFeed[token_] == address(0)) {
            revert InvalidToken();
        }

        try AggregatorV3Interface(priceFeed[token_]).decimals() returns (uint8 decimals) {
            return decimals;
        } catch (bytes memory) {
            return 0;
        }
    }

    /**
     * @notice          - used to set the owner of the contract
     * @dev             - only callable by the current owner
     * @dev            - owner can modify price feeds
     * @param _owner - new owner address
     */
    function setOwner(address _owner) external {
        if (msg.sender != owner) {
            revert NotOwner();
        }
        owner = _owner;
    }

    /**
     * @notice          - used to set the price feed for a token_
     * @dev             - only callable by the current owner
     * @param token_     - token_ address
     * @param feed      - price feed address
     */
    function setPriceFeed(address token_, address feed) external {
        if (msg.sender != owner) {
            revert NotOwner();
        }
        priceFeed[token_] = feed;
    }
}