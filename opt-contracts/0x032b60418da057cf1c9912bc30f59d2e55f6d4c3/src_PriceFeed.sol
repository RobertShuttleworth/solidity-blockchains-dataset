// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./src_interfaces_IPriceFeed.sol";
import "./src_dependencies_Ownable.sol";
import "./src_AddressBook.sol";

/**
 * @title PriceFeed contract supporting Chainlink, System and Pyth oracles
 */
contract PriceFeed is IPriceFeed, Ownable {
    /// @dev Used to convert all oracle price answers to 18-digit precision uint
    uint256 public constant TARGET_DIGITS = 18;
    uint256 public constant SPOT_CONVERSION_BASE = 8; // For spot prices: 10^(8-szDecimals)
    uint256 public constant PERP_CONVERSION_BASE = 6; // For spot prices: 10^(6-szDecimals)
    uint256 public constant SYSTEM_TO_WAD = 1e18;    // To convert to 1e18 notation

    // State variables
    mapping(address => OracleRecordV2) public oracles;
    mapping(address => uint256) public lastCorrectPrice;

    // Functions ---------------------------------------------------------------------------------------------------
    
    /// @notice Fetches price for any token regardless of oracle type
    /// @param _token Address of the token to fetch price for
    /// @return Price in 1e18 (WAD) format
    function fetchPrice(address _token) public view virtual override returns (uint256) {
        OracleRecordV2 memory oracle = oracles[_token];
        uint256 price = _fetchOracleScaledPrice(oracle);

        if (price != 0) {
            // If the price is ETH indexed, multiply by ETH price
            return oracle.isEthIndexed ? _calcEthIndexedPrice(price) : price;
        }

        revert PriceFeed__InvalidOracleResponseError(_token);
    }

    /// @notice Sets a Chainlink oracle for a token
    function setChainlinkOracle(
        address _token,
        address _chainlinkOracle,
        uint256 _timeoutSeconds,
        bool _isEthIndexed
    ) external onlyOwner {
        uint8 decimals = _fetchDecimals(_chainlinkOracle);
        if (decimals == 0) {
            revert PriceFeed__InvalidDecimalsError();
        }

        OracleRecordV2 memory newOracle = OracleRecordV2({
            oracleAddress: _chainlinkOracle,
            timeoutSeconds: _timeoutSeconds,
            decimals: decimals,
            isEthIndexed: _isEthIndexed,
            oracleType: OracleType.CHAINLINK,
            szDecimals: 0,
            priceIndex: 0,
            pythPriceId: bytes32(0)
        });

        uint256 price = _fetchOracleScaledPrice(newOracle);
        if (price == 0) {
            revert PriceFeed__InvalidOracleResponseError(_token);
        }

        oracles[_token] = newOracle;
        emit ChainlinkOracleSet(_token, _chainlinkOracle, _timeoutSeconds, _isEthIndexed);
    }

    /// @notice Sets a SystemOracle for a token
    function setSystemOracle(
        address _token,
        address _systemOracle,
        uint256 _priceIndex,
        uint8 _szDecimals
    ) external onlyOwner {
        OracleRecordV2 memory newOracle = OracleRecordV2({
            oracleAddress: _systemOracle,
            timeoutSeconds: 3600,
            decimals: 0,
            isEthIndexed: false,
            oracleType: OracleType.SYSTEM,
            szDecimals: _szDecimals,
            priceIndex: _priceIndex,
            pythPriceId: bytes32(0)
        });

        uint256 price = _fetchOracleScaledPrice(newOracle);
        if (price == 0) {
            revert PriceFeed__InvalidOracleResponseError(_token);
        }

        oracles[_token] = newOracle;
        emit SystemOracleSet(_token, _systemOracle, _priceIndex, _szDecimals);
    }

    /// @notice Sets a Pyth oracle for a token
    function setPythOracle(
        address _token,
        address _pythOracle,
        bytes32 _priceId,
        uint256 _timeoutSeconds,
        bool _isEthIndexed
    ) external onlyOwner {
        require(_pythOracle != address(0), "Invalid Pyth oracle address");
        require(_priceId != bytes32(0), "Invalid price ID");
        require(_timeoutSeconds > 0, "Invalid timeout");

        OracleRecordV2 memory newOracle = OracleRecordV2({
            oracleAddress: _pythOracle,
            timeoutSeconds: _timeoutSeconds,
            decimals: 0,
            isEthIndexed: _isEthIndexed,
            oracleType: OracleType.PYTH,
            szDecimals: 0,
            priceIndex: 0,
            pythPriceId: _priceId
        });

        uint256 price = _fetchOracleScaledPrice(newOracle);
        if (price == 0) {
            revert PriceFeed__InvalidOracleResponseError(_token);
        }

        oracles[_token] = newOracle;
        emit PythOracleSet(_token, _pythOracle, _priceId, _timeoutSeconds, _isEthIndexed);
    }

    // Internal functions ------------------------------------------------------------------------------------------

    function _fetchOracleScaledPrice(OracleRecordV2 memory oracle) internal view returns (uint256) {
        if (oracle.oracleAddress == address(0)) {
            revert PriceFeed__UnknownAssetError();
        }

        uint256 oraclePrice;
        uint256 priceTimestamp;

        if (oracle.oracleType == OracleType.CHAINLINK) {
            (oraclePrice, priceTimestamp) = _fetchChainlinkOracleResponse(oracle.oracleAddress);
            if (oraclePrice != 0 && !_isStalePrice(priceTimestamp, oracle.timeoutSeconds)) {
                return _scalePriceByDigits(oraclePrice, oracle.decimals);
            }
        } else if (oracle.oracleType == OracleType.SYSTEM) {
            (oraclePrice, priceTimestamp) = _fetchSystemOracleResponse(
                oracle.oracleAddress,
                oracle.priceIndex,
                oracle.szDecimals
            );
            if (oraclePrice != 0 && !_isStalePrice(priceTimestamp, oracle.timeoutSeconds)) {
                return oraclePrice;
            }
        } else if (oracle.oracleType == OracleType.PYTH) {
            (oraclePrice, priceTimestamp) = _fetchPythOracleResponse(
                oracle.oracleAddress,
                oracle.pythPriceId,
                oracle.timeoutSeconds
            );
            if (oraclePrice != 0) {
                return oraclePrice;
            }
        }

        return 0;
    }

    function _fetchPythOracleResponse(
        address _oracleAddress,
        bytes32 _priceId,
        uint256 _timeoutSeconds
    ) internal view returns (uint256 price, uint256 timestamp) {
        try IPyth(_oracleAddress).getPriceNoOlderThan(_priceId, _timeoutSeconds) returns (PythStructs.Price memory pythPrice) {
            if (pythPrice.publishTime == 0 || pythPrice.price <= 0) {
                revert PriceFeed__InvalidPythPrice();
            }

            // Convert price to positive uint256
            int256 priceInt = pythPrice.price;
            if (priceInt < 0) {
                revert PriceFeed__InvalidPythPrice();
            }
            
            // Simply convert the price without any additional scaling
            price = uint256(priceInt);
            timestamp = pythPrice.publishTime;
        } catch {
            revert PriceFeed__InvalidPythPrice();
        }
    }

    function _fetchChainlinkOracleResponse(
        address _oracleAddress
    ) internal view returns (uint256 price, uint256 timestamp) {
        try ChainlinkAggregatorV3Interface(_oracleAddress).latestRoundData() returns (
            uint80 roundId,
            int256 answer,
            uint256,
            uint256 updatedAt,
            uint80
        ) {
            if (roundId != 0 && updatedAt != 0 && answer > 0) {
                price = uint256(answer);
                timestamp = updatedAt;
            }
        } catch {
            // If call to Chainlink aggregator reverts, return a zero response
        }
    }

    function _fetchSystemOracleResponse(
        address _oracleAddress,
        uint256 _priceIndex,
        uint8 _szDecimals
    ) internal view returns (uint256 price, uint256 timestamp) {
        uint[] memory prices = ISystemOracle(_oracleAddress).getSpotPxs();
        
        if (_priceIndex < prices.length && prices[_priceIndex] != 0) {
            uint256 divisor = 10 ** (SPOT_CONVERSION_BASE - _szDecimals);
            price = (prices[_priceIndex] * SYSTEM_TO_WAD) / divisor;
            timestamp = block.timestamp;
        }
    }

    function _isStalePrice(uint256 _priceTimestamp, uint256 _oracleTimeoutSeconds) internal view returns (bool) {
        return block.timestamp - _priceTimestamp > _oracleTimeoutSeconds;
    }

    function _calcEthIndexedPrice(uint256 _ethAmount) internal view returns (uint256) {
        uint256 ethPrice = fetchPrice(address(0));
        return (ethPrice * _ethAmount) / 1e18;
    }

    function _scalePriceByDigits(uint256 _price, uint256 _priceDigits) internal pure returns (uint256) {
        unchecked {
            if (_priceDigits > TARGET_DIGITS) {
                return _price / (10 ** (_priceDigits - TARGET_DIGITS));
            } else if (_priceDigits < TARGET_DIGITS) {
                return _price * (10 ** (TARGET_DIGITS - _priceDigits));
            }
        }
        return _price;
    }

    function _fetchDecimals(address _oracle) internal view returns (uint8) {
        return ChainlinkAggregatorV3Interface(_oracle).decimals();
    }
}