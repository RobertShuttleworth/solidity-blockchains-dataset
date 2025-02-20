// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./openzeppelin_contracts_token_ERC20_ERC20.sol";
import "./openzeppelin_contracts_security_ReentrancyGuard.sol";
import "./openzeppelin_contracts_access_Ownable.sol";

contract Polydanara is ERC20, ReentrancyGuard, Ownable {
    uint256 public stakingAPY = 5; // 5% APY
    uint256 public constant MIN_STAKE_DURATION = 1 days; // durasi minimum
    uint256 public constant MAX_SUPPLY = 100000 * 10**18; // suplai maksimum token

    struct StakeInfo {
        uint256 amount;
        uint256 timestamp;
        bool isStaked;
    }

    mapping(address => StakeInfo) public stakes;

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount, uint256 reward);

    constructor() ERC20("Polydanara", "POL") Ownable() {
        _mint(msg.sender, MAX_SUPPLY); // Mint semua token ke pemilik awal
    }

    function stake(uint256 amount) external nonReentrant {
        require(amount > 0, "Tidak bisa staking 0 token");
        require(balanceOf(msg.sender) >= amount, "Saldo tidak mencukupi");
        require(!stakes[msg.sender].isStaked, "Sudah staking");

        _transfer(msg.sender, address(this), amount);

        stakes[msg.sender] = StakeInfo({
            amount: amount,
            timestamp: block.timestamp,
            isStaked: true
        });

        emit Staked(msg.sender, amount);
    }

    function unstake() external nonReentrant {
        StakeInfo storage userStake = stakes[msg.sender];
        require(userStake.isStaked, "Tidak ada staking aktif");
        require(block.timestamp >= userStake.timestamp + MIN_STAKE_DURATION, "Durasi staking belum selesai");

        uint256 reward = calculateReward(msg.sender);
        uint256 totalAmount = userStake.amount + reward;

        require(balanceOf(address(this)) >= totalAmount, "Dana kontrak tidak mencukupi");

        userStake.isStaked = false;
        _transfer(address(this), msg.sender, totalAmount);

        emit Unstaked(msg.sender, userStake.amount, reward);
    }

    function calculateReward(address user) public view returns (uint256) {
        StakeInfo storage userStake = stakes[user];
        if (!userStake.isStaked) return 0;

        uint256 stakingDuration = block.timestamp - userStake.timestamp;
        uint256 yearlyReward = (userStake.amount * stakingAPY) / 100;
        uint256 reward = (yearlyReward * stakingDuration) / 365 days;

        return reward;
    }
}