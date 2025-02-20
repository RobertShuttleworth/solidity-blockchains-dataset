// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./hardhat_console.sol";

import "./openzeppelin_contracts_utils_structs_EnumerableSet.sol";
import "./openzeppelin_contracts_access_AccessControl.sol";
import "./openzeppelin_contracts_utils_Pausable.sol";

import "./contracts_interface_2.i_Fish_CERTNFT.sol";
import "./contracts_interface_3.i_Fish_RewardERC20.sol";
import "./contracts_interface_6.i_Fish_Staking_Slave.sol";


contract Fish_Staking_Slave is I_Fish_Staking_Slave, AccessControl, Pausable {

    bytes32 public constant POOL_MASTER_ROLE = keccak256("POOL_MASTER_ROLE");


    I_Fish_RewardERC20 public erc20;
    uint256 public paidOut = 0;
    
    
    uint8 public poolIndex;
    bool public poolInitialised;
    bool public poolCompleted;
    uint256 public rewardPerBlock;
    uint256 public startBlock;
    uint256 public endBlock;
    PoolInfo public poolInfo;

    
    mapping(address => UserInfo) public userInfo;


    // event UpdatePoolEvent(uint8 _poolIndex, PoolInfo _poolInfo);
    // event DepositEvent           ( address indexed _user, uint8 indexed _poolIndex, uint256 _power );
    // event ClaimEvent             ( address indexed _user, uint8 indexed _poolIndex, uint256 _amountClaimed, uint256 _totalClaimed );
    // event WithdrawEvent          ( address indexed _user, uint8 indexed _poolIndex, uint256 _power );
    // // event EmergencyWithdraw ( address indexed _user, uint8 indexed _poolNumber, uint256 _power );


    constructor(
        I_Fish_RewardERC20  _erc20,
        uint256 _rewardPerBlock,
        uint256 _startBlock,
        uint256 _endBlock,
        address _admin,
        uint8 _poolIndex
    ) Pausable() AccessControl() {
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _setRoleAdmin(POOL_MASTER_ROLE, DEFAULT_ADMIN_ROLE);

        _grantRole(POOL_MASTER_ROLE, msg.sender);


        erc20 = _erc20;
        rewardPerBlock = _rewardPerBlock;
        startBlock = _startBlock;
        endBlock = _endBlock;

        poolIndex = _poolIndex;
    }


    // intraContract Spec
    function initialisePool(uint256 _poolTotalPower) external onlyRole(POOL_MASTER_ROLE) {
        require(poolInitialised == false, "pool already initialised");
        poolInfo.poolTotalPower = _poolTotalPower;
        poolInitialised = true;
    }
    function completeContractAndGetPoolTotalPower () external onlyRole(POOL_MASTER_ROLE)  returns (uint256) {
        console.log("Pool: CompletePool: ", poolIndex);
        
        require(poolCompleted == false, "Pool already completed");
        poolCompleted = true;
        return poolInfo.poolTotalPower;
    }


    // function fund(uint256 _amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
    //     require(block.number < endBlock, "fund: too late, the farm is closed");

    //     erc20.transferFrom(address(msg.sender), address(this), _amount);
    //     endBlock = endBlock +  ( _amount / rewardPerBlock );
    // }


    function deposited( address _user) external view returns (uint256) {
        return userInfo[_user].totalPower;
    }


    // view functions for dApp
    function getPendingRewards(address _user, uint256 _userTotalPower) external view returns (uint256, uint8) {

        console.log("Fish_Staking_Slave: getPendingRewards: _user", _user);
        console.log("Fish_Staking_Slave: getPendingRewards: _userTotalPower", _userTotalPower);

        uint256 poolUserTotalPower = userInfo[_user].totalPower;
        if (poolUserTotalPower == 0 && _userTotalPower == 0) return (0, poolIndex);
       

        PoolInfo memory LOCAL_poolInfo = poolInfo;
        
        if (LOCAL_poolInfo.poolTotalPower == 0) {
            return (0, poolIndex);
        }

        uint256 accERC20PerShare = LOCAL_poolInfo.accERC20PerShare;

        if (block.number > LOCAL_poolInfo.lastRewardBlock) {
            uint256 lastBlock = block.number < endBlock ? block.number : endBlock;
            uint256 nrOfBlocks = lastBlock - LOCAL_poolInfo.lastRewardBlock;

            uint256 erc20Reward = nrOfBlocks * rewardPerBlock;
            accERC20PerShare += ((erc20Reward * 1e36 ) / LOCAL_poolInfo.poolTotalPower);
        }

        console.log("Fish_Staking_Slave: getPendingRewards: accERC20PerShare", accERC20PerShare);
        console.log("Fish_Staking_Slave: getPendingRewards: rewardDebt", userInfo[_user].rewardDebt);
        

        uint256 pendingRewards = (((poolUserTotalPower != 0 ? poolUserTotalPower : _userTotalPower) * accERC20PerShare) / 1e36) - (userInfo[_user].rewardDebt);

        console.log("Fish_Staking_Slave: getPendingRewards: pendingRewards", pendingRewards);
        console.log("Fish_Staking_Slave: getPendingRewards: poolIndex", poolIndex);

        return (pendingRewards, poolIndex);
    }


    function deposit( address _addr , uint256 _userTotalPower, uint256 _power ) external onlyRole(POOL_MASTER_ROLE) whenNotPaused returns (uint256){
        console.log("Pool: deposit: ", poolIndex);

        require(poolCompleted == false, "no deposits on completed pools");

        uint256 claimedRewards = iClaim(_addr, _userTotalPower, 0);

        userInfo[_addr].totalPower += _power;
        userInfo[_addr].rewardDebt = (userInfo[_addr].totalPower * poolInfo.accERC20PerShare) / 1e36;
        poolInfo.poolTotalPower += _power;
        
        emit DepositEvent(_addr, poolIndex, _power);

        return claimedRewards;
    }

    function claim( address _addr, uint256 _userTotalPower) public onlyRole(POOL_MASTER_ROLE) whenNotPaused returns (uint256) {
        console.log("Pool: claim: ", poolIndex);
        uint256 claimedRewards = iClaim(_addr ,_userTotalPower, 0);

        userInfo[_addr].rewardDebt = (userInfo[_addr].totalPower * poolInfo.accERC20PerShare) / 1e36;

        return claimedRewards;
    }

    function withdraw( address _addr , uint256 _userTotalPower, uint256 _power) external onlyRole(POOL_MASTER_ROLE)  whenNotPaused returns (uint256) {
        console.log("Pool: withdraw: ", poolIndex);

        require(poolCompleted == false, "no withdrawals on completed pools");
           
        uint256 claimedRewards = iClaim(_addr, _userTotalPower, _power);
        
        userInfo[_addr].totalPower -= _power;
        userInfo[_addr].rewardDebt = (userInfo[_addr].totalPower * poolInfo.accERC20PerShare) / 1e36;

        poolInfo.poolTotalPower -= _power;
        
        emit WithdrawEvent(_addr, poolIndex, _power );

        return claimedRewards;
    }


    // Internal Functions
    function iClaim( address _addr, uint256 _userTotalPower, uint256 _withdrawPower) internal whenNotPaused returns (uint256) {
        require(poolInitialised == true, "no actions allowed on poolInitialised == false");

        UserInfo memory LOCAL_user = userInfo[_addr];

        iUpdatePool();

        if (LOCAL_user.totalPower == 0 && _userTotalPower != 0) {
            userInfo[_addr].totalPower = _userTotalPower;
            LOCAL_user.totalPower = _userTotalPower;
        }
        if (_withdrawPower > 0) {
            require(LOCAL_user.totalPower >= _withdrawPower, "withdraw: can't withdraw more than deposit");
        }


        console.log("  iClaim: totalPower", LOCAL_user.totalPower);
        console.log("  iClaim: accpershare", poolInfo.accERC20PerShare);
        console.log("  iClaim: rewardDebt", LOCAL_user.rewardDebt);
        console.log("  iClaim: lastRewardBlock", poolInfo.lastRewardBlock);

        uint256 pendingAmount;
        if (LOCAL_user.totalPower > 0) {
            pendingAmount =  ((LOCAL_user.totalPower * poolInfo.accERC20PerShare) / 1e36) - LOCAL_user.rewardDebt;
            erc20Transfer(_addr, pendingAmount);
        }
        console.log("  iClaim: pendingAmount: ", pendingAmount / 1e18);
        console.log("  iClaim: balanceOfPool: ", erc20.balanceOf(address(this))  / 1e18);
        // userInfo[_addr].rewardDebt = (userInfo[_addr].totalPower * poolInfo.accERC20PerShare) / 1e36;
        // LOCAL_user.rewardDebt += pendingAmount;
        // userInfo[_addr].rewardDebt = LOCAL_user.rewardDebt;
        
        emit ClaimEvent(_addr, poolIndex, pendingAmount, LOCAL_user.rewardDebt);

        return pendingAmount;
    }

    function iUpdatePool() internal {
        require(block.number >= startBlock, "iUpdatePool: pool has not started");

        PoolInfo memory LOCAL_poolInfo = poolInfo;
        
        
        uint256 lastBlock = block.number < endBlock ? block.number : endBlock;


        // console.log("totalPower", userInfo.totalPower);
        console.log("  updatePool: poolTotalPower:", LOCAL_poolInfo.poolTotalPower);
        console.log("  updatePool: accpershare1: ", poolInfo.accERC20PerShare);
        // console.log("rewardDebt", userInfo.rewardDebt);
        console.log("  updatePool: currentBlock", block.number);
        console.log("  updatePool: lastBlock", lastBlock);
        console.log("  updatePool: lastRewardBlock", poolInfo.lastRewardBlock);


        if (LOCAL_poolInfo.lastRewardBlock ==0) {
            LOCAL_poolInfo.lastRewardBlock = startBlock;
        }

        if (lastBlock <= LOCAL_poolInfo.lastRewardBlock) {
            return;
        }
        if (LOCAL_poolInfo.poolTotalPower == 0) {
            // poolInfo.zeroSinceBlock = poolInfo.lastRewardBlock > 0 ? poolInfo.lastRewardBlock : startBlock;
            poolInfo.lastRewardBlock = lastBlock;
            // if (LOCAL_poolInfo.lastRewardBlock < startBlock) poolInfo.lastRewardBlock = block.number;
            // poolInfo.numberOfBlocksEmpty = block.number - poolInfo.zeroSinceBlock;
            return;
        }

        

        uint256 nrOfBlocks = lastBlock - LOCAL_poolInfo.lastRewardBlock;
        uint256 erc20Reward = ( ( nrOfBlocks * rewardPerBlock ) );

        LOCAL_poolInfo.accERC20PerShare += ( ( erc20Reward * 1e36 ) / LOCAL_poolInfo.poolTotalPower);
        poolInfo.accERC20PerShare = LOCAL_poolInfo.accERC20PerShare;
        poolInfo.lastRewardBlock = lastBlock;

        console.log("  updatePool: accpershare2: ", poolInfo.accERC20PerShare);

        emit UpdatePoolEvent(poolIndex, poolInfo);
    }


    // function emergencyWithdrawAdmin(address _addr , uint256 _power ) external onlyRole(POOL_MASTER_ROLE) {
    //     require(userInfo[_addr].totalPower >= _power, "emergencyWthdrawAdmin: can't withdraw more than deposit");

    //     emit EmergencyWithdraw(_addr, poolIndex, _power);
    //     userInfo[_addr].totalPower -= _power;
    //     // userInfo[_addr].rewardDebt = 0;

    //     poolInfo.poolTotalPower -= _power;
    // }

    function postWithdrawAdmin() external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(poolCompleted == true, "postWithdrawAdmin: pool must be completed");
        require(block.number > endBlock, "postWithdrawAdmin: pool must be past endBLock");

        uint256 totalPending = erc20.balanceOf(address(this));
        erc20.transfer(msg.sender, totalPending);
    }

    function erc20Transfer(address _to, uint256 _amount) internal {
        erc20.transfer(_to, _amount);
        paidOut += _amount;
    }
}
