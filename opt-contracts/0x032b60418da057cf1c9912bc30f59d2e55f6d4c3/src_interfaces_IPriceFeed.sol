// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./src_dependencies_PythStructs.sol";

/*
 * @dev from https://github.com/smartcontractkit/chainlink/blob/develop/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol
 */
interface ChainlinkAggregatorV3Interface {
    function decimals() external view returns (uint8);
    function latestRoundData() external view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

interface ISystemOracle {
    function getMarkPxs() external view returns (uint[] memory);
    function getOraclePxs() external view returns (uint[] memory);
    function getSpotPxs() external view returns (uint[] memory);
}

interface IPythEvents {
    event PriceFeedUpdate(bytes32 indexed id, uint64 publishTime, int64 price, uint64 conf);
    event BatchPriceFeedUpdate(uint16 chainId, uint64 sequenceNumber);
}

interface IPyth is IPythEvents {
    function getValidTimePeriod() external view returns (uint validTimePeriod);
    function getPrice(bytes32 id) external view returns (PythStructs.Price memory price);
    function getEmaPrice(bytes32 id) external view returns (PythStructs.Price memory price);
    function getPriceUnsafe(bytes32 id) external view returns (PythStructs.Price memory price);
    function getPriceNoOlderThan(bytes32 id, uint age) external view returns (PythStructs.Price memory price);
    function getEmaPriceUnsafe(bytes32 id) external view returns (PythStructs.Price memory price);
    function getEmaPriceNoOlderThan(bytes32 id, uint age) external view returns (PythStructs.Price memory price);
    function updatePriceFeeds(bytes[] calldata updateData) external payable;
    function updatePriceFeedsIfNecessary(bytes[] calldata updateData, bytes32[] calldata priceIds, uint64[] calldata publishTimes) external payable;
    function getUpdateFee(bytes[] calldata updateData) external view returns (uint feeAmount);
    function parsePriceFeedUpdates(bytes[] calldata updateData, bytes32[] calldata priceIds, uint64 minPublishTime, uint64 maxPublishTime) external payable returns (PythStructs.PriceFeed[] memory priceFeeds);
}

interface IPriceFeed {
    // Enums ---------------------------------------------------------------------------------------------------------
    enum OracleType { CHAINLINK, SYSTEM, PYTH }

    // Structs -------------------------------------------------------------------------------------------------------
    struct OracleRecordV2 {
        address oracleAddress;     // All oracles
        uint256 timeoutSeconds;    // All oracles
        uint8 decimals;           // Chainlink
        bool isEthIndexed;        // All oracles
        OracleType oracleType;    // All oracles
        uint8 szDecimals;         // SystemOracle
        uint256 priceIndex;       // SystemOracle
        bytes32 pythPriceId;      // Pyth specific
    }

    // Custom Errors ------------------------------------------------------------------------------------------------
    error PriceFeed__ExistingOracleRequired();
    error PriceFeed__InvalidDecimalsError();
    error PriceFeed__InvalidOracleResponseError(address token);
    error PriceFeed__TimelockOnlyError();
    error PriceFeed__UnknownAssetError();
    error PriceFeed__InvalidPythPrice();
    error PriceFeed__PythPriceStale();

    // Events ------------------------------------------------------------------------------------------------------
    event ChainlinkOracleSet(address indexed token, address indexed oracle, uint256 timeout, bool isEthIndexed);
    event SystemOracleSet(address indexed token, address indexed oracle, uint256 priceIndex, uint8 szDecimals);
    event PythOracleSet(address indexed token, address indexed oracle, bytes32 indexed priceId, uint256 timeout, bool isEthIndexed);

    // Functions ---------------------------------------------------------------------------------------------------
    /// @notice Fetches price for any token regardless of oracle type
    /// @param _token Address of the token to fetch price for
    /// @return Price in 1e18 (WAD) format
    function fetchPrice(address _token) external view returns (uint256);

    /// @notice Sets a Chainlink oracle for a token
    /// @param _token Token address
    /// @param _chainlinkOracle Chainlink oracle address
    /// @param _timeoutSeconds Maximum age of the price feed
    /// @param _isEthIndexed Whether the price should be multiplied by ETH price
    function setChainlinkOracle(
        address _token,
        address _chainlinkOracle,
        uint256 _timeoutSeconds,
        bool _isEthIndexed
    ) external;

    /// @notice Sets a SystemOracle for a token
    /// @param _token Token address
    /// @param _systemOracle SystemOracle address
    /// @param _priceIndex Index in the price array for this token
    /// @param _szDecimals Token decimals for price scaling
    function setSystemOracle(
        address _token,
        address _systemOracle,
        uint256 _priceIndex,
        uint8 _szDecimals
    ) external;

    function setPythOracle(
        address _token,
        address _pythOracle,
        bytes32 _priceId,
        uint256 _timeoutSeconds,
        bool _isEthIndexed
    ) external;
}