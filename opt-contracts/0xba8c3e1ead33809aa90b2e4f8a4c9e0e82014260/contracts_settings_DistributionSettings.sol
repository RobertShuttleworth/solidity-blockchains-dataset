// @author Daosourced
// @date Ocotober 18, 2023

pragma solidity ^0.8.0;

import './openzeppelin_contracts_token_ERC20_ERC20.sol';
import "./openzeppelin_contracts_utils_structs_EnumerableSet.sol";
import "./openzeppelin_contracts_utils_structs_EnumerableMap.sol";

import './contracts_settings_IDistributionSettings.sol';
import './contracts_IMintingManager.sol';
import './contracts_rewards_IRewards.sol';
import './contracts_roles_ProtocolAdminRole.sol';
import './contracts_utils_Distribution.sol';
import './contracts_utils_Strings.sol';

/**
* @title Contract that is tasked with management of payment settings on the main controller contract 
* @dev contains function defintions for payment protocol manager contract
*/
contract DistributionSettings is ProtocolAdminRole, IDistributionSettings {
    
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableMap for EnumerableMap.UintToAddressMap;
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    using Strings for string;
    using Distribution for uint256;
    using Distribution for uint256[];

    mapping(uint256 => mapping(IRewards.RewardType => GlobalDistributionConfig)) _globalDistributionConfig;

    /** @notice Token, Native => set of action type hashes */
    mapping(IRewards.RewardType => EnumerableSet.UintSet) internal _actionHashes;
    
    /** @notice action type hash => action type */
    mapping(uint256 => string) internal _actionTypes;

    modifier onlyExistingAction(string memory actionType) {
        require(_existsActionType(actionType), 'HDNS Settings: INVALID_DISTRIBUTION_ACTION');
        _;
    }

    function initialize(DistributionConfig[] memory configs) external initializer {
        __ProtocolAdminRole_init();
        _configureDistributionSettings(configs);
    }

    function __DistributionSettings_init_(DistributionConfig[] memory configs) internal onlyInitializing {
        _configureDistributionSettings(configs);
    }

    function _configureDistributionSettings(DistributionConfig[] memory configs) internal {
        for (uint256 i = 0; i < configs.length; i++) {
           _configureDistributionSetting(configs[i]);
        }
    }

    function _configureDistributionSetting(DistributionConfig memory config) internal { 
        if(!_existsActionType(config.actionType)) {
            _setActionType(config.actionType, config.rewardType);
        } else {
            _clearConfig(_getDistributionConfig(config.actionType, config.rewardType));
        }
        _setFallbackData(
            config.actionType.keyHash(),
            config.rewardType, 
            config.fallbackRewardAddress, 
            config.fallbackRewardDirection
        );
        _setDistributionSettings(config);
    }


    function _setDistributionSettings(DistributionConfig memory config) internal {
        for (uint256 i = 0; i < config.rewardAddresses.length; i++) {
            _setDistributionSetting(
                config.actionType, 
                config.rewardType, 
                config.rewardAddresses[i],
                config.rewardDirections[i], 
                config.distShares[i],
                config.accThresholds[i]
            );
        }
        if(config.ignoreAddresses.length > 0) {
            for(uint i = 0; i < config.ignoreAddresses.length; i++) {
                _ignoreDistAddress(config.actionType, config.rewardType, config.ignoreAddresses[i]);
            }
        }
    }

    function _clearConfig(DistributionConfig memory config) internal {
        if(config.rewardAddresses.length > 0) {
            for(uint i =0; i< config.rewardAddresses.length;i++) {
                delete _globalDistributionConfig[config.actionType.keyHash()][config.rewardType].distShares[config.rewardAddresses[i]];
                delete _globalDistributionConfig[config.actionType.keyHash()][config.rewardType].accThresholds[config.rewardAddresses[i]];
                _globalDistributionConfig[config.actionType.keyHash()][config.rewardType].rewardDirections.remove(config.rewardAddresses[i]);
                _globalDistributionConfig[config.actionType.keyHash()][config.rewardType].rewardAddresses.remove(config.rewardAddresses[i]);
            }
        }

        if(config.ignoreAddresses.length > 0){
            for(uint i =0; i< config.ignoreAddresses.length;i++) {
                delete _globalDistributionConfig[config.actionType.keyHash()][config.rewardType].distShares[config.rewardAddresses[i]];
                delete _globalDistributionConfig[config.actionType.keyHash()][config.rewardType].accThresholds[config.rewardAddresses[i]];
                _globalDistributionConfig[config.actionType.keyHash()][config.rewardType].rewardDirections.remove(config.rewardAddresses[i]);
                _globalDistributionConfig[config.actionType.keyHash()][config.rewardType].rewardAddresses.remove(config.rewardAddresses[i]);
            }
        }
        delete _globalDistributionConfig[config.actionType.keyHash()][config.rewardType].fallbackRewardAddress;
        delete _globalDistributionConfig[config.actionType.keyHash()][config.rewardType].fallbackRewardDirection;
    }

    function _updateDistributionSetting(
        string memory actionType,
        IRewards.RewardType rewardType,        
        UpdateDistributionConfigParams memory oldConfig,
        UpdateDistributionConfigParams memory newConfig
    ) internal {
        // update dist shares
        delete _globalDistributionConfig[actionType.keyHash()][rewardType].distShares[oldConfig.rewardAddress];
        _globalDistributionConfig[actionType.keyHash()][rewardType].distShares[newConfig.rewardAddress] = newConfig.bps;
        
        // update thresholds 
        delete _globalDistributionConfig[actionType.keyHash()][rewardType].accThresholds[oldConfig.rewardAddress];
        _globalDistributionConfig[actionType.keyHash()][rewardType].accThresholds[newConfig.rewardAddress] = newConfig.minAccount;
        
        // update directions and addresses
        _globalDistributionConfig[actionType.keyHash()][rewardType].rewardDirections.remove(oldConfig.rewardAddress);
        _globalDistributionConfig[actionType.keyHash()][rewardType].rewardAddresses.remove(oldConfig.rewardAddress);
        
        _globalDistributionConfig[actionType.keyHash()][rewardType].rewardDirections.set(newConfig.rewardAddress, uint(newConfig.direction));
        _globalDistributionConfig[actionType.keyHash()][rewardType].rewardAddresses.add(newConfig.rewardAddress);
        emit SetDistributionSetting(actionType, rewardType, newConfig.rewardAddress, newConfig.bps);
    }

    function _setDistributionSetting(   
        string memory actionType,
        IRewards.RewardType rewardType,
        address rewardAddress,
        RewardDirection direction,
        uint256 bps,
        uint256 minAccount
    ) internal {
        _globalDistributionConfig[actionType.keyHash()][rewardType].rewardType = rewardType;
        _globalDistributionConfig[actionType.keyHash()][rewardType].actionType = actionType;
        _globalDistributionConfig[actionType.keyHash()][rewardType].rewardDirections.set(rewardAddress, uint(direction));
        _globalDistributionConfig[actionType.keyHash()][rewardType].distShares[rewardAddress] = bps;
        _globalDistributionConfig[actionType.keyHash()][rewardType].accThresholds[rewardAddress] = minAccount;
        _globalDistributionConfig[actionType.keyHash()][rewardType].rewardAddresses.add(rewardAddress);
        emit SetDistributionSetting(actionType, rewardType, rewardAddress, bps);
    }

    function setGlobalDistributionConfigs(DistributionConfig[] memory configs) external override onlyProtocolAdmin {
        for(uint256 i = 0; i < configs.length; i++) {
            _configureDistributionSetting(configs[i]);
        }
    }

    function getActionConfigs(
        string[] memory actionTypes,
        IRewards.RewardType[] memory rewardTypes
    ) external view override returns (string[] memory, DistributionSetting[][] memory) { 
        DistributionSetting[][] memory configs = new DistributionSetting[][](actionTypes.length);
        for (uint256 i = 0; i < actionTypes.length; i++){
            configs[i] = _getActionConfigurations(actionTypes[i], rewardTypes[i]);
        }
        return (actionTypes, configs);
    }

    function getActionConfig(
        string memory actionType,
        IRewards.RewardType rewardType
    ) external view override returns (DistributionSetting[] memory) {
        return _getActionConfigurations(actionType, rewardType);
    }

    function _getActionConfigurations(
        string memory actionType, 
        IRewards.RewardType rewardType
    ) internal view returns (DistributionSetting[] memory actionConfigs) {
        DistributionConfig memory config = _getDistributionConfig(actionType, rewardType);
        actionConfigs = new DistributionSetting[](config.rewardAddresses.length);
        for(uint i = 0; i < config.rewardAddresses.length; i++) {
            actionConfigs[i] = DistributionSetting({
                rewardAddress: config.rewardAddresses[i],
                rewardDirection: config.rewardDirections[i],
                fallbackRewardAddress: config.fallbackRewardAddress,
                fallbackRewardDirection: config.fallbackRewardDirection,
                accThreshold: config.accThresholds[i],
                distShare: config.distShares[i]
            });
        }
        return actionConfigs;
    }  

    function _getDistributionConfig(
        string memory actionType, 
        IRewards.RewardType rewardType 
    ) internal view returns (DistributionConfig memory config) {
        address[] memory rewardAddresses = _globalDistributionConfig[actionType.keyHash()][rewardType].rewardAddresses.values();
        RewardDirection[] memory directions = new RewardDirection[](rewardAddresses.length);
        uint256[] memory distShares = new uint256[](rewardAddresses.length);
        uint256[] memory accThresholds = new uint256[](rewardAddresses.length);
        for(uint i = 0; i < rewardAddresses.length;i++) {
            directions[i] = RewardDirection(_globalDistributionConfig[actionType.keyHash()][rewardType].rewardDirections.get(rewardAddresses[i]));
            distShares[i] = _globalDistributionConfig[actionType.keyHash()][rewardType].distShares[rewardAddresses[i]];
            accThresholds[i] = _globalDistributionConfig[actionType.keyHash()][rewardType].accThresholds[rewardAddresses[i]];
        }
        config = DistributionConfig({
            actionType: actionType,
            rewardType: rewardType,
            rewardAddresses: rewardAddresses,
            rewardDirections: directions,
            accThresholds: accThresholds,
            fallbackRewardAddress: _globalDistributionConfig[actionType.keyHash()][rewardType].fallbackRewardAddress, 
            fallbackRewardDirection: _globalDistributionConfig[actionType.keyHash()][rewardType].fallbackRewardDirection,
            distShares: distShares,
            ignoreAddresses: _globalDistributionConfig[actionType.keyHash()][rewardType].ignoreAddresses.values()
        });
    }

    function calculateRewardShares(  
        string memory actionType,
        IRewards.RewardType rewardType,
        uint256 distributionAmount
    ) public view override returns (DistributionSetting[] memory, uint256[] memory shareAmounts) {        
        return _calculateShares(actionType, rewardType, distributionAmount);
    }
    function _calculateShares(  
        string memory actionType,
        IRewards.RewardType rewardType,
        uint256 distributionAmount
    ) internal view returns (DistributionSetting[] memory, uint256[] memory shareAmounts) {        
        DistributionSetting[] memory configs = _getActionConfigurations(actionType, rewardType);
        shareAmounts = new uint256[](configs.length);
        for (uint256 i = 0; i < configs.length; i++) {
            shareAmounts[i] = distributionAmount.calculateShare(configs[i].distShare);
        }
        return (configs, shareAmounts);
    }

    function calculateRewardSharesFor(
        string memory actionType,
        IRewards.RewardType rewardType,
        RewardDirection direction,
        uint256 distributionAmount
    ) public view override returns (
        DistributionSetting[] memory configs, 
        uint256[] memory shareAmounts
        ) {    
        (configs, shareAmounts) = _calculateShares(actionType, rewardType, distributionAmount);
        uint256 configsCount;
        for(uint256 i = 0; i < configs.length; i++) {
            if(configs[i].rewardDirection == direction) configsCount++;
        }
        DistributionSetting[] memory filtered = new DistributionSetting[](configsCount);  
        uint256[] memory filteredAmounts = new uint256[](configsCount);  
        uint j = 0;
        for(uint256 i = 0; i < configs.length; i++){
            if(configs[i].rewardDirection == direction) {
                filtered[j] = configs[i];
                filteredAmounts[j] = shareAmounts[i];
                j++;
            }
        }
        configs = filtered;
        shareAmounts = filteredAmounts;
    }

    function ignoreDistAddresses(
        string memory actionType, 
        IRewards.RewardType rewardType, 
        address[] memory ignoreAddresses
    ) external override onlyProtocolAdmin onlyExistingAction(actionType) {
        for(uint i = 0; i < ignoreAddresses.length; i++) {
            _ignoreDistAddress(actionType, rewardType, ignoreAddresses[i]);
        }
    }

    function unignoreDistAddresses(
        string memory actionType, 
        IRewards.RewardType rewardType, 
        address[] memory ignoreAddresses
    ) external override onlyProtocolAdmin onlyExistingAction(actionType) {
        for(uint i = 0; i < ignoreAddresses.length; i++) {
            _unignoreDistAddress(actionType, rewardType, ignoreAddresses[i]);
        }
    }  

    function _unignoreDistAddress (
        string memory actionType, 
        IRewards.RewardType rewardType, 
        address ignoreAddress
    ) internal {
        _globalDistributionConfig[actionType.keyHash()][rewardType].ignoreAddresses.remove(ignoreAddress);
    }

    function _ignoreDistAddress (
        string memory actionType, 
        IRewards.RewardType rewardType, 
        address ignoreAddress
    ) internal {
        _globalDistributionConfig[actionType.keyHash()][rewardType].ignoreAddresses.add(ignoreAddress);
    }

    function shouldIgnoreDistAddress(
        string memory actionType,
        IRewards.RewardType rewardType, 
        address ignoreAddress
    ) public view override returns (bool) {
        return  _globalDistributionConfig[actionType.keyHash()][rewardType].ignoreAddresses.contains(ignoreAddress);
    }

    function _existsActionType(string memory actionType) internal view returns (bool) {
        return bytes(_actionTypes[actionType.keyHash()]).length > 0;
    }

    function _setFallbackData(
        uint256 actionType,
        IRewards.RewardType rewardType, 
        address fallbackRewardAddress,
        RewardDirection fallbackRewardDirection
    ) internal {
        _globalDistributionConfig[actionType][rewardType].fallbackRewardAddress = fallbackRewardAddress;
        _globalDistributionConfig[actionType][rewardType].fallbackRewardDirection = fallbackRewardDirection;
    }

    function _setActionType(string memory actionType, IRewards.RewardType rewardType) internal {
        _actionHashes[rewardType].add(actionType.keyHash());
        _actionTypes[actionType.keyHash()] = actionType;
    }

    function calculateShareForAction(
        string memory actionType,
        IRewards.RewardType rewardType,
        uint256 amount
    ) external view returns (uint256 shareInWei) {
        DistributionSetting[] memory configs = _getActionConfigurations(actionType, rewardType);
        uint256 totalBPS;
        for(uint i = 0; i < configs.length; i++) {
            totalBPS += configs[i].distShare;        
        }
        return amount.calculateShare(totalBPS);
    }
    
    uint256[50] private __gap;
}