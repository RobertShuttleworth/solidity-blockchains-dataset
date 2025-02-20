// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface I_Fish_Staking_Slave {
    // Struct Definitions
    struct UserInfo {
        uint256 totalPower;
        uint256 rewardDebt;
    }

    struct PoolInfo {
        uint256 lastRewardBlock;
        uint256 poolTotalPower;
        uint256 accERC20PerShare;
        uint256 numberOfBlocksEmpty;
        uint256 zeroSinceBlock;
    }

    // Events
    event UpdatePoolEvent(uint8 _poolIndex, PoolInfo _poolInfo);
    event DepositEvent(address indexed _user, uint8 indexed _poolIndex, uint256 _power);
    event ClaimEvent(
        address indexed _user,
        uint8 indexed _poolIndex,
        uint256 _amountClaimed,
        uint256 _totalClaimed
    );
    event WithdrawEvent(address indexed _user, uint8 indexed _poolIndex, uint256 _power);

    // View Functions
    function deposited(address _user) external view returns (uint256);

    function getPendingRewards(address _user, uint256 _userTotalPower)
        external
        view
        returns (uint256, uint8);

    // External Functions
    function initialisePool(uint256 _poolTotalPower) external;

    function completeContractAndGetPoolTotalPower() external returns (uint256);

    function deposit(
        address _addr,
        uint256 _userTotalPower,
        uint256 _power
    ) external returns (uint256);

    function claim(address _addr, uint256 _userTotalPower) external returns (uint256);

    function withdraw(
        address _addr,
        uint256 _userTotalPower,
        uint256 _power
    ) external returns (uint256);

    function postWithdrawAdmin() external;
}