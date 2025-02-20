// @author Daosourced
// @date Jan 9, 2024
pragma solidity ^0.8.12;

import './openzeppelin_contracts-upgradeable_utils_ContextUpgradeable.sol';
import './openzeppelin_contracts-upgradeable_utils_introspection_ERC165Upgradeable.sol';
import "./openzeppelin_contracts-upgradeable_utils_structs_EnumerableSetUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_security_ReentrancyGuardUpgradeable.sol";
import "./openzeppelin_contracts_utils_cryptography_MerkleProof.sol";

import './openzeppelin_contracts_token_ERC20_ERC20.sol';
import "./openzeppelin_contracts_utils_Address.sol";
import './contracts_rewards_IRewardsPool.sol';
import './contracts_token_HashtagCredits.sol';
import './contracts_deprecated_IFees.sol';
import './contracts_utils_Strings.sol';
import './contracts_utils_Distribution.sol';
import './contracts_utils_Pausable.sol';
import './contracts_staking_IRewardStakingManager.sol';

/**
* @title An abstract contract for pools used in the HDNS ecosystem
* @dev contains function declarations that all pools should have
*/
contract RewardsPool is ERC165Upgradeable, Pausable, ReentrancyGuardUpgradeable, IRewardsPool {
    
    using Address for address payable;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
    using Strings for string;
    using Distribution for uint256;

    string public POOL_NAME;
        
    HashtagCredits private _tokenCredits;

    HashtagCredits private _nativeCredits;
        
    ERC20 private _rewardsToken;

    uint256 private _nativeBalance;

    IFees private _feeManager;
    
    EnumerableSetUpgradeable.AddressSet internal _accounts;

    address public POOL_MANAGER;

    IRewardStakingManager internal _rewardStakingManager;

    bool public SUPPORTS_REWARD_STAKING; 

    bool public IS_ACTIVE;

    mapping(address => uint256) private _tokenCreditBalances;

    mapping(address => uint256) private _nativeCreditBalances;

    string public TOKEN_CREDITS_SYMBOL;
    
    string public NATIVE_CREDITS_SYMBOL;

    mapping(address => uint256) private _tokenCreditsClaimed;

    mapping(address => uint256) private _nativeCreditsClaimed;

    bytes32 private _root;

    bytes32[] private _previousRoots;

    modifier onlySufficientCreditBalance(address account, uint256 amount, IRewards.RewardType rewardType) {
        if(rewardType == IRewards.RewardType.Token) require(_getCredits(account, IRewards.RewardType.Token) >= amount, 'HDNS RewardsPool: INSUFFICIENT_CREDIT_BALANCE');
        if(rewardType == IRewards.RewardType.Native) require(_getCredits(account, IRewards.RewardType.Native) >= amount, 'HDNS RewardsPool: INSUFFICIENT_CREDIT_BALANCE');
        _;
    }

    modifier onlySuffientPoolBalance(uint256 amount, IRewards.RewardType rewardType) {
        if (rewardType == IRewards.RewardType.Token) require(tokenBalance() >= amount, 'HDNS RewardsPool: INSUFFICIENT_POOL_BALANCE'); 
        if (rewardType == IRewards.RewardType.Native) require(nativeBalance() >= amount, 'HDNS RewardsPool: INSUFFICIENT_POOL_BALANCE');
        _;
    }

    modifier onlyPoolManager {
        require(_msgSender() == POOL_MANAGER, 'HDNS RewardsPool: CALLER_IS_NOT_POOL_MANAGER');
        _;
    }
    
    modifier onlyIfActive {
        require(IS_ACTIVE, 'HDNS RewardsPool: POOL_IS_INACTIVE');
        _;
    }

    modifier onlyIfSupportsRewardStaking {
        require(SUPPORTS_REWARD_STAKING, 'HDNS RewardsPool: UNSUPPORTED_CLAIM_METHOD');
        _;
    }

    function initialize(
        string memory _poolName,
        address rewardsTokenAddress,
        address feeManager_,
        address rewardStakingManager,
        bool supportsRewardStaking_,
        bool isActive 
    ) public initializer {
        __Pausable_init();
        __ERC165_init();
        __ReentrancyGuard_init();
        __RewardsPool_init(
            _poolName, 
            rewardsTokenAddress, 
            feeManager_, 
            rewardStakingManager,
            supportsRewardStaking_,
            isActive
        );
    }

    function __RewardsPool_init(
        string memory _poolName,
        address rewardsTokenAddress,
        address feeManager_,
        address rewardStakingManager,
        bool supportsRewardStaking_,
        bool isActive
    ) internal {
        __RewardsPool_init_unchained(_poolName, rewardsTokenAddress, feeManager_, rewardStakingManager, supportsRewardStaking_, isActive);
        TOKEN_CREDITS_SYMBOL = POOL_NAME.concat('-HTCRED');
        NATIVE_CREDITS_SYMBOL = POOL_NAME.concat('-HNCRED');
    }
    
    function __RewardsPool_init_unchained(
        string memory _poolName,
        address rewardsTokenAddress,
        address feeManager_,
        address rewardStakingManager,
        bool supportsRewardStaking_,
        bool isActive
    ) internal onlyInitializing  {
        // should set the root chain of the merkle tree
        POOL_NAME = _poolName;
        TOKEN_CREDITS_SYMBOL = POOL_NAME.concat('-HTCRED');
        NATIVE_CREDITS_SYMBOL = POOL_NAME.concat('-HNCRED');
        _feeManager = IFees(feeManager_);
        _rewardsToken = ERC20(rewardsTokenAddress);
        _rewardStakingManager = IRewardStakingManager(rewardStakingManager);
        POOL_MANAGER = _msgSender();
        SUPPORTS_REWARD_STAKING = supportsRewardStaking_;
        IS_ACTIVE = isActive;
    }

    function pause() external onlyPoolManager {
        _pause();
    }
    
    function unpause() external onlyPoolManager {
        _pause();
    }

    function supportsInterface(bytes4 interfaceId) 
        public view override(ERC165Upgradeable) 
        returns (bool) { return  interfaceId == type(IRewardsPool).interfaceId || super.supportsInterface(interfaceId);
    }
    
    function rewardsToken() external view override returns (address){
        return address(_rewardsToken);
    }

    function nativeBalance() public view override returns (uint256 poolBalance) {
        poolBalance = _nativeBalance;
    }
    
    function tokenBalance() public view override returns (uint256 poolTokenBalance) {
        poolTokenBalance = _rewardsToken.balanceOf(address(this)); 
    }

    function withdrawTokenRewards(uint256 penaltyPeriodOrWithdrawAmountInWei) public override onlyIfActive
    onlySuffientPoolBalance(penaltyPeriodOrWithdrawAmountInWei, IRewards.RewardType.Token)
    onlySufficientCreditBalance(_msgSender(), penaltyPeriodOrWithdrawAmountInWei, IRewards.RewardType.Token) {
        IRewards.RewardType rewardType = IRewards.RewardType.Token;
        if(_feeManager.hasFeeRule(address(this), rewardType)) {
            if(_feeManager.isFeeRuleDynamic(address(this), rewardType)) {
                _claimRewardsWithDynamicFees(_msgSender(), penaltyPeriodOrWithdrawAmountInWei, rewardType);
            } else {
                _claimRewardsWithStaticFees(_msgSender(), penaltyPeriodOrWithdrawAmountInWei, rewardType);
            }
        } else {
            _clearCredits(_msgSender(), penaltyPeriodOrWithdrawAmountInWei, rewardType);
            _claimRewards(_msgSender(), penaltyPeriodOrWithdrawAmountInWei, rewardType);
        }
    }

    function withdrawNativeRewards(uint256 penaltyPeriodOrWithdrawAmountInWei) public override onlyIfActive
    onlySuffientPoolBalance(penaltyPeriodOrWithdrawAmountInWei, IRewards.RewardType.Native)
    onlySufficientCreditBalance(_msgSender(), penaltyPeriodOrWithdrawAmountInWei, IRewards.RewardType.Native) {
        IRewards.RewardType rewardType = IRewards.RewardType.Native;
        if(_feeManager.hasFeeRule(address(this), rewardType)){
            if(_feeManager.isFeeRuleDynamic(address(this), rewardType)) {
                _claimRewardsWithDynamicFees(_msgSender(), penaltyPeriodOrWithdrawAmountInWei, rewardType);
            } else {
                _claimRewardsWithStaticFees(_msgSender(), penaltyPeriodOrWithdrawAmountInWei, rewardType);
            }
        } else {
            _clearCredits(_msgSender(), penaltyPeriodOrWithdrawAmountInWei, rewardType);
            _claimRewards(_msgSender(), penaltyPeriodOrWithdrawAmountInWei, rewardType);
        }
    }

    function _claimRewardsWithDynamicFees(
        address to, 
        uint256 targetPenalty,
        IRewards.RewardType rewardType
    ) internal {
        uint256 totalSendAmountInWei;
        uint256 totalFeeAmountInWei;
        address[] memory feeTakers;
        uint256[] memory feeTakersDistSharesInWei;
        (
            totalSendAmountInWei,
            totalFeeAmountInWei,
            feeTakers,
            feeTakersDistSharesInWei
        ) = _feeManager.calculateDynamicFees(address(this), to, targetPenalty, rewardType);
        _feeManager.clearRewardTimestamps(to, targetPenalty, rewardType);
        _clearCredits(to, totalSendAmountInWei+totalFeeAmountInWei, rewardType);
        _claimRewards(to, totalSendAmountInWei, rewardType);
        _distributeFees(feeTakers, feeTakersDistSharesInWei, totalFeeAmountInWei, rewardType);
    }

    function _claimRewardsWithStaticFees(
        address to, 
        uint256 amount,
        IRewards.RewardType rewardType
    ) internal  {
        uint256 totalSendAmountInWei;
        uint256 totalFeeAmountInWei;
        address[] memory feeTakers;
        uint256[] memory feeTakersDistSharesInWei;
        (
            totalSendAmountInWei,
            totalFeeAmountInWei,
            feeTakers,
            feeTakersDistSharesInWei
        ) = _feeManager.calculateStaticFees(address(this), amount, rewardType);
        _clearCredits(to, totalSendAmountInWei+totalFeeAmountInWei, rewardType);
        _claimRewards(to, totalSendAmountInWei, rewardType);
        _distributeFees(feeTakers, feeTakersDistSharesInWei, totalFeeAmountInWei, rewardType);
    }

    function _clearCredits(address account, uint256 amount, IRewards.RewardType rewardType) internal whenNotPaused {
        if(rewardType == IRewards.RewardType.Native) {
            _nativeCreditBalances[account]-=amount;
            emit CreditsRemoved(
                account, 
                amount, 
                _getCredits(account, rewardType), 
                NATIVE_CREDITS_SYMBOL
            );
        } else if (rewardType == IRewards.RewardType.Token) {
            _tokenCreditBalances[account]-=amount;
            emit CreditsRemoved(
                account, 
                amount, 
                _getCredits(account, rewardType), 
                TOKEN_CREDITS_SYMBOL
            );
        }
    }
    
    function _claimRewards(address to, uint256 amount, IRewards.RewardType rewardType) internal whenNotPaused nonReentrant {
        if(rewardType == IRewards.RewardType.Native) {
            _nativeBalance-=amount;
            payable(to).sendValue(amount);
        } else if (rewardType == IRewards.RewardType.Token) {
            _rewardsToken.transfer(to, amount);
        }
        emit RewardsClaim(to, amount, rewardType);
        if(_getCredits(to, rewardType) == 0 && !SUPPORTS_REWARD_STAKING) _accounts.remove(to);
    }

    function _distributeFees(
        address[] memory feeTakers, 
        uint256[] memory feeTakersDistSharesInWei,
        uint256 totalFeeAmountInWei,
        IRewards.RewardType rewardType
    ) internal {
        if(rewardType == IRewards.RewardType.Native){
            _feeManager.distributeFees{ value: totalFeeAmountInWei }(feeTakers, feeTakersDistSharesInWei);
        } else {
            _rewardsToken.approve(address(_feeManager), totalFeeAmountInWei);
            _feeManager.distributeFees(address(_rewardsToken), feeTakers, feeTakersDistSharesInWei);
        }
    }

    function depositTokenCredits(
        address[] memory tos,
        uint256 amount
    ) external override onlyPoolManager {
        _depositCredits(tos, amount, IRewards.RewardType.Token);
    }

    function depositNativeCredits(
        address[] memory tos,
        uint256 amount
    ) external override onlyPoolManager {
        _depositCredits(tos, amount, IRewards.RewardType.Native);
    }

    function _depositCredits(
        address[] memory tos, 
        uint256 amount, 
        IRewards.RewardType rewardType
    ) internal whenNotPaused {
        for(uint256 i = 0; i< tos.length;i++) {
            if(SUPPORTS_REWARD_STAKING){
                if(_rewardStakingManager.hasAccountStaked(address(this), tos[i])) {
                    uint256 creditsInWei = _rewardShareFromStakeOf(tos[i], amount, rewardType);
                    _depositCredits(tos[i], creditsInWei, rewardType);
                }
            } else {
                _depositCredits(tos[i], amount, rewardType);
            }
        }
    }

    function _rewardShareFromStakeOf(
        address account,
        uint256 amount,
        IRewards.RewardType rewardType
    ) internal view returns (uint256 rewardShareFromStake) {
        uint256 stakeShareInBps = _rewardStakingManager.stakeShareOf(address(this), account); 
        if(rewardType == IRewards.RewardType.Token) {
            rewardShareFromStake = amount.calculateShare(stakeShareInBps);
        } else {
            rewardShareFromStake = amount.calculateShare(stakeShareInBps);
        }
    }

    function _depositCredits(
        address to, 
        uint256 amount, 
        IRewards.RewardType rewardType
    ) internal whenNotPaused { 
        if(!_accounts.contains(to)) _accounts.add(to);
        if(_feeManager.hasFeeRule(address(this), rewardType) && _feeManager.isFeeRuleDynamic(address(this), rewardType)) _feeManager.recordRewardTimestamp(to, amount, rewardType);
        if(rewardType == IRewards.RewardType.Native) {
            _nativeCreditBalances[to]+=amount;
            emit CreditsAdded(to, amount, _getCredits(to, rewardType), NATIVE_CREDITS_SYMBOL);
        } else {
            _tokenCreditBalances[to]+=amount;
            emit CreditsAdded(to, amount, _getCredits(to, rewardType), TOKEN_CREDITS_SYMBOL);
        }
    }
    
    function tokenCreditBalanceOf(address account) external view override returns (uint256) {
        return _getCredits(account, IRewards.RewardType.Token);
    }

    function nativeCreditBalanceOf(address account) external view override returns (uint256) {
        return _getCredits(account, IRewards.RewardType.Native);
    }

    function _getCredits(address account, IRewards.RewardType rewardType) internal view returns (uint256 balance) {
        if(rewardType == IRewards.RewardType.Native) {
            balance = _nativeCreditBalances[account];
        } else if (rewardType == IRewards.RewardType.Token) {
            balance = _tokenCreditBalances[account];
        }
    }

    function _transferCredits(
        address from, 
        address to, 
        uint256 amountInWei, 
        IRewards.RewardType rewardType
    ) internal whenNotPaused {
        if(rewardType == IRewards.RewardType.Native) {
            _nativeCreditBalances[from]-=amountInWei;
            _nativeCreditBalances[to]+=amountInWei;
            emit CreditsTransfer(from, to, amountInWei, _getCredits(from, rewardType), NATIVE_CREDITS_SYMBOL);
        } else if (rewardType == IRewards.RewardType.Token) {
            _tokenCreditBalances[from]-=amountInWei;
            _tokenCreditBalances[to]+=amountInWei;
            emit CreditsTransfer(from, to, amountInWei, _getCredits(from, rewardType), TOKEN_CREDITS_SYMBOL);
        }
    } 

    function deposit() external payable override onlyPoolManager whenNotPaused {
        _nativeBalance += msg.value;
    }

    function accounts() external view override returns (address[] memory) {
        return _accounts.values();
    }

    function transferTokenCredits(address to, uint256 amount) onlySufficientCreditBalance(_msgSender(), amount, IRewards.RewardType.Token) public override onlyIfActive {
        _transferCredits(_msgSender(), to, amount, IRewards.RewardType.Token);
    }
    
    function transferNativeCredits(address to, uint256 amount) public override onlyIfActive onlySufficientCreditBalance(_msgSender(), amount, IRewards.RewardType.Native) {
        _transferCredits(_msgSender(), to, amount, IRewards.RewardType.Native);
    }

    function creditsAddress(IRewards.RewardType rewardType) public view override returns (address) {
        if(rewardType == IRewards.RewardType.Native) {
            return address(_nativeCredits);
        } else {
            return address(_tokenCredits);
        }
    }

    function _setStakingManager(address stakingMangerAddress) internal {
        _rewardStakingManager = IRewardStakingManager(stakingMangerAddress);
        emit SetRewardStakingManager(stakingMangerAddress);
    }

    function stakingManager() external view override returns(address) {
        return address(_rewardStakingManager);
    }

    function feeManager() external view override returns(address) {
        return address(_feeManager);
    }

    function configure(Configuration memory poolConfig) external override onlyPoolManager {
        _feeManager = IFees(poolConfig.feeManager); 
        _setStakingManager(poolConfig.rewardStakingManager);
        IS_ACTIVE = poolConfig.isActive;
        SUPPORTS_REWARD_STAKING = poolConfig.supportsRewardStaking; 
        emit ConfigurePool(address(this), poolConfig.feeManager, poolConfig.rewardStakingManager, poolConfig.isActive);
    }
    
    function createRewardStakeAccount(address account) external override onlyIfSupportsRewardStaking {
        require(_msgSender() == address(_rewardStakingManager), 'HDNS RewardsPool: CALLER_NOT_AN_HDNS_STAKING_MANAGER');
        if(!_accounts.contains(account)){
            _accounts.add(account);
            emit AccountCreation(address(this), account);
        }
    }

    function removeRewardStakeAccount(address account) external override onlyIfSupportsRewardStaking {
        require(_msgSender() == address(_rewardStakingManager), 'HDNS RewardsPool: CALLER_NOT_AN_HDNS_STAKING_MANAGER');
        if(_accounts.contains(account)){
            _accounts.remove(account);
            emit AccountRemoval(address(this), account);
        }
    }

    function drain(address receiver) external override onlyPoolManager {
        if(_nativeBalance > 0) {
            payable(receiver).sendValue(_nativeBalance);
            _nativeBalance = 0;
        }
        if(_rewardsToken.balanceOf(address(this)) > 0) {
            _rewardsToken.transfer(receiver, _rewardsToken.balanceOf(address(this)));
        }
    }
    uint256[43] private __gap;
}