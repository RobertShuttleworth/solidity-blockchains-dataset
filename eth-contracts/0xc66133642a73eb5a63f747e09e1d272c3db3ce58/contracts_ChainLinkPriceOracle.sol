// contracts/ChainLinkPriceOracle.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./openzeppelin_contracts-upgradeable_access_OwnableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_security_PausableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";
import "./contracts_interfaces_IAggregatorV3.sol";

contract ChainLinkPriceOracle is
    Initializable,
    OwnableUpgradeable,
    PausableUpgradeable
{
    struct PriceFeed {
        AggregatorV3Interface feed;
        uint256 heartbeat;
        uint256 decimals;
        bool isActive;
    }

    mapping(address => PriceFeed) public priceFeeds;
    mapping(address => uint256) public fallbackPrices;

    uint256 public constant PRICE_PRECISION = 1e8;
    uint256 public constant DEFAULT_HEARTBEAT = 1 hours;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    event PriceFeedUpdated(address indexed token, address indexed feed);
    event FallbackPriceUpdated(address indexed token, uint256 price);
    event HeartbeatUpdated(address indexed token, uint256 heartbeat);

    function initialize(
        address _ethUsdPriceFeed,
        uint256 _heartbeat
    ) public initializer {
        __Ownable_init();
        __Pausable_init();

        require(_ethUsdPriceFeed != address(0), "Invalid price feed address");
        require(_heartbeat > 0, "Invalid heartbeat");

        PriceFeed memory ethFeed = PriceFeed({
            feed: AggregatorV3Interface(_ethUsdPriceFeed),
            heartbeat: _heartbeat,
            decimals: AggregatorV3Interface(_ethUsdPriceFeed).decimals(),
            isActive: true
        });

        priceFeeds[WETH] = ethFeed;
    }

    function getLatestPrice()
        external
        view
        whenNotPaused
        returns (uint256 price, uint256 timestamp)
    {
        return _getPrice(WETH);
    }

    function getTokenPrice(
        address _token
    ) external view whenNotPaused returns (uint256 price, uint256 timestamp) {
        return _getPrice(_token);
    }

    function _getPrice(
        address _token
    ) internal view returns (uint256 price, uint256 timestamp) {
        PriceFeed memory feed = priceFeeds[_token];

        if (!feed.isActive) {
            uint256 fallbackPrice = fallbackPrices[_token];
            require(fallbackPrice > 0, "No price available");
            return (fallbackPrice, block.timestamp);
        }

        try feed.feed.latestRoundData() returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) {
            require(answer > 0, "Negative price");
            require(updatedAt != 0, "Incomplete round");
            require(answeredInRound >= roundId, "Stale price");
            require(
                block.timestamp <= updatedAt + feed.heartbeat,
                "Stale price"
            );

            // Convert int256 to uint256 safely
            uint256 rawPrice = uint256(answer);

            // No need for decimal conversion as we're using same precision
            // MockV3Aggregator is set to 8 decimals and PRICE_PRECISION is 1e8
            return (rawPrice, updatedAt);
        } catch {
            revert("Price feed failed");
        }
    }

    // Additional ChainLinkPriceOracle functions will continue in the
    // Continuing ChainLinkPriceOracle.sol...

    function updatePriceFeed(
        address _token,
        address _feed,
        uint256 _heartbeat
    ) external onlyOwner {
        require(_token != address(0), "Invalid token");
        require(_feed != address(0), "Invalid feed address");
        require(_heartbeat > 0, "Invalid heartbeat");

        AggregatorV3Interface feedInterface = AggregatorV3Interface(_feed);

        PriceFeed memory newFeed = PriceFeed({
            feed: feedInterface,
            heartbeat: _heartbeat,
            decimals: feedInterface.decimals(),
            isActive: true
        });

        priceFeeds[_token] = newFeed;
        emit PriceFeedUpdated(_token, _feed);
        emit HeartbeatUpdated(_token, _heartbeat);
    }

    function setFallbackPrice(
        address _token,
        uint256 _price
    ) external onlyOwner {
        require(_token != address(0), "Invalid token");
        require(_price > 0, "Invalid price");

        fallbackPrices[_token] = _price;
        emit FallbackPriceUpdated(_token, _price);
    }

    function setPriceFeedStatus(
        address _token,
        bool _isActive
    ) external onlyOwner {
        require(
            priceFeeds[_token].feed != AggregatorV3Interface(address(0)),
            "Feed not set"
        );
        priceFeeds[_token].isActive = _isActive;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}