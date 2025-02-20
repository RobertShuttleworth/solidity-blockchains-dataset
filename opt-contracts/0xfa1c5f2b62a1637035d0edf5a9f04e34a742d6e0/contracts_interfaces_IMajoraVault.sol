// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./openzeppelin_contracts_token_ERC20_extensions_IERC20Metadata.sol";
import "./openzeppelin_contracts_interfaces_IERC4626.sol";
import "./openzeppelin_contracts_token_ERC20_extensions_IERC20Permit.sol";
import "./openzeppelin_contracts_access_Ownable.sol";
import "./openzeppelin_contracts_utils_Strings.sol";
import {DataTypes} from "./majora-finance_libraries_contracts_DataTypes.sol";



interface IMajoraVault {

    enum MajoraVaultUpdateType {
        Transfer,
        StrategyInitialized
    }

    enum MajoraVaultSettings {
        TimelockParams,
        DepositLimits,
        HoldingParams,
        EditWhitelist,
        FeeParams,
        BufferParams
    }

    /// @notice Error triggered on operator proxy reserved function when the sender is not the proxy
    error NotOperator();

    /**
     * @dev Error thrown when the caller is not the factory contract.
     */
    error NotFactory();

    /**
     * @dev Error thrown when the caller is not the owner.
     */
    error NotOwner();

    /**
     * @dev Error thrown when the minimum deposit amount is not reached.
     */
    error MinDepositNotReached();

    /**
     * @dev Error thrown when the user's maximum deposit amount is reached.
     */
    error MaxUserDepositReached();

    /**
     * @dev Error thrown when the vault's maximum deposit amount is reached.
     */
    error MaxVaultDepositReached();

    /**
     * @dev Error thrown when the timelock for withdrawal has not been reached.
     */
    error TimelockNotReached();

    /**
     * @dev Error thrown when the required hold amount is not reached.
     */
    error HoldAmountNotReached();

    /**
     * @dev Error thrown when the caller is not whitelisted.
     */
    error NotWhitelisted();

    /**
     * @notice Error triggered on position manager reserved function when the sender is not a position manager
     */
    error NotPositionManager();

    /**
     * @notice Error triggered on strategy related function when strategy isn't set
     */
    error StrategyNotInitialized();

    /**
     * @notice Error triggered when you try to setup the vault strategy a second time
     */
    error StrategyAlreadyInitialized();

    /**
     * @notice Error triggered when you try to deposit more than the maximum of assets depositable
     */
    error DepositMoreThanMax();

    /**
     * @notice Error triggered when you try to withdraw more than the maximum of assets withdrawable
     */
    error WithdrawMoreThanMax();

    /**
     * @notice Error triggered when you try to include not approved block in a vault strategy
     */
    error BlockListNotValid();

    /**
     * @notice Error triggered when you try to deposit and the amount of share is 0
     */
    error NoSharesMinted();

    /**
     * @notice Error triggered when you try to deposit and the amount of share is 0
     */
    error PreventRoundingLoss();

    /**
     * @notice Error triggered when there is an issue during the withdrawal rebalance
     */
    error WithdrawalRebalanceIssue();

    /**
     * @dev Error thrown when inputs arrays length are different.
     */
    error DynamicParamsArrayLengthsMismatch();

    /**
     * @dev Emitted when a MajoraVault is updated.
     * @param update The type of update being performed.
     * @param data Data relevant to the update.
     */
    event MajoraVaultUpdate(MajoraVaultUpdateType indexed update, bytes data);

    /**
     * @dev Initalize function call by the factory on deployment
     * @param _erc3525 ERC3525 address
     * @param _name vault name
     * @param _symbol vault symbol
     * @param _asset native asset
     */
    function initialize(
        address _erc3525,
        string memory _name,
        string memory _symbol,
        address _asset
    ) external;

    /**
     * @dev Set the strategy blocks for the vault. Only callable by the factory.
     * @param _positionManagers Array of position managers.
     * @param _stratBlocks Array of strategy blocks.
     * @param _stratBlocksParameters Array of strategy block parameters.
     * @param _isFinalBlock Array of boolean indicating if a block is a final block..
     * @param _harvestBlocks Array of harvest blocks.
     * @param _harvestBlocksParameters Array of harvest block parameters.
     */
    function setStrat(
        address[] memory _positionManagers,
        address[] memory _stratBlocks,
        bytes[] memory _stratBlocksParameters,
        bool[] memory _isFinalBlock,
        address[] memory _harvestBlocks,
        bytes[] memory _harvestBlocksParameters
    ) external;


    /**
     * @dev Get the strategy blocks for the vault.
     * @return _strategyBlocks Array of strategy blocks addresses.
     * @return _strategyBlocksParameters Array of strategy blocks parameters.
     * @return _isFinalBlock Array of boolean indicating if a block is a final block.
     * @return _harvestBlocks Array of harvest blocks addresses.
     * @return _harvestBlocksParameters Array of harvest blocks parameters.
     */
    function getStrat()
        external
        view
        returns (
            address[] memory _strategyBlocks,
            bytes[] memory _strategyBlocksParameters,
            bool[] memory _isFinalBlock,
            address[] memory _harvestBlocks,
            bytes[] memory _harvestBlocksParameters
        );

    /**
     * @notice return current owner of the vault
     * @return Owner of the vault
     */
    function owner() external view returns (address);
    
    /**
     * @notice return last harvest index
     * @return Last harvest index
     */
    function vaultIndexHighWaterMark() external view returns (uint256);
    
    /**
     * @notice Get pending vault fees
     * @return pending vault fees
     */
    function taxValueCumulated() external view returns (uint256);

    /**
     * @notice return length of the strategy blocks
     * @return Length of the strategy blocks
     */
    function strategyBlocksLength() external view returns (uint256);

    /**
     * @notice return length of the harvest blocks
     * @return Length of the harvest blocks
     */
    function harvestBlocksLength() external view returns (uint256);

    /**
     * @notice return factory address
     * @return factory address
     */
    function factory() external view returns (address);

    /**
     * @dev Function to execute the buffer rebalancing process. Only callable by the operator proxy.
     * @param _dynParamsIndex The array of dynamic parameter indices for strategy
     * @param _dynParams The array of dynamic parameters for strategy
     */
    function rebalance(
        uint256[] memory _dynParamsIndex,
        bytes[] memory _dynParams
    ) external;

    /**
     * @dev Internal function to stop the strategy, harvest fees, and perform rebalancing. Only callable by the operator proxy.
     * @param _dynParamsIndex The array of dynamic parameter indices.
     * @param _dynParams The array of dynamic parameter values.
     */
    function stopStrategy(uint256[] memory _dynParamsIndex, bytes[] memory _dynParams) external;

    /**
     * @dev Internal function to harvest strategy rewards. Only callable by the operator proxy.
     * @param _dynParamsIndex The array of dynamic parameter indices.
     * @param _dynParams The array of dynamic parameter values.
     */
    function harvest(uint256[] memory _dynParamsIndex, bytes[] memory _dynParams) external;

    /**
     * @dev Function to perform a withdrawal rebalance. Only callable by the operator proxy.
     * @param _user The user address requesting the withdrawal.
     * @param _amount The amount of shares to be withdrawn.
     * @param _dynParamsIndexExit The array of dynamic parameter indices for strategy exit.
     * @param _dynParamsExit The array of dynamic parameters for strategy exit.
     */
    function withdrawalRebalance(
        address _user,
        uint256 _amount,
        uint256[] memory _dynParamsIndexExit,
        bytes[] memory _dynParamsExit
    ) external returns (uint256);

    /**
     * @notice Executes partial strategy enter for a given range of strategy blocks. Only callable by a position manager owned by the vault.
     * @dev Executes the strategy enter function for a subset of strategy blocks, starting from `_from` index.
     *      The `_dynParamsIndex` array and `_dynParams` array provide dynamic parameters for the strategy blocks.
     * @param _isEnter Boolean indicating if the strategy blocks are entering or exiting the vault.
     * @param _neededTokenToRebalance The token needed for the position manager to rebalance.
     * @param _from The starting index of the strategy blocks.
     * @param _to The ending index of the strategy blocks.
     * @param _dynParamsIndex The array of dynamic parameter indices.
     * @param _dynParams The array of dynamic parameter values.
     * @param _dynParams The array of dynamic parameter values.
     */
    function partialStrategyExecution(
        bool _isEnter,
        address _neededTokenToRebalance,
        uint256[] memory _from, 
        uint256[] memory _to, 
        uint256[] memory _dynParamsIndex, 
        bytes[] memory _dynParams
    ) external;    
}