// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import './openzeppelin_contracts_token_ERC20_IERC20.sol';
import './openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol';
import './openzeppelin_contracts_access_Ownable.sol';
import './openzeppelin_contracts_security_ReentrancyGuard.sol';

contract DonationPool is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable USDT;
    IERC20 public immutable USDC;

    uint256 public startTime;
    uint256 public endTime;

    struct UserDonationStats {
        uint256 totalUSDT;
        uint256 totalUSDC;
        uint256 lastDonationTime;
    }

    mapping(address => UserDonationStats) private _userStats;

    uint256 public totalUSDT;
    uint256 public totalUSDC;

    event DonationReceived(address indexed donor, uint256 amount, bool isUSDT, uint256 timestamp);
    event TimeSet(uint256 startTime, uint256 endTime);
    event TokensWithdrawn(address indexed token, uint256 amount);

    constructor(address _usdt, address _usdc, uint256 _startTime, uint256 _endTime) {
        require(_usdt != address(0) && _usdc != address(0), 'Invalid token address');
        require(_startTime < _endTime, 'Invalid time range');
        require(_endTime > block.timestamp, 'End time must be in future');
        USDT = IERC20(_usdt);
        USDC = IERC20(_usdc);

        startTime = _startTime;
        endTime = _endTime;
    }

    function setTime(uint256 _startTime, uint256 _endTime) external onlyOwner {
        require(_startTime < _endTime, 'Invalid time range');
        require(_endTime > block.timestamp, 'End time must be in future');
        startTime = _startTime;
        endTime = _endTime;
        emit TimeSet(_startTime, _endTime);
    }

    function donateUSDT(uint256 amount) external nonReentrant {
        _donate(amount, true);
    }

    function donateUSDC(uint256 amount) external nonReentrant {
        _donate(amount, false);
    }

    function _donate(uint256 amount, bool isUSDT) internal {
        require(block.timestamp >= startTime, 'Donation not started');
        require(block.timestamp <= endTime, 'Donation ended');
        require(amount > 0, 'Amount must be greater than 0');

        if (isUSDT) {
            USDT.safeTransferFrom(msg.sender, address(this), amount);
            totalUSDT += amount;
            _userStats[msg.sender].totalUSDT += amount;
        } else {
            USDC.safeTransferFrom(msg.sender, address(this), amount);
            totalUSDC += amount;
            _userStats[msg.sender].totalUSDC += amount;
        }

        _userStats[msg.sender].lastDonationTime = block.timestamp;

        emit DonationReceived(msg.sender, amount, isUSDT, block.timestamp);
    }

    function withdraw(address token) external onlyOwner nonReentrant {
        require(block.timestamp > endTime, 'Donation period not ended');
        uint256 amount = IERC20(token).balanceOf(address(this));
        require(amount > 0, 'No token to withdraw');
        IERC20(token).safeTransfer(owner(), amount);
        emit TokensWithdrawn(token, amount);
    }

    function getUserStats(address user) external view returns (UserDonationStats memory) {
        return _userStats[user];
    }
}