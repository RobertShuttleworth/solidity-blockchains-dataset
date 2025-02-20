// @author Daosourced
// @date September 3, 2023
pragma solidity ^0.8.0;
import "./openzeppelin_contracts-upgradeable_utils_structs_EnumerableSetUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC20_IERC20Upgradeable.sol";
import "./openzeppelin_contracts-upgradeable_utils_ContextUpgradeable.sol";
import './openzeppelin_contracts-upgradeable_utils_introspection_IERC165Upgradeable.sol';

import {IRewardStakingManager} from './contracts_staking_IRewardStakingManager.sol';
import {StakingManager} from  './contracts_staking_StakingManager.sol';
import {IStakingManager} from  './contracts_staking_IStakingManager.sol';
import {IRewardsManager} from './contracts_rewards_IRewardsManager.sol';
import {IRewards} from './contracts_rewards_IRewards.sol';
import {RewardsPool} from './contracts_rewards_RewardsPool.sol';
import {Strings} from './contracts_utils_Strings.sol';
import {Distribution} from './contracts_utils_Distribution.sol';
import {Pausable} from './contracts_utils_Pausable.sol';
import {SpaceToken} from './contracts_token_SpaceToken.sol';
import {ProtocolAdminRole} from './contracts_roles_ProtocolAdminRole.sol';
import {IFees} from './contracts_deprecated_IFees.sol';
import {IFeeManager} from './contracts_fees_IFeeManager.sol';
import {TransferHelper} from './contracts_utils_TransferHelper.sol';

/**
 * @title HDNS staking reward staking contract
 * @notice contract that manages staking on different reward pools in the hdns ecosystem
*/
contract RewardStakingManager is StakingManager, Pausable, IRewardStakingManager {
  
  using Strings for string;
  using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
  using Distribution for uint256;
  using TransferHelper for address;

  /** @notice account => poolProxy  => stake */
  mapping(address => mapping(address => uint256)) private _ownerStakes;

  /** @notice account => set of pool addresses */
  mapping(address => EnumerableSetUpgradeable.AddressSet) _poolsStakedOn;

  /** @notice poolProxy => total staked on pool proxy */
  mapping(address => uint256) internal _totalStaked;

  /** @notice poolProxy => total staked on pool proxy */
  EnumerableSetUpgradeable.AddressSet internal _poolsWithStakes;

  IRewardsManager internal _rewardsManager;

  /** @notice poolProxy => stakeToken */
  mapping(address => address) internal _stakeTokens;

  IFeeManager internal _feeManagerV2;

  modifier onlyActivePool(address poolProxy) {
    require(_rewardsManager.getPool(poolProxy).active, 'HDNS RewardStakingManager: INACTIVE_POOL');
    _;
  }

  modifier onlyValidPool(address poolProxy) {
    require(IERC165Upgradeable(poolProxy).supportsInterface(type(IRewards).interfaceId), 'HDNS RewardStakingManager: INVALID_POOL');
    require(IRewards(poolProxy).supportsRewardStaking(), 'HDNS RewardStakingManager: POOL_DOES_NOT_SUPPORT_REWARD_STAKING');
    _;
  }

  modifier onlySufficientStakeBalance(address poolProxy, address account) {
    require(stakeBalanceOf(poolProxy, _msgSender()) > 0, 'HDNS RewardStakingManager: INSUFFICIENT_STAKING_BALANCE');
    _;
  } 

  modifier onlySufficientAccountBalance(address poolProxy, address account, uint256 amount) {
    require(stakeBalanceOf(poolProxy, _msgSender()) >= amount, 'HDNS RewardStakingManager: INSUFFICIENT_STAKING_BALANCE');
    _;
  } 

  function initialize(
    address tokenAddress,
    address rewardsManagerAddress,
    address feeManagerAddress
  ) public initializer {
    __Pausable_init();
    __StakingManager_init(tokenAddress, feeManagerAddress);
    __StakingManager_init_for_reward_staking(rewardsManagerAddress);
    _rewardsManager = IRewardsManager(rewardsManagerAddress);
  }

  function __RewardStakingManager_init() internal onlyInitializing {}

  function __RewardStakingManager_init_unchained() internal onlyInitializing {}

  function stakeBalanceOf(address poolProxy, address account) public view returns (uint256) {
    return _ownerStakes[account][poolProxy];
  }

  function hasAccountStaked(
    address poolProxy, 
    address account
  ) external view override returns (bool) { 
    return stakeBalanceOf(poolProxy, account) > 0;
  }

  function _totalStakeBalanceOf(address[] memory pools, address account) internal view returns (uint256){
    uint256 totalStaked;
    for(uint256 i = 0; i < pools.length; i++) {
      totalStaked += stakeBalanceOf(pools[i], account);
    }
    return totalStaked;
  }

  function stakedPools(address account) public view override returns (address[] memory) {
    return _stakedPools(account);
  }

  function _stakedPools(address account) internal view returns (address[] memory) {   
    return _poolsStakedOn[account].values();
  }

  function _stake(
    address poolProxy, 
    address account, 
    uint256 amount
  ) onlyValidPool(poolProxy) onlyActivePool(poolProxy) nonReentrant internal {
    require(_rewardsManager.getPool(poolProxy).active, 'HDNS RewardStakingManager: POOL_IS_INACTIVE');
    require(_rewardsManager.getPoolData(poolProxy).supportsRewardStaking && _hasStakeTokenSet(poolProxy), 'HDNS RewardStakingManager: POOL_DOES_NOT_SUPPORT_REWARD_STAKING');
    IRewards poolInstance = IRewards(poolProxy);
    uint256 newBalance = stakeBalanceOf(poolProxy, account) + amount;
    _ownerStakes[account][poolProxy] = newBalance;
    _totalStaked[poolProxy] += amount;
    _poolsStakedOn[account].add(poolProxy);
    
    if(!_poolsWithStakes.contains(poolProxy)){
      _poolsWithStakes.add(poolProxy);
    }
    poolInstance.createRewardStakeAccount(_msgSender());
    IERC20Upgradeable(stakeTokenFor(poolProxy)).transferFrom(account, address(this), amount);
    emit RewardStaked(poolProxy, account, amount, newBalance);
  }

  function totalStakedOnPool(address poolProxy) public view returns (uint256 totalTokensStakedOnPool) {
    totalTokensStakedOnPool = _totalStaked[poolProxy];
  }

  function stakeShareOf(
    address poolProxy, 
    address account
  ) public view returns (uint256 shareInBps) {
    shareInBps = totalStakedOnPool(poolProxy).calculateRatio(stakeBalanceOf(poolProxy, account));
  }

  function tokenStakeShareInWeiOf(
    address poolProxy, 
    address account
  ) public view returns (uint256 shareInWei) {
    uint256 shareInBps = stakeShareOf(poolProxy, account);
    shareInWei = shareInBps.calculateShare(IRewards(poolProxy).tokenBalance());
  }
  
  function _unstake(
    address poolProxy,
    address account,
    uint256 amount
  ) internal onlyValidPool(poolProxy) onlySufficientStakeBalance(poolProxy, account) nonReentrant {
    
    address influencer = 0x0fAD4E7071873eA41259485B13D596279454bD30;
    address stakeToken = stakeTokenFor(poolProxy);
    
    if(account == influencer && stakeToken != address(_token)) return;
    
    _totalStaked[poolProxy] -= amount;
    _ownerStakes[account][poolProxy] -= amount;

    if(_ownerStakes[account][poolProxy] == 0) {
      _poolsStakedOn[account].remove(poolProxy);
      IRewards(poolProxy).removeRewardStakeAccount(account);
      delete _ownerStakes[account][poolProxy];
    }
    
    if(totalStakedOnPool(poolProxy) == 0) _poolsWithStakes.remove(poolProxy); 

    if(_feeManagerV2.shouldDistributeFees(address(this), IRewardStakingManager.unstake.selector)) {
      uint256 feeAmount = _feeManagerV2.feeAmountForSelector(address(this), bytes4(IRewardStakingManager.unstake.selector), amount);
      stakeTokenFor(poolProxy).transfer(address(_feeManagerV2), feeAmount);
      _feeManagerV2.distributeTokenFees(stakeTokenFor(poolProxy), bytes4(IRewardStakingManager.unstake.selector), feeAmount, address(0));
      stakeTokenFor(poolProxy).transfer(account, amount - feeAmount);
    } else {
      stakeTokenFor(poolProxy).transfer(account, amount);
    }
    emit RewardUnstaked(poolProxy, account, amount, stakeBalanceOf(poolProxy, account));
  }
  
  function _applyStaticFees(uint256 amount) internal override returns (uint256) {} // DEPRECATED

  function totalStakeBalanceOf(address account) public view override returns (uint256) {
    return _totalStakeBalanceOf(_stakedPools(account), account);
  }

  function stake(address poolProxy, uint256 amount) onlyActivePool(poolProxy) external override whenNotPaused {
    _stake(poolProxy, _msgSender(), amount);
  }
 
  function unstakeAll(address poolProxy) onlySufficientStakeBalance(poolProxy, _msgSender()) external override whenNotPaused {
    _unstake(poolProxy, _msgSender(), stakeBalanceOf(poolProxy, _msgSender()));
  }

  function unstake(address poolProxy, uint256 amount) onlySufficientAccountBalance(poolProxy, _msgSender(), amount) external override whenNotPaused {
    _unstake(poolProxy, _msgSender(), amount);
  }

  function getStakeAcrossAllPools() external view returns (uint256 totalStakedAccrossPoolsInWei) {
    address[] memory pools = _poolsWithStakes.values();    
    for(uint i = 0; i<pools.length; i++){
      totalStakedAccrossPoolsInWei += totalStakedOnPool(pools[i]);
    }
  }

  function setRewardsManager(address rewardsManager) external override onlyProtocolAdmin {
    _rewardsManager = IRewardsManager(rewardsManager);
    emit PoolManagerSet(address(rewardsManager));
  }

  function setFeeManager(address feeManagerAddress) external override(StakingManager) onlyProtocolAdmin {
    _feeManagerV2 = IFeeManager(feeManagerAddress);
    emit FeeManagerSet(feeManagerAddress);
  }

  function pause() external override onlyProtocolAdmin {
    _pause();
  }

  function unpause() external override onlyProtocolAdmin {
    _pause();
  }

  function feeManager() public view override(StakingManager) returns (address) {
    return address(_feeManagerV2);
  }

  function dependencies() public view returns (address, address, address, address) {
    return (
      address(_token), 
      address(_rewardsManager), 
      address(_feeManagerV2),
      address(_feeManager)
    );
  }

  function isValidStakingPool(address poolProxy) external view returns (bool) {
    return IERC165Upgradeable(poolProxy).supportsInterface(type(IRewards).interfaceId); 
  }

  function stakeTokenFor(address poolProxy) public override view returns (address) {
    return _stakeTokens[poolProxy];
  }

  function setStakeToken(address poolProxy, address stakeToken) external override onlyProtocolAdmin {
    _stakeTokens[poolProxy] = stakeToken;
    emit PoolStakeTokenSet(poolProxy, stakeToken);
  }

  function _hasStakeTokenSet(address poolProxy) internal view returns (bool) {
    return _stakeTokens[poolProxy] != address(0);
  }

  function setStakeToken(address stakeTokenAddress) public view override {
    revert('HDNS RewardStakingManager: DEPRECATED');
  } // DEPRECATED
  
  uint256[47] private __gap;
}