// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./openzeppelin_contracts_access_AccessControl.sol";
import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./openzeppelin_contracts_utils_ReentrancyGuard.sol";
import "./contracts_Treasury_interfaces_IDragonTreasuryFinance.sol";
import "./contracts_Treasury_interfaces_IDragonTreasuryCore.sol";

interface IChainlinkAggregator {
    function latestRoundData() external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    );
}

contract DragonTreasuryFinance is IDragonTreasuryFinance, AccessControl, ReentrancyGuard {
    bytes32 public constant CORE_ROLE = keccak256("CORE_ROLE");
    
    IDragonTreasuryCore public immutable treasuryCore;
    uint256[] private _flowTimestamps;
    
    mapping(uint256 => CashFlowData) private monthlyCashFlows;
    uint256 private constant PRICE_PRECISION = 8;
    address private constant MATIC_USD_FEED = 0xAB594600376Ec9fD91F8e885dADF0CE036862dE0;

    constructor(address _treasuryCore) {
        require(_treasuryCore != address(0), "DragonTreasuryFinance: invalid treasury core address");
        treasuryCore = IDragonTreasuryCore(_treasuryCore);
        _grantRole(DEFAULT_ADMIN_ROLE, _treasuryCore);
        _grantRole(CORE_ROLE, _treasuryCore);
    }

    modifier onlyCore() {
        require(hasRole(CORE_ROLE, msg.sender), "DragonTreasuryFinance: caller does not have CORE_ROLE");
        _;
    }

    function updateCashFlow(
        address _token,
        uint256 _amount,
        bool _isInflow
    ) external override onlyCore nonReentrant {
        uint256 currentMonth = (block.timestamp / 30 days) * 30 days;
        if (_flowTimestamps.length == 0 || _flowTimestamps[_flowTimestamps.length - 1] < currentMonth) {
            _flowTimestamps.push(currentMonth);
        }

        CashFlowData storage flow = monthlyCashFlows[currentMonth];
        flow.timestamp = currentMonth;
        uint256 valueUSD = getTokenValueUSD(_token, _amount);

        if (_isInflow) {
            flow.inflow += valueUSD;
            flow.tokenInflows[_token] += _amount;
        } else {
            flow.outflow += valueUSD;
            flow.tokenOutflows[_token] += _amount;
        }

        emit CashFlowUpdated(
            currentMonth,
            flow.inflow,
            flow.outflow,
            _token,
            _isInflow
        );
    }

    function getTokenPriceUSD(address _token) public view override returns (uint256) {
        if (_token == address(0)) {
            (,int256 price,,,) = IChainlinkAggregator(MATIC_USD_FEED).latestRoundData();
            require(price > 0, "DragonTreasuryFinance: invalid MATIC price");
            return uint256(price);
        }

        IDragonTreasuryCore.TokenInfo memory tokenInfo = treasuryCore.getToken(_token);
        require(tokenInfo.priceFeed != address(0), "DragonTreasuryFinance: no price feed");
        
        (,int256 price,,,) = IChainlinkAggregator(tokenInfo.priceFeed).latestRoundData();
        require(price > 0, "DragonTreasuryFinance: invalid price");
        return uint256(price);
    }

    function getTokenValueUSD(address _token, uint256 _amount) public view override returns (uint256) {
        if (_amount == 0) return 0;
        uint256 price = getTokenPriceUSD(_token);
        uint8 decimals = _token == address(0) ? 18 : treasuryCore.getToken(_token).decimals;
        return (_amount * price) / (10 ** (decimals - PRICE_PRECISION));
    }

    function getTotalTreasuryValueUSD() public view override returns (uint256) {
        uint256 total = 0;
        address[] memory tokens = treasuryCore.getTrackedTokens();
        
        total += getTokenValueUSD(address(0), address(treasuryCore).balance);
        
        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 balance = IERC20(tokens[i]).balanceOf(address(treasuryCore));
            total += getTokenValueUSD(tokens[i], balance);
        }
        
        return total;
    }

    function getMonthlyBurn() public view override returns (uint256) {
        if (_flowTimestamps.length == 0) return 0;
        uint256 latestMonth = _flowTimestamps[_flowTimestamps.length - 1];
        CashFlowData storage flow = monthlyCashFlows[latestMonth];
        return flow.outflow;
    }

    function calculateRunway() public view override returns (uint256) {
        uint256 totalValueUSD = getTotalTreasuryValueUSD();
        uint256 monthlyBurn = getMonthlyBurn();
        
        if (monthlyBurn == 0) return type(uint256).max;
        
        return totalValueUSD / monthlyBurn;
    }

    function calculateAndEmitRunway() external returns (uint256) {
        uint256 runway = calculateRunway();
        emit RunwayCalculated(runway, getTotalTreasuryValueUSD(), getMonthlyBurn());
        return runway;
    }

    function getCashFlowHistory(uint256 _months) external view override returns (
        uint256[] memory timestamps,
        uint256[] memory inflows,
        uint256[] memory outflows
    ) {
        uint256 count = _months > _flowTimestamps.length ? _flowTimestamps.length : _months;
        
        timestamps = new uint256[](count);
        inflows = new uint256[](count);
        outflows = new uint256[](count);
        
        for (uint256 i = 0; i < count; i++) {
            uint256 timestamp = _flowTimestamps[_flowTimestamps.length - 1 - i];
            CashFlowData storage flow = monthlyCashFlows[timestamp];
            timestamps[i] = timestamp;
            inflows[i] = flow.inflow;
            outflows[i] = flow.outflow;
        }
        
        return (timestamps, inflows, outflows);
    }

    function monthlyFlows(uint256 timestamp) external view override returns (
        uint256 inflow,
        uint256 outflow,
        uint256 timestamp_
    ) {
        CashFlowData storage flow = monthlyCashFlows[timestamp];
        return (flow.inflow, flow.outflow, flow.timestamp);
    }

    function flowTimestamps(uint256 index) external view override returns (uint256) {
        require(index < _flowTimestamps.length, "Index out of bounds");
        return _flowTimestamps[index];
    }

    function getFlowTimestampsLength() external view override returns (uint256) {
        return _flowTimestamps.length;
    }
}