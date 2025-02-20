// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {ERC20} from "./lib_openzeppelin-contracts_contracts_token_ERC20_ERC20.sol";
import {Ownable} from "./lib_openzeppelin-contracts_contracts_access_Ownable.sol";

abstract contract ERC20Yield is ERC20, Ownable {
    event BalanceAdjusted(address indexed account, uint256 newBalance);
    event DefaultYieldParamsUpdated(int256 newRate, uint256 newInterval);
    event TokensBurned(address indexed account, uint256 amount);
    event YieldParamsBatchReset(address[] accounts);
    event YieldParamsBatchUpdated(address[] accounts, int256[] rates, uint256[] intervals);
    event YieldParamsCleared(address indexed account);
    event YieldParamsReset(address indexed account);
    event YieldParamsUpdated(address indexed account, int256 newRate, uint256 newInterval);

    struct YieldParams {
        uint256 interval;
        int256 rate;
    }

    mapping(address => uint256) private _lastUpdated;
    mapping(address => YieldParams) private _yieldParams;
    int256 private _defaultYieldRate;
    int256 private constant MAX_YIELD_RATE = 1.0 * 1e18; // 100% per interval
    int256 private constant MIN_YIELD_RATE = -1.0 * 1e18; // -100% per interval
    uint256 private _defaultYieldInterval;
    uint256 private constant MAX_YIELD_INTERVAL = 31_536_000; // 1 year
    uint256 private constant MIN_YIELD_INTERVAL = 3600; // 1 hour

    constructor(uint256 defaultYieldInterval_, int256 defaultYieldRate_) {
        _defaultYieldInterval = defaultYieldInterval_;
        _defaultYieldRate = defaultYieldRate_;
    }

    function clearYieldParams(address account) public onlyOwner {
        require(account != address(0), "Invalid account address");

        _adjustBalance(account);
        delete _yieldParams[account];

        emit YieldParamsCleared(account);
    }

    function getYieldParams(address account) public view returns (int256 rate, uint256 interval) {
        YieldParams memory params = _getEffectiveYieldParams(account);
        return (params.rate, params.interval);
    }

    function getYieldParams() public view returns (int256 rate, uint256 interval) {
        return (_defaultYieldRate, _defaultYieldInterval);
    }

    function resetYieldParams(address account) public onlyOwner {
        require(account != address(0), "Invalid account address");

        delete _yieldParams[account];

        emit YieldParamsReset(account);
    }

    function resetYieldParamsBatch(address[] memory accounts) public onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            _resetYieldParams(accounts[i]);
        }

        emit YieldParamsBatchReset(accounts);
    }

    function setDefaultYieldParams(int256 rate, uint256 interval) public onlyOwner {
        require(rate > MIN_YIELD_RATE, "Yield rate below minimum allowed");
        require(rate <= MAX_YIELD_RATE, "Yield rate exceeds maximum allowed");
        require(interval >= MIN_YIELD_INTERVAL, "Yield interval is too small");
        require(interval <= MAX_YIELD_INTERVAL, "Yield interval exceeds maximum allowed");

        _defaultYieldInterval = interval;
        _defaultYieldRate = rate;

        emit DefaultYieldParamsUpdated(rate, interval);
    }

    function setYieldParams(int256 rate, uint256 interval, address account) public onlyOwner {
        _setYieldParams(rate, interval, account);
    }

    function setYieldParamsBatch(int256[] memory rates, uint256[] memory intervals, address[] memory accounts)
        public
        onlyOwner
    {
        require(rates.length == intervals.length && intervals.length == accounts.length, "Array length mismatch");

        for (uint256 i = 0; i < accounts.length; i++) {
            _setYieldParams(rates[i], intervals[i], accounts[i]);
        }

        emit YieldParamsBatchUpdated(accounts, rates, intervals);
    }

    function _adjustBalance(address account) internal {
        _lastUpdated[account] = block.timestamp;
        uint256 currentBalance = super.balanceOf(account);
        uint256 newBalance = _calculateBalance(account, currentBalance);

        if (newBalance == currentBalance) return;

        if (newBalance > currentBalance) {
            uint256 mintAmount = newBalance - currentBalance;
            _mint(account, mintAmount);
        } else {
            uint256 burnAmount = currentBalance - newBalance;
            _burn(account, burnAmount);
        }

        emit BalanceAdjusted(account, newBalance);
    }

    function _calculateBalance(address account, uint256 baseBalance) internal view returns (uint256) {
        uint256 lastUpdated = _lastUpdated[account];
        YieldParams memory params = _getEffectiveYieldParams(account);
        uint256 intervalsPassed = (block.timestamp - lastUpdated) / params.interval;

        if (intervalsPassed == 0) {
            return baseBalance;
        }

        int256 updatedBalance = int256(baseBalance);
        for (uint256 i = 0; i < intervalsPassed; i++) {
            updatedBalance += (updatedBalance * params.rate) / 1e18;
        }

        return updatedBalance < 0 ? 0 : uint256(updatedBalance);
    }

    function _getEffectiveYieldParams(address account) internal view returns (YieldParams memory) {
        if (_yieldParams[account].interval > 0) {
            return _yieldParams[account];
        }
        return YieldParams(_defaultYieldInterval, _defaultYieldRate);
    }

    function _resetYieldParams(address account) internal {
        require(account != address(0), "Invalid account address");

        delete _yieldParams[account];

        emit YieldParamsReset(account);
    }

    function _setYieldParams(int256 rate, uint256 interval, address account) internal {
        require(account != address(0), "Invalid account address");
        require(interval >= MIN_YIELD_INTERVAL, "Yield interval is too small");
        require(interval <= MAX_YIELD_INTERVAL, "Yield interval exceeds maximum allowed");
        require(rate > 0, "Yield rate must be positive");
        require(rate > MIN_YIELD_RATE, "Yield rate below minimum allowed");
        require(rate <= MAX_YIELD_RATE, "Yield rate exceeds maximum allowed");

        _adjustBalance(account);
        _yieldParams[account].interval = interval;
        _yieldParams[account].rate = rate;

        emit YieldParamsUpdated(account, rate, interval);
    }

    function _update(address from, address to, uint256 value) internal virtual override {
        if (from != address(0)) {
            _adjustBalance(from);
        }

        if (to != address(0)) {
            _adjustBalance(to);
        }

        super._update(from, to, value);
    }
}