/// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.24;

import {SafeTransferLib} from "./lib_solmate_src_utils_SafeTransferLib.sol";
import {ERC20} from "./lib_solmate_src_tokens_ERC20.sol";
import {Ownable} from "./lib_openzeppelin-contracts_contracts_access_Ownable.sol";
import {IChainlinkAggregator} from "./contracts_interfaces_IChainlinkAggregator.sol";
import {SafeCast} from "./lib_openzeppelin-contracts_contracts_utils_math_SafeCast.sol";
import {Math} from "./contracts_utils_Math.sol";
import {Address} from "./openzeppelin_contracts_utils_Address.sol";
import {AdditionalSource} from "./contracts_oracles_AdditionalSource.sol";

/**
 * @notice Attempted to set a minimum price below the Chainlink minimum price (with buffer).
 * @param minPrice minimum price attempted to set
 * @param bufferedMinPrice minimum price that can be set including buffer
 */
error UniversalOracle__InvalidMinPrice(
    uint256 minPrice,
    uint256 bufferedMinPrice
);

/**
 * @notice Attempted to set a maximum price above the Chainlink maximum price (with buffer).
 * @param maxPrice maximum price attempted to set
 * @param bufferedMaxPrice maximum price that can be set including buffer
 */
error UniversalOracle__InvalidMaxPrice(
    uint256 maxPrice,
    uint256 bufferedMaxPrice
);

/**
 * @notice Attempted to add an invalid asset.
 * @param asset address of the invalid asset
 */
error UniversalOracle__InvalidAsset(address asset);

/**
 * @notice Attempted to add an asset that is already supported.
 */
error UniversalOracle__AssetAlreadyAdded(address asset);

/**
 * @notice Attempted to edit an asset that is not supported.
 */
error UniversalOracle__AssetNotAdded(address asset);

/**
 * @notice Attempted to edit an asset that is not editable.
 */
error UniversalOracle__AssetNotEditable(address asset);

/**
 * @notice Attempted to cancel the editing of an asset that is not pending edit.
 */
error UniversalOracle__AssetNotPendingEdit(address asset);

/**
 * @notice Attempted to add an asset, but actual answer was outside range of expectedAnswer.
 */
error UniversalOracle__BadAnswer(uint256 answer, uint256 expectedAnswer);

/**
 * @notice Attempted to perform an operation using an unknown derivative.
 */
error UniversalOracle__UnknownDerivative(uint8 unknownDerivative);

/**
 * @notice Attempted to add an asset with invalid min/max prices.
 * @param min price
 * @param max price
 */
error UniversalOracle__MinPriceGreaterThanMaxPrice(uint256 min, uint256 max);
/**
 * @notice Attempted to update the asset to one that is not supported by the platform.
 * @param asset address of the unsupported asset
 */
error UniversalOracle__UnsupportedAsset(address asset);
/**
 * @notice Attempted an operation to price an asset that under its minimum valid price.
 * @param asset address of the asset that is under its minimum valid price
 * @param price price of the asset
 * @param minPrice minimum valid price of the asset
 */
error UniversalOracle__AssetBelowMinPrice(
    address asset,
    uint256 price,
    uint256 minPrice
);

/**
 * @notice Attempted an operation to price an asset that under its maximum valid price.
 * @param asset address of the asset that is under its maximum valid price
 * @param price price of the asset
 * @param maxPrice maximum valid price of the asset
 */
error UniversalOracle__AssetAboveMaxPrice(
    address asset,
    uint256 price,
    uint256 maxPrice
);

/**
 * @notice Attempted to fetch a price for an asset that has not been updated in too long.
 * @param asset address of the asset thats price is stale
 * @param timeSinceLastUpdate seconds since the last price update
 * @param heartbeat maximum allowed time between price updates
 */
error UniversalOracle__StalePrice(
    address asset,
    uint256 timeSinceLastUpdate,
    uint256 heartbeat
);
/**
 * @notice Buffered min price exceedes 80 bits of data.
 */
error UniversalOracle__BufferedMinOverflow();
/**
 * @notice Attempted an operation with arrays of unequal lengths that were expected to be equal length.
 */
error UniversalOracle__LengthMismatch();

contract UniversalOracle is Ownable {
    using SafeTransferLib for ERC20;
    using SafeCast for int256;
    using Math for uint256;
    using Address for address;

    /**
     * @notice Bare minimum settings all derivatives support.
     * @param derivative the derivative used to price the asset
     * @param source the address used to price the asset
     */
    struct AssetSettings {
        uint8 derivative;
        address source;
    }

    /**
     * @notice Stores data for Chainlink derivative assets.
     * @param max the max valid price of the asset
     * @param min the min valid price of the asset
     * @param heartbeat the max amount of time between price updates
     * @param inETH bool indicating whether the price feed is
     *        denominated in ETH(true) or USD(false)
     */
    struct ChainlinkDerivativeStorage {
        uint144 max;
        uint80 min;
        uint24 heartbeat;
        bool inETH;
    }

    ERC20 public immutable WETH;
    /**
     * @notice Mapping between an asset to price and its `AssetSettings`.
     */
    mapping(ERC20 => AssetSettings) public getAssetSettings;
    /**
     * @notice The allowed deviation between the expected answer vs the actual answer.
     */
    uint256 public constant EXPECTED_ANSWER_DEVIATION = 0.02e18;

    /**
     * @notice Returns Chainlink Derivative Storage
     */
    mapping(ERC20 => ChainlinkDerivativeStorage)
        public getChainlinkDerivativeStorage;

    /**
     * @notice If zero is specified for a Chainlink asset heartbeat, this value is used instead.
     */
    uint24 public constant DEFAULT_HEART_BEAT = 1 days;

    event AddAsset(address indexed asset);
    event EditAssetComplete(address asset, bytes32 editHash);

    constructor(address newOwner, ERC20 _weth) Ownable(newOwner) {
        WETH = _weth;
    }

    /**
     * @notice Allows owner to add assets to the universal oracle.
     * @dev Performs a sanity check by comparing the universal oracle computed price to
     * a user input `_expectedAnswer`.
     * @param _asset the asset to add to the pricing router
     * @param _settings the settings for `_asset`
     *        @dev The `derivative` value in settings MUST be non zero.
     * @param _storage arbitrary bytes data used to configure `_asset` pricing
     * @param _expectedAnswer the expected answer for the asset from  `_getPriceInUSD`
     */
    function addAsset(
        ERC20 _asset,
        AssetSettings memory _settings,
        bytes memory _storage,
        uint256 _expectedAnswer
    ) external onlyOwner {
        // Check that asset is not already added.
        if (getAssetSettings[_asset].derivative > 0)
            revert UniversalOracle__AssetAlreadyAdded(address(_asset));

        _updateAsset(_asset, _settings, _storage, _expectedAnswer);

        emit AddAsset(address(_asset));
    }

    /**
     * @notice editAsset.
     * @param _asset the asset to finish editing in the pricing router
     * @param _settings the settings for `_asset`
     *        @dev The `derivative` value in settings MUST be non zero.
     * @param _storage arbitrary bytes data used to configure `_asset` pricing
     */
    function editAsset(
        ERC20 _asset,
        AssetSettings memory _settings,
        bytes memory _storage,
        uint256 _expectedAnswer
    ) external onlyOwner {
        bytes32 editHash = keccak256(abi.encode(_asset, _settings, _storage));
        // Edit the asset.
        _updateAsset(_asset, _settings, _storage, _expectedAnswer);

        emit EditAssetComplete(address(_asset), editHash);
    }

    /**
     * @notice Helper function to update an `_asset`s configuration.
     * @param _asset the asset to update in the pricing router
     * @param _settings the settings for `_asset`
     *        @dev The `derivative` value in settings MUST be non zero.
     * @param _storage arbitrary bytes data used to configure `_asset` pricing
     */
    function _updateAsset(
        ERC20 _asset,
        AssetSettings memory _settings,
        bytes memory _storage,
        uint256 _expectedAnswer
    ) internal {
        if (address(_asset) == address(0))
            revert UniversalOracle__InvalidAsset(address(_asset));

        // Zero is an invalid derivative.
        if (_settings.derivative == 0)
            revert UniversalOracle__UnknownDerivative(_settings.derivative);

        // Call setup function for appropriate derivative.
        if (_settings.derivative == 1) {
            _setupPriceForChainlinkDerivative(
                _asset,
                _settings.source,
                _storage
            );
        } else if (_settings.derivative == 2) {
            AdditionalSource(_settings.source).setupSource(_asset, _storage);
        } else revert UniversalOracle__UnknownDerivative(_settings.derivative);

        // Check `_getPriceInUSD` against `_expectedAnswer`.
        uint256 minAnswer = _expectedAnswer.mulWadDown(
            (1e18 - EXPECTED_ANSWER_DEVIATION)
        );
        uint256 maxAnswer = _expectedAnswer.mulWadDown(
            (1e18 + EXPECTED_ANSWER_DEVIATION)
        );

        getAssetSettings[_asset] = _settings;
        uint256 answer = _getPriceInUSD(_asset, _settings);
        if (answer < minAnswer || answer > maxAnswer)
            revert UniversalOracle__BadAnswer(answer, _expectedAnswer);
    }

    /**
     * @notice return bool indicating whether or not an asset has been set up.
     * @dev Since `addAsset` enforces the derivative is non zero, checking if the stored setting
     *      is nonzero is sufficient to see if the asset is set up.
     */
    function isSupported(ERC20 asset) external view returns (bool) {
        return getAssetSettings[asset].derivative > 0;
    }

    // ======================================= PRICING OPERATIONS =======================================

    /**
     * @notice Get `asset` price in USD.
     * @dev Returns price in USD with 8 decimals.
     */
    function getPriceInUSD(ERC20 asset) external view returns (uint256) {
        AssetSettings memory assetSettings = getAssetSettings[asset];
        return _getPriceInUSD(asset, assetSettings);
    }

    /**
     * @notice Get multiple `asset` prices in USD.
     * @dev Returns array of prices in USD with 8 decimals.
     */
    function getPricesInUSD(
        ERC20[] calldata assets
    ) external view returns (uint256[] memory prices) {
        prices = new uint256[](assets.length);
        for (uint256 i; i < assets.length; ++i) {
            AssetSettings memory assetSettings = getAssetSettings[assets[i]];
            prices[i] = _getPriceInUSD(assets[i], assetSettings);
        }
    }

    /**
     * @notice Get the value of an asset in terms of another asset.
     * @param baseAsset address of the asset to get the price of in terms of the quote asset
     * @param amount amount of the base asset to price
     * @param quoteAsset address of the asset that the base asset is priced in terms of
     * @return value value of the amount of base assets specified in terms of the quote asset
     */
    function getValue(
        ERC20 baseAsset,
        uint256 amount,
        ERC20 quoteAsset
    ) external view returns (uint256 value) {
        AssetSettings memory baseSettings = getAssetSettings[baseAsset];
        AssetSettings memory quoteSettings = getAssetSettings[quoteAsset];
        if (baseSettings.derivative == 0)
            revert UniversalOracle__UnsupportedAsset(address(baseAsset));
        if (quoteSettings.derivative == 0)
            revert UniversalOracle__UnsupportedAsset(address(quoteAsset));
        uint256 priceBaseUSD = _getPriceInUSD(baseAsset, baseSettings);
        uint256 priceQuoteUSD = _getPriceInUSD(quoteAsset, quoteSettings);
        value = _getValueInQuote(
            priceBaseUSD,
            priceQuoteUSD,
            baseAsset.decimals(),
            quoteAsset.decimals(),
            amount
        );
    }

    /**
     * @notice Helper function that compares `_getValues` between input 0 and input 1.
     */
    function getValuesDelta(
        ERC20[] calldata baseAssets0,
        uint256[] calldata amounts0,
        ERC20[] calldata baseAssets1,
        uint256[] calldata amounts1,
        ERC20 quoteAsset
    ) external view returns (uint256) {
        uint256 value0 = _getValues(baseAssets0, amounts0, quoteAsset);
        uint256 value1 = _getValues(baseAssets1, amounts1, quoteAsset);
        return value0 - value1;
    }

    /**
     * @notice Helper function that determines the value of assets using `_getValues`.
     */
    function getValues(
        ERC20[] calldata baseAssets,
        uint256[] calldata amounts,
        ERC20 quoteAsset
    ) external view returns (uint256) {
        return _getValues(baseAssets, amounts, quoteAsset);
    }

    /**
     * @notice Get the exchange rate between two assets.
     * @param baseAsset address of the asset to get the exchange rate of in terms of the quote asset
     * @param quoteAsset address of the asset that the base asset is exchanged for
     * @return exchangeRate rate of exchange between the base asset and the quote asset
     */
    function getExchangeRate(
        ERC20 baseAsset,
        ERC20 quoteAsset
    ) public view returns (uint256 exchangeRate) {
        AssetSettings memory baseSettings = getAssetSettings[baseAsset];
        AssetSettings memory quoteSettings = getAssetSettings[quoteAsset];
        if (baseSettings.derivative == 0)
            revert UniversalOracle__UnsupportedAsset(address(baseAsset));
        if (quoteSettings.derivative == 0)
            revert UniversalOracle__UnsupportedAsset(address(quoteAsset));

        exchangeRate = _getExchangeRate(
            baseAsset,
            baseSettings,
            quoteAsset,
            quoteSettings,
            quoteAsset.decimals()
        );
    }

    /**
     * @notice Get the exchange rates between multiple assets and another asset.
     * @param baseAssets addresses of the assets to get the exchange rates of in terms of the quote asset
     * @param quoteAsset address of the asset that the base assets are exchanged for
     * @return exchangeRates rate of exchange between the base assets and the quote asset
     */
    function getExchangeRates(
        ERC20[] memory baseAssets,
        ERC20 quoteAsset
    ) external view returns (uint256[] memory exchangeRates) {
        uint8 quoteAssetDecimals = quoteAsset.decimals();
        AssetSettings memory quoteSettings = getAssetSettings[quoteAsset];
        if (quoteSettings.derivative == 0)
            revert UniversalOracle__UnsupportedAsset(address(quoteAsset));

        uint256 numOfAssets = baseAssets.length;
        exchangeRates = new uint256[](numOfAssets);
        for (uint256 i; i < numOfAssets; ++i) {
            AssetSettings memory baseSettings = getAssetSettings[baseAssets[i]];
            if (baseSettings.derivative == 0)
                revert UniversalOracle__UnsupportedAsset(
                    address(baseAssets[i])
                );
            exchangeRates[i] = _getExchangeRate(
                baseAssets[i],
                baseSettings,
                quoteAsset,
                quoteSettings,
                quoteAssetDecimals
            );
        }
    }

    // =========================================== HELPER FUNCTIONS ===========================================

    /**
     * @notice Gets the exchange rate between a base and a quote asset
     * @param baseAsset the asset to convert into quoteAsset
     * @param quoteAsset the asset base asset is converted into
     * @return exchangeRate value of base asset in terms of quote asset
     */
    function _getExchangeRate(
        ERC20 baseAsset,
        AssetSettings memory baseSettings,
        ERC20 quoteAsset,
        AssetSettings memory quoteSettings,
        uint8 quoteAssetDecimals
    ) internal view returns (uint256) {
        uint256 basePrice = _getPriceInUSD(baseAsset, baseSettings);
        uint256 quotePrice = _getPriceInUSD(quoteAsset, quoteSettings);
        uint256 exchangeRate = basePrice.mulDivDown(
            10 ** quoteAssetDecimals,
            quotePrice
        );
        return exchangeRate;
    }

    /**
     * @notice Helper function to get an assets price in USD.
     * @dev Returns price in USD with 8 decimals.
     */
    function _getPriceInUSD(
        ERC20 asset,
        AssetSettings memory settings
    ) internal view returns (uint256) {
        _runPreFlightCheck();
        // Call get price function using appropriate derivative.
        uint256 price;
        if (settings.derivative == 1) {
            price = _getPriceForChainlinkDerivative(asset, settings.source);
        } else if (settings.derivative == 2) {
            price = AdditionalSource(settings.source).getPriceInUSD(asset);
        } else revert UniversalOracle__UnknownDerivative(settings.derivative);

        return price;
    }

    /**
     * @notice If any safety checks needs to be run before pricing operations, they should be added here.
     */
    function _runPreFlightCheck() internal view virtual {}

    /**
     * @notice math function that preserves precision by multiplying the amountBase before dividing.
     * @param priceBaseUSD the base asset price in USD
     * @param priceQuoteUSD the quote asset price in USD
     * @param baseDecimals the base asset decimals
     * @param quoteDecimals the quote asset decimals
     * @param amountBase the amount of base asset
     */
    function _getValueInQuote(
        uint256 priceBaseUSD,
        uint256 priceQuoteUSD,
        uint8 baseDecimals,
        uint8 quoteDecimals,
        uint256 amountBase
    ) internal pure returns (uint256 valueInQuote) {
        // Get value in quote asset, but maintain as much precision as possible.
        // Cleaner equations below.
        // baseToUSD = amountBase * priceBaseUSD / 10**baseDecimals.
        // valueInQuote = baseToUSD * 10**quoteDecimals / priceQuoteUSD
        valueInQuote = amountBase.mulDivDown(
            (priceBaseUSD * 10 ** quoteDecimals),
            (10 ** baseDecimals * priceQuoteUSD)
        );
    }

    /**
     * @notice Get the total value of multiple assets in terms of another asset.
     * @param baseAssets addresses of the assets to get the price of in terms of the quote asset
     * @param amounts amounts of each base asset to price
     * @param quoteAsset address of the assets that the base asset is priced in terms of
     * @return value total value of the amounts of each base assets specified in terms of the quote asset
     */
    function _getValues(
        ERC20[] calldata baseAssets,
        uint256[] calldata amounts,
        ERC20 quoteAsset
    ) internal view returns (uint256) {
        if (baseAssets.length != amounts.length)
            revert UniversalOracle__LengthMismatch();
        uint256 quotePrice;
        {
            AssetSettings memory quoteSettings = getAssetSettings[quoteAsset];
            if (quoteSettings.derivative == 0)
                revert UniversalOracle__UnsupportedAsset(address(quoteAsset));
            quotePrice = _getPriceInUSD(quoteAsset, quoteSettings);
        }
        uint256 valueInQuote;
        uint8 quoteDecimals = quoteAsset.decimals();

        for (uint256 i = 0; i < baseAssets.length; ++i) {
            // Skip zero amount values.
            if (amounts[i] == 0) continue;
            ERC20 baseAsset = baseAssets[i];
            if (baseAsset == quoteAsset) valueInQuote += amounts[i];
            else {
                uint256 basePrice;
                {
                    AssetSettings memory baseSettings = getAssetSettings[
                        baseAsset
                    ];
                    if (baseSettings.derivative == 0)
                        revert UniversalOracle__UnsupportedAsset(
                            address(baseAsset)
                        );
                    basePrice = _getPriceInUSD(baseAsset, baseSettings);
                }
                valueInQuote += _getValueInQuote(
                    basePrice,
                    quotePrice,
                    baseAsset.decimals(),
                    quoteDecimals,
                    amounts[i]
                );
            }
        }
        return valueInQuote;
    }

    // =========================================== CHAINLINK PRICE DERIVATIVE ===========================================\

    /**
     * @notice Setup function for pricing Chainlink derivative assets.
     * @dev _source The address of the Chainlink Data feed.
     * @dev _storage A ChainlinkDerivativeStorage value defining valid prices.
     */
    function _setupPriceForChainlinkDerivative(
        ERC20 _asset,
        address _source,
        bytes memory _storage
    ) internal {
        ChainlinkDerivativeStorage memory parameters = abi.decode(
            _storage,
            (ChainlinkDerivativeStorage)
        );

        // Use Chainlink to get the min and max of the asset.
        IChainlinkAggregator aggregator = IChainlinkAggregator(
            IChainlinkAggregator(_source).aggregator()
        );
        uint256 minFromChainklink = uint256(uint192(aggregator.minAnswer()));
        uint256 maxFromChainlink = uint256(uint192(aggregator.maxAnswer()));

        // Add a ~10% buffer to minimum and maximum price from Chainlink because Chainlink can stop updating
        // its price before/above the min/max price.
        uint256 bufferedMinPrice = (minFromChainklink * 1.1e18) / 1e18;
        uint256 bufferedMaxPrice = (maxFromChainlink * 0.9e18) / 1e18;

        if (parameters.min == 0) {
            // Revert if bufferedMinPrice overflows because uint80 is too small to hold the minimum price,
            // and lowering it to uint80 is not safe because the price feed can stop being updated before
            // it actually gets to that lower price.
            if (bufferedMinPrice > type(uint80).max)
                revert UniversalOracle__BufferedMinOverflow();
            parameters.min = uint80(bufferedMinPrice);
        } else {
            if (parameters.min < bufferedMinPrice)
                revert UniversalOracle__InvalidMinPrice(
                    parameters.min,
                    bufferedMinPrice
                );
        }

        if (parameters.max == 0) {
            //Do not revert even if bufferedMaxPrice is greater than uint144, because lowering it to uint144 max is more conservative.
            parameters.max = bufferedMaxPrice > type(uint144).max
                ? type(uint144).max
                : uint144(bufferedMaxPrice);
        } else {
            if (parameters.max > bufferedMaxPrice)
                revert UniversalOracle__InvalidMaxPrice(
                    parameters.max,
                    bufferedMaxPrice
                );
        }

        if (parameters.min >= parameters.max)
            revert UniversalOracle__MinPriceGreaterThanMaxPrice(
                parameters.min,
                parameters.max
            );

        parameters.heartbeat = parameters.heartbeat != 0
            ? parameters.heartbeat
            : DEFAULT_HEART_BEAT;

        getChainlinkDerivativeStorage[_asset] = parameters;
    }

    /**
     * @notice Get the price of a Chainlink derivative in terms of USD.
     */
    function _getPriceForChainlinkDerivative(
        ERC20 _asset,
        address _source
    ) internal view returns (uint256) {
        ChainlinkDerivativeStorage
            memory parameters = getChainlinkDerivativeStorage[_asset];
        IChainlinkAggregator aggregator = IChainlinkAggregator(_source);
        (, int256 _price, , uint256 _timestamp, ) = aggregator
            .latestRoundData();
        uint256 price = _price.toUint256();
        _checkPriceFeed(
            address(_asset),
            price,
            _timestamp,
            parameters.max,
            parameters.min,
            parameters.heartbeat
        );
        // If price is in ETH, then convert price into USD.
        if (parameters.inETH) {
            uint256 _ethToUsd = _getPriceInUSD(WETH, getAssetSettings[WETH]);
            price = price.mulWadDown(_ethToUsd);
        }
        return price;
    }

    /**
     * @notice helper function to validate a price feed is safe to use.
     * @param asset ERC20 asset price feed data is for.
     * @param value the price value the price feed gave.
     * @param timestamp the last timestamp the price feed was updated.
     * @param max the upper price bound
     * @param min the lower price bound
     * @param heartbeat the max amount of time between price updates
     */
    function _checkPriceFeed(
        address asset,
        uint256 value,
        uint256 timestamp,
        uint144 max,
        uint88 min,
        uint24 heartbeat
    ) internal view {
        if (value < min)
            revert UniversalOracle__AssetBelowMinPrice(
                address(asset),
                value,
                min
            );

        if (value > max)
            revert UniversalOracle__AssetAboveMaxPrice(
                address(asset),
                value,
                max
            );

        uint256 timeSinceLastUpdate = block.timestamp - timestamp;
        if (timeSinceLastUpdate > heartbeat)
            revert UniversalOracle__StalePrice(
                address(asset),
                timeSinceLastUpdate,
                heartbeat
            );
    }
}