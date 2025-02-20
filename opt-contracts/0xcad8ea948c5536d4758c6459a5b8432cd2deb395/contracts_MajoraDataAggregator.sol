// // SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "./openzeppelin_contracts-upgradeable_access_AccessControlUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";
import "./openzeppelin_contracts_interfaces_IERC4626.sol";
import "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";

import {IMajoraStrategyBlock} from "./majora-finance_libraries_contracts_interfaces_IMajoraStrategyBlock.sol";
import {IMajoraHarvestBlock} from "./majora-finance_libraries_contracts_interfaces_IMajoraHarvestBlock.sol";
import {LibOracleState} from "./majora-finance_libraries_contracts_LibOracleState.sol";
import {VaultConfiguration} from "./majora-finance_libraries_contracts_VaultConfiguration.sol";
import {DataTypes} from "./majora-finance_libraries_contracts_DataTypes.sol";
import {IMajoraOperationsPaymentToken} from "./majora-finance_mopt_contracts_interfaces_IMajoraOperationsPaymentToken.sol";

import {IMajoraVault} from "./contracts_interfaces_IMajoraVault.sol";
import {IMajoraVaultFactory} from "./contracts_interfaces_IMajoraVaultFactory.sol";
import {IMajoraDataAggregator} from "./contracts_interfaces_IMajoraDataAggregator.sol";

/**
 * @title MajoraDataAggregator
 * @author Majora Development Association
 * @notice This contract serves as a data provider for operator to aggregate data about a StrategVault to operator it. 
 */
contract MajoraDataAggregator is Initializable, IMajoraDataAggregator {
    using SafeERC20 for IERC20;
    using VaultConfiguration for DataTypes.VaultConfigurationMap;
    using LibOracleState for DataTypes.OracleState;
    
    /**
     * @notice The payment token used for strategy operations 
     */
    IMajoraOperationsPaymentToken public paymentToken;

    address buffer;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the contract.
     * @param _paymentToken address of the payment token
     */
    function initialize(
        address _paymentToken,
        address _buffer
    ) public initializer {
        paymentToken = IMajoraOperationsPaymentToken(_paymentToken);
        buffer = _buffer;
    }

    /**
     * @dev Return vault's strategy configuration and informations
     * @param _vault vault address
     * @return status Information about a vault
     */
    function vaultInfo(address _vault) external returns (MajoraVaultInfo memory status) {
        IMajoraVault vault = IMajoraVault(_vault);
        IMajoraVaultFactory factory = IMajoraVaultFactory(vault.factory());

        DataTypes.VaultConfigurationMap memory config = factory.getVaultConfiguration(_vault);

        status.owner = IMajoraVault(_vault).owner();
        status.asset = IERC4626(_vault).asset();
        status.gasAvailable = _getAvailableGas(_vault);
        status.totalSupply = IERC4626(_vault).totalSupply();
        status.totalAssets = IERC4626(_vault).totalAssets();
        status.bufferAssetsAvailable = IERC20(status.asset).allowance(buffer, _vault);
        status.bufferSize = config.getBufferSize();
        status.bufferDerivation = config.getBufferDerivation();
        status.harvestFee = config.getHarvestFee();
        status.creatorFee = config.getCreatorFee();
        status.vaultIndexHighWaterMark = vault.vaultIndexHighWaterMark();
        status.minSupplyForActivation = factory.getVaultMinimalDepositLimits(_vault);
        status.currentVaultIndex = status.totalSupply == 0 ? 10000 : (status.totalAssets * 10000) / status.totalSupply;
        status.middleware = config.getMiddlewareStrategy();

        uint256 harvestBlockLength = vault.harvestBlocksLength();
        if (harvestBlockLength > 0) {
            try IMajoraDataAggregator(address(this)).getVaultHarvestExecutionInfo(_vault) returns (MajoraVaultHarvestExecutionInfo memory info) {
                status.onHarvestNativeAssetReceived = info.blocksInfo[harvestBlockLength - 1].oracleStatus.findTokenAmount(status.asset);
            } catch {
                status.onHarvestNativeAssetReceived = 0;
            }
        }
    }

    /**
     * @dev Return strategy enter execution information for a specific block   list
     * @param _oracleState initial oracle state
     * @param _strategyBlocks Block address list
     * @param _strategyBlocksParameters Block parameters list
     * @return info Simulation result on enter execution 
     */
    function emulateEnterStrategy(DataTypes.OracleState memory _oracleState, address[] memory _strategyBlocks, bytes[] memory _strategyBlocksParameters)
        external
        view
        returns (DataTypes.MajoraVaultExecutionInfo memory)
    {
        return _emulateEnterStrategy(_oracleState, _strategyBlocks, _strategyBlocksParameters);
    }

    /**
     * @dev Return strategy enter execution information for a specific block   list
     * @param _oracleState token amount
     * @param _strategyBlocks Block address list
     * @param _strategyBlocksParameters Block parameters list
     * @return info Simulation result on exit execution 
     */
    function emulateExitStrategy(DataTypes.OracleState memory _oracleState, address[] memory _strategyBlocks, bytes[] memory _strategyBlocksParameters, bool[] memory _isFinalBlock, uint256 _percent)
        external
        view
        returns (DataTypes.MajoraVaultExecutionInfo memory)
    {
        return _emulateExitStrategy(_oracleState, _strategyBlocks, _strategyBlocksParameters, _isFinalBlock,  _percent);
    }

    /**
     * @dev Return strategy enter execution information for a specific vault
     * @param _vault vault address
     * @return info A `DataTypes.MajoraVaultExecutionInfo` struct containing the updated oracle state and execution details for each block.
     */
    function getVaultStrategyEnterExecutionInfo(address _vault)
        external
        view
        returns (DataTypes.MajoraVaultExecutionInfo memory info)
    {
        address factory = IMajoraVault(_vault).factory();
        DataTypes.VaultConfigurationMap memory config = IMajoraVaultFactory(factory).getVaultConfiguration(_vault);
        
        (address[] memory _strategyBlocks, bytes[] memory _strategyBlocksParameters,,,) = IMajoraVault(_vault).getStrat();
        uint256 strategyBlocksLength = _strategyBlocks.length;

        if (strategyBlocksLength == 0) return info;

        address asset = IERC4626(_vault).asset();
        uint256 nativeTVL = IERC4626(_vault).totalAssets();
        uint256 availableAssets = IERC20(asset).balanceOf(_vault) + IERC20(asset).allowance(buffer, _vault);
        uint256 desiredBuffer = (config.getBufferSize() * nativeTVL) / 10000;

        if (desiredBuffer >= availableAssets) revert BufferIsUnderLimit();

        DataTypes.OracleState memory _oracleState;
        _oracleState.vault = _vault;
        _oracleState.tokens = new address[](1);
        _oracleState.tokensAmount = new uint256[](1);
        _oracleState.tokens[0] = asset;
        _oracleState.tokensAmount[0] = availableAssets - desiredBuffer;

        info = _emulateEnterStrategy(_oracleState, _strategyBlocks, _strategyBlocksParameters);
    }

    /**
     * @dev Return strategy exit execution information for a specific vault
     * @param _vault vault address
     * @param _percent percentage to exit
     * @return info A `DataTypes.MajoraVaultExecutionInfo` struct containing the updated oracle state and execution details for each block.
     */
    function getVaultStrategyExitExecutionInfo(address _vault, uint256 _percent)
        external
        view
        returns (DataTypes.MajoraVaultExecutionInfo memory info)
    {
        IMajoraVault vault = IMajoraVault(_vault);

        (address[] memory _strategyBlocks, bytes[] memory _strategyBlocksParameters, bool[] memory _isFinalBlock,,) = vault.getStrat();
        uint256 strategyBlocksLength = _strategyBlocks.length;

        if (strategyBlocksLength == 0) return info;


        DataTypes.OracleState memory _oracleState;
        _oracleState.vault = address(_vault);

        info = _emulateExitStrategy(_oracleState, _strategyBlocks, _strategyBlocksParameters, _isFinalBlock, _percent);
    }

    /**
     * @dev Return strategy enter execution information for a specific vault
     * @param _vault vault address
     * @param _from array of indexes to start from
     * @param _to array of indexes to end at
     * @param _oracleState Oracle state
     * @return info A `DataTypes.MajoraVaultExecutionInfo` struct containing the updated oracle state and execution details for each block.
     */
    function getPartialVaultStrategyEnterExecutionInfo(address _vault, uint256[] memory _from, uint256[] memory _to, DataTypes.OracleState memory _oracleState)
        public
        view
        returns (DataTypes.MajoraVaultExecutionInfo memory info)
    {
        IMajoraVault vault = IMajoraVault(_vault);
        (address[] memory _strategyBlocks, bytes[] memory _strategyBlocksParameters,,,) = vault.getStrat();     

        info.blocksLength = _strategyBlocks.length;
        info.startOracleStatus = _oracleState;
        if(_from.length == 0) 
            return info;
         
        info.blocksInfo = new DataTypes.StrategyBlockExecutionInfo[](
            info.blocksLength
        );

        for (uint256 i = 0; i < _from.length; i++) {
            for (uint256 j = _from[i]; j <= _to[i]; j++) {

                (bool dynParamsNeeded, DataTypes.DynamicParamsType dynParamsType, bytes memory dynParamsInfo) =
                IMajoraStrategyBlock(_strategyBlocks[j]).dynamicParamsInfo(
                    DataTypes.BlockExecutionType.ENTER, _strategyBlocksParameters[j], _oracleState, 10000
                );

                _oracleState = IMajoraStrategyBlock(_strategyBlocks[j]).oracleEnter(_oracleState, _strategyBlocksParameters[j]);
                
                info.blocksInfo[j] =  DataTypes.StrategyBlockExecutionInfo({
                    oracleStatus: _oracleState,
                    blockAddr: _strategyBlocks[j],
                    dynParamsNeeded: dynParamsNeeded,
                    dynParamsType: dynParamsType,
                    dynParamsInfo: dynParamsInfo
                });
            }
        }
    }

    /**
     * @dev Return strategy exit execution information for a specific vault
     * @param _vault vault address
     * @param _from array of indexes to start from
     * @param _to array of indexes to end at
     * @return info A `DataTypes.MajoraVaultExecutionInfo` struct containing the updated oracle state and execution details for each block.
     */
    function getPartialVaultStrategyExitExecutionInfo(address _vault, uint256[] memory _from, uint256[] memory _to)
        public
        view
        returns (DataTypes.MajoraVaultExecutionInfo memory info)
    {
        if(_from.length != _to.length) revert InputError();

        IMajoraVault vault = IMajoraVault(_vault);
        (address[] memory _strategyBlocks, bytes[] memory _strategyBlocksParameters,,,) = vault.getStrat();

        DataTypes.OracleState memory _oracleState;
        _oracleState.vault = address(_vault);

        info.startOracleStatus = _oracleState;
        info.blocksLength = _strategyBlocks.length;
        info.blocksInfo = new DataTypes.StrategyBlockExecutionInfo[](_strategyBlocks.length);

        for (uint256 i = 0; i < _from.length; i++) {
            for (uint256 j = _to[i]; j >= _from[i]; j--) {
                (bool dynParamsNeeded, DataTypes.DynamicParamsType dynParamsType, bytes memory dynParamsInfo) =
                IMajoraStrategyBlock(_strategyBlocks[j]).dynamicParamsInfo(
                    DataTypes.BlockExecutionType.EXIT, _strategyBlocksParameters[j], _oracleState,  10000
                );

                _oracleState = IMajoraStrategyBlock(_strategyBlocks[j]).oracleExit(_oracleState, _strategyBlocksParameters[j], 10000);

                info.blocksInfo[j] = DataTypes.StrategyBlockExecutionInfo({
                    oracleStatus: _oracleState,
                    blockAddr: _strategyBlocks[j],
                    dynParamsNeeded: dynParamsNeeded,
                    dynParamsType: dynParamsType,
                    dynParamsInfo: dynParamsInfo
                });
            }
        }
    }

    /**
     * @dev Return strategy harvest execution information for a specific vault
     * @param _vault vault address
     * @return info A `DataTypes.MajoraVaultHarvestExecutionInfo` struct containing the updated oracle state and execution details for each block.
     */
    function getVaultHarvestExecutionInfo(address _vault)
        external
        returns (MajoraVaultHarvestExecutionInfo memory info)
    {
        IMajoraVault vault = IMajoraVault(_vault);
        IMajoraVaultFactory factory = IMajoraVaultFactory(vault.factory());
        DataTypes.VaultConfigurationMap memory config = factory.getVaultConfiguration(_vault);

        (,,, address[] memory _harvestBlocks, bytes[] memory _harvestBlocksParameters) = vault.getStrat();
        uint256 harvestBlocksLength = vault.harvestBlocksLength();
        uint256 harvestReceivedAssets;

        if (harvestBlocksLength > 0) {
            DataTypes.OracleState memory oracleState;
            oracleState.vault = address(_vault);

            info.startOracleStatus = oracleState;
            info.blocksLength = harvestBlocksLength;
            info.blocksInfo = new StrategyBlockExecutionInfo[](harvestBlocksLength);
            for (uint256 i = 0; i < harvestBlocksLength; i++) {
                (bool dynParamsNeeded, DataTypes.DynamicParamsType dynParamsType, bytes memory dynParamsInfo) =
                IMajoraHarvestBlock(_harvestBlocks[i]).dynamicParamsInfo(
                    DataTypes.BlockExecutionType.HARVEST, _harvestBlocksParameters[i], oracleState, 10000
                );

                oracleState = IMajoraHarvestBlock(_harvestBlocks[i]).oracleHarvest(oracleState, _harvestBlocksParameters[i]);

                info.blocksInfo[i] = StrategyBlockExecutionInfo({
                    oracleStatus: oracleState,
                    blockAddr: _harvestBlocks[i],
                    dynParamsNeeded: dynParamsNeeded,
                    dynParamsType: dynParamsType,
                    dynParamsInfo: dynParamsInfo
                });
            }

            harvestReceivedAssets = oracleState.findTokenAmount(IERC4626(_vault).asset());
        }
        
        uint256 totalSupply = IERC4626(_vault).totalSupply();
        uint256 vaultIndexHighWaterMark = vault.vaultIndexHighWaterMark();
        uint256 assetsAfterHarvest = IERC4626(_vault).totalAssets() + harvestReceivedAssets;
        uint256 vaultIndexAfterHarvest = assetsAfterHarvest * 10000 / totalSupply;

        uint256 receivedAmount;
        {
            uint256 taxValueCumulated = vault.taxValueCumulated();

            uint256 totalFee = config.getProtocolFee() +
                config.getCreatorFee() +
                config.getHarvestFee();

            uint256 weightedHarvestFee = config.getHarvestFee() * 10000 / totalFee;
      
            receivedAmount = (taxValueCumulated * weightedHarvestFee) / 10000;

            if(vaultIndexAfterHarvest > vaultIndexHighWaterMark) {
                uint256 addedFees = ((totalSupply * (vaultIndexAfterHarvest - vaultIndexHighWaterMark) * totalFee) / 100000000);
                receivedAmount += addedFees * weightedHarvestFee / 10000;
            }
            
        }
        info.receivedAmount = receivedAmount;
    }

    /**
     * @dev Return strategy exit execution information for a specific vault
     * @param _vault vault address
     * @param _shares number of shares yo withdraw
     * @return info A `DataTypes.MajoraVaultExecutionInfo` struct containing the updated oracle state and execution details for each block.
     */
    function getVaultWithdrawalRebalanceExecutionInfo(address _vault, uint256 _shares)
        external
        view
        returns (DataTypes.MajoraVaultExecutionInfo memory info)
    {
        IMajoraVault vault = IMajoraVault(_vault);
        DataTypes.VaultConfigurationMap memory config = IMajoraVaultFactory(vault.factory()).getVaultConfiguration(_vault);
        
        (address[] memory _strategyBlocks, bytes[] memory _strategyBlocksParameters, bool[] memory _isFinalBlock,,) = vault.getStrat();
        
        uint256 receivedAmount = ((_shares * IERC4626(_vault).totalAssets()) / IERC4626(_vault).totalSupply());
        uint256 withdrawalPercent;
        {
            uint256 remainingAssets = IERC4626(_vault).totalAssets() - receivedAmount;
            // uint256 finalBufferAmount = config.getBufferSize() * remainingAssets / 10000;
            uint256 finalAmountInStrategy = (10000 - config.getBufferSize()) * remainingAssets / 10000;
            uint256 currentAmountInStrategy = IERC4626(_vault).totalAssets() * (10000 - config.getBufferSize() ) / 10000;
            withdrawalPercent = 10000 - (finalAmountInStrategy * 10000 / currentAmountInStrategy);
        }

        DataTypes.OracleState memory oracleState;
        oracleState.vault = address(_vault);

        info.startOracleStatus = oracleState;
        info.blocksLength = _strategyBlocks.length;
        info.blocksInfo = new DataTypes.StrategyBlockExecutionInfo[](
            _strategyBlocks.length
        );

        info = _emulateExitStrategy(
            oracleState, 
            _strategyBlocks, 
            _strategyBlocksParameters,
            _isFinalBlock,
            withdrawalPercent
        );
    }    

    
    /**
     * @dev Calculates the total available gas for a given vault by summing the vault's balance and sponsored amounts.
     * @param _vault The address of the vault for which to calculate available gas.
     * @return availableGas The total amount of gas available to the vault.
     */
    function _getAvailableGas(address _vault) internal view returns (uint256 availableGas) {
        availableGas = IERC20(address(paymentToken)).balanceOf(_vault);
        (, uint256[] memory amounts) = paymentToken.getSponsors(_vault);
        for (uint256 i = 0; i < amounts.length; i++) {
            availableGas += amounts[i];
        }
    }
    /**
     * @dev Simulates the execution of entering a strategy for a vault, updating the oracle state and gathering dynamic parameters for each strategy block.
     * @param _oracleState The initial oracle state before entering the strategy.
     * @param _strategyBlocks An array of addresses representing the strategy blocks to be executed.
     * @param _strategyBlocksParameters An array of bytes representing the parameters for each strategy block.
     * @return info A `DataTypes.MajoraVaultExecutionInfo` struct containing the updated oracle state and execution details for each block.
     */
    function _emulateEnterStrategy(
        DataTypes.OracleState memory _oracleState, 
        address[] memory _strategyBlocks, 
        bytes[] memory _strategyBlocksParameters
    )
        internal
        view
        returns (DataTypes.MajoraVaultExecutionInfo memory info)
    {
        uint256 strategyBlocksLength = _strategyBlocks.length;

        // Return empty info if there are no strategy blocks.
        if (strategyBlocksLength == 0) return info;

        // Initialize the return structure with the starting oracle state and the number of blocks.
        info.startOracleStatus = _oracleState;
        info.blocksLength = strategyBlocksLength;
        info.blocksInfo = new DataTypes.StrategyBlockExecutionInfo[](strategyBlocksLength);

        // Iterate through each strategy block to simulate its execution.
        for (uint256 i = 0; i < strategyBlocksLength; i++) {
            // Retrieve dynamic parameters needed for the block execution.
            (bool dynParamsNeeded, DataTypes.DynamicParamsType dynParamsType, bytes memory dynParamsInfo) =
                IMajoraStrategyBlock(_strategyBlocks[i]).dynamicParamsInfo(
                    DataTypes.BlockExecutionType.ENTER, 
                    _strategyBlocksParameters[i], 
                    _oracleState, 
                    10000
                );

            // Update the oracle state based on the block's execution.
            _oracleState = IMajoraStrategyBlock(_strategyBlocks[i]).oracleEnter(_oracleState, _strategyBlocksParameters[i]);

            // Store the execution details for the block.
            info.blocksInfo[i] = DataTypes.StrategyBlockExecutionInfo({
                oracleStatus: _oracleState,
                blockAddr: _strategyBlocks[i],
                dynParamsNeeded: dynParamsNeeded,
                dynParamsType: dynParamsType,
                dynParamsInfo: dynParamsInfo
            });
        }
    }

    /**
     * @dev Simulates the execution of exiting a strategy for a vault, updating the oracle state and gathering dynamic parameters for each strategy block in reverse order.
     * @param _oracleState The initial oracle state before exiting the strategy.
     * @param _strategyBlocks An array of addresses representing the strategy blocks to be executed in reverse.
     * @param _strategyBlocksParameters An array of bytes representing the parameters for each strategy block.
     * @param _isFinalBlock An array of booleans indicating if the corresponding block is the final block in the strategy.
     * @param _percent The percentage of the strategy to exit, applied to final blocks or all blocks if only one exists.
     * @return info A `DataTypes.MajoraVaultExecutionInfo` struct containing the updated oracle state and execution details for each block.
     */
    function _emulateExitStrategy(
        DataTypes.OracleState memory _oracleState, 
        address[] memory _strategyBlocks, 
        bytes[] memory _strategyBlocksParameters,
        bool[] memory _isFinalBlock,
        uint256 _percent
    )
        internal
        view
        returns (DataTypes.MajoraVaultExecutionInfo memory info)
    {
        // Initialize the return structure with the starting oracle state and the number of blocks.
        info.startOracleStatus = _oracleState;
        info.blocksLength = _strategyBlocks.length;
        info.blocksInfo = new DataTypes.StrategyBlockExecutionInfo[](
            info.blocksLength
        );

        // Handle single block strategy separately for simplicity.
        if (info.blocksLength == 1) {
            // Retrieve dynamic parameters and update oracle state for the single block.
            (bool dynParamsNeeded, DataTypes.DynamicParamsType dynParamsType, bytes memory dynParamsInfo) =
            IMajoraStrategyBlock(_strategyBlocks[0]).dynamicParamsInfo(
                DataTypes.BlockExecutionType.EXIT, _strategyBlocksParameters[0], _oracleState, _percent
            );

            _oracleState = IMajoraStrategyBlock(_strategyBlocks[0]).oracleExit(
                _oracleState,
                _strategyBlocksParameters[0],
                _isFinalBlock[0] ? _percent : 10000
            );

            // Store the execution details for the block.
            info.blocksInfo[0] = DataTypes.StrategyBlockExecutionInfo({
                oracleStatus: _oracleState,
                blockAddr: _strategyBlocks[0],
                dynParamsNeeded: dynParamsNeeded,
                dynParamsType: dynParamsType,
                dynParamsInfo: dynParamsInfo
            });
        } else {
            // Process multiple blocks in reverse order.
            uint256 revertedIndex = info.blocksLength - 1;
            for (uint256 i = 0; i < info.blocksLength; i++) {
                uint256 index = revertedIndex - i;

                // Retrieve dynamic parameters and update oracle state for each block.
                (bool dynParamsNeeded, DataTypes.DynamicParamsType dynParamsType, bytes memory dynParamsInfo) =
                IMajoraStrategyBlock(_strategyBlocks[index]).dynamicParamsInfo(
                    DataTypes.BlockExecutionType.EXIT, _strategyBlocksParameters[index], _oracleState, _isFinalBlock[index] ? _percent : 10000
                );

                _oracleState = IMajoraStrategyBlock(_strategyBlocks[index]).oracleExit(
                    _oracleState, _strategyBlocksParameters[index], _isFinalBlock[index] ? _percent : 10000);

                // Store the execution details for each block.
                info.blocksInfo[index] = DataTypes.StrategyBlockExecutionInfo({
                    oracleStatus: _oracleState,
                    blockAddr: _strategyBlocks[index],
                    dynParamsNeeded: dynParamsNeeded,
                    dynParamsType: dynParamsType,
                    dynParamsInfo: dynParamsInfo
                });
            }
        }
    }
}