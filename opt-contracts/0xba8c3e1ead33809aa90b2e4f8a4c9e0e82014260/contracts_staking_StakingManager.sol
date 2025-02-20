// @author Daosourced
// @date September 6, 2023
pragma solidity ^0.8.0;

import "./openzeppelin_contracts-upgradeable_security_ReentrancyGuardUpgradeable.sol";
import './contracts_token_SpaceToken.sol';
import './contracts_roles_ProtocolAdminRole.sol';
import './contracts_staking_IStakingManager.sol';
import './contracts_IHDNSRegistry.sol';
import {IPoolManager} from './contracts_rewards_IPoolManager.sol';
import './contracts_rewards_IRewardsManager.sol';
import './contracts_deprecated_IFees.sol';
import {IFees} from './contracts_deprecated_IFees.sol';
import './contracts_utils_Distribution.sol';


abstract contract StakingManager is IStakingManager, ReentrancyGuardUpgradeable, ProtocolAdminRole {
  using Distribution for uint256[];
 
  SpaceToken internal _token;
 
  IHDNSRegistry internal _registry;
 
  IPoolManager internal _poolManager;

  IFees internal _feeManager;
  
  function __StakingManager_init(
    address stakeTokenAddress,
    address feeManagerAddress
    ) internal onlyInitializing {
    __StakingManager_init_unchained(stakeTokenAddress, feeManagerAddress);
    __ProtocolAdminRole_init();
    __ReentrancyGuard_init();
  }

  function __StakingManager_init_unchained(
    address stakeTokenAddress,
    address feeManagerAddress
    ) internal onlyInitializing {
    _token = SpaceToken(stakeTokenAddress);
    emit StakeTokenSet(stakeTokenAddress);
    _feeManager = IFees(feeManagerAddress);
    emit FeeManagerSet(feeManagerAddress);
  }
  
  function __StakingManager_init_for_reward_staking(address poolManagerAddress) internal onlyInitializing {
    _poolManager = IPoolManager(poolManagerAddress);
    emit PoolManagerSet(poolManagerAddress);
  }
  
  function __StakingManager_init_for_keyword_staking(address registryAddress) internal onlyInitializing {
    _registry = IHDNSRegistry(registryAddress);
    emit RegistrySet(registryAddress);
  }
  
  function setStakeToken(address stakeTokenAddress) public virtual onlyProtocolAdmin {
    _token = SpaceToken(stakeTokenAddress);
    emit StakeTokenSet(stakeTokenAddress);
  }

  function setRegistry(address registryAddress) public override onlyProtocolAdmin {
    _registry = IHDNSRegistry(registryAddress);
    emit RegistrySet(registryAddress);
  }

  function setFeeManager(address feeManagerAddress) external override virtual onlyProtocolAdmin {
    _feeManager = IFees(feeManagerAddress);
    emit FeeManagerSet(feeManagerAddress);
  }

  function registry() public view override returns(address) {
    return address(_registry);
  }

  function token() external view override returns(address) {
    return address(_token);
  }

  function feeManager() public view virtual returns(address) {
    return address(_feeManager);
  }

  function _applyStaticFees(
    uint256 amount
  ) internal virtual nonReentrant returns (uint256) {
    (
      uint256 totalSendAmountInWei,
      uint256 totalFeeAmountInWei,
      address[] memory feeTakers,
      uint256[] memory feeTakersDistSharesInWei
    ) = _feeManager.calculateStaticFees(
        address(this), 
        amount,
        IRewards.RewardType.Token
    );
    _token.approve(address(_feeManager), totalFeeAmountInWei);
    _feeManager.distributeFees(address(_token), feeTakers, feeTakersDistSharesInWei);
    return totalSendAmountInWei;
  }
}