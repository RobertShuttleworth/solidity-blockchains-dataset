// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {IERC20} from "./openzeppelin_contracts_interfaces_IERC20.sol";
import {ERC20Upgradeable} from "./openzeppelin_contracts-upgradeable_token_ERC20_ERC20Upgradeable.sol";
import {ERC20PermitUpgradeable} from "./openzeppelin_contracts-upgradeable_token_ERC20_extensions_ERC20PermitUpgradeable.sol";
import {SafeERC20} from "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";
import {ReentrancyGuard} from "./openzeppelin_contracts_utils_ReentrancyGuard.sol";
import {Math} from "./openzeppelin_contracts_utils_math_Math.sol";

import {LibBlock} from "./majora-finance_libraries_contracts_LibBlock.sol";
import {DataTypes} from "./majora-finance_libraries_contracts_DataTypes.sol";
import {VaultConfiguration} from "./majora-finance_libraries_contracts_VaultConfiguration.sol";
import {LibOracleState} from "./majora-finance_libraries_contracts_LibOracleState.sol";
import {IMajoraStrategyBlock} from "./majora-finance_libraries_contracts_interfaces_IMajoraStrategyBlock.sol";

import {IMajoraAddressesProvider} from "./majora-finance_access-manager_contracts_interfaces_IMajoraAddressesProvider.sol";
import {IMajoraAccessManager} from "./majora-finance_access-manager_contracts_interfaces_IMajoraAccessManager.sol";

import {IMajoraVaultFactory} from "./contracts_interfaces_IMajoraVaultFactory.sol";
import {IMajoraBlockRegistry} from "./contracts_interfaces_IMajoraBlockRegistry.sol";
import {IMajoraERC3525} from "./contracts_interfaces_IMajoraERC3525.sol";
import {IMajoraVault} from "./contracts_interfaces_IMajoraVault.sol";
import {IMajoraAssetBuffer} from "./contracts_interfaces_IMajoraAssetBuffer.sol";

import {MajoraERC4626Upgradeable} from "./contracts_MajoraERC4626Upgradeable.sol";

/**
 * @title MajoraVault
 * @author Majora Development Association
 * @notice Majora ERC4626 Vault implementation
 */
contract MajoraVault is
    ERC20Upgradeable,
    ERC20PermitUpgradeable,
    MajoraERC4626Upgradeable,
    ReentrancyGuard,
    IMajoraVault
{
    using Math for uint256;
    using SafeERC20 for IERC20;
    using VaultConfiguration for DataTypes.VaultConfigurationMap;
    using LibOracleState for DataTypes.OracleState;

    /**
     * @notice The address of the buffer contract
     */
    address private immutable buffer;

    /**
     * @notice The address of the operator
     */
    IMajoraAddressesProvider private immutable addressProvider;

    /**
     * @notice The address of the operator
     */
    IMajoraAccessManager private immutable accessManager;

    /**
     * @notice Majora ERC3525 which define vault ownership
     */
    address public erc3525;

    /**
     * @notice Majora vault factory address
     */
    address public factory;

    /**
     * @notice Indicates whether the strategy has been initialized
     */
    bool public stratInitialized;

    /**
     * @notice The native Total Value Locked in the vault
     */
    uint256 private nativeTVL;

    /**
     * @notice The timestamp of the last native TVL update
     */
    uint256 private lastNativeTVLUpdate;

    /**
     * @notice Mapping of strategy block numbers to their corresponding addresses
     */
    mapping(uint256 => address) private strategyBlocks;

    /**
     * @notice Mapping of harvest block numbers to their corresponding addresses
     */
    mapping(uint256 => address) private harvestBlocks;

    /**
     * @notice Mapping of strategy block numbers to their corresponding addresses
     */
    uint256 public strategyBlocksLength;

    /**
     * @notice Mapping of harvest block numbers to their corresponding addresses
     */
    uint256 public harvestBlocksLength;

    /**
     * @notice Mapping to check if an address is an owned position manager
     */
    mapping(address => bool) private isOwnedPositionManager;

    /**
     * @notice Indicates whether the vault is live
     */
    bool public isLive;

    /**
     * @notice Array of boolean indicating if a block is a final block.
     */
    bool[] private isFinalBlock;

    /**
     * @notice Last index of harvest operation
     */
    uint256 public vaultIndexHighWaterMark;

    /**
     * @notice cumulated taxs
     */
    uint256 public taxValueCumulated;

    /**
     * @notice User Timelocks
     */
    mapping(address => uint256) public timelocks;


    /**
     * @notice Only operator proxy modifier 
     */
    modifier onlyOperator() {
        if (msg.sender != addressProvider.operatorProxy()) revert NotOperator();
        _;
    }

    /**
     * @notice Only vault factory modifier 
     */
    modifier onlyFactory() {
        if (msg.sender != factory) revert NotFactory();
        _;
    }

    /**
     * @notice Only position managers modifier 
     */
    modifier onlyPositionManager() {
        if (!isOwnedPositionManager[msg.sender]) revert NotPositionManager();
        _;
    }

    /**
     * @notice update internal vault index
     */
    modifier updateIndex() {
        _updateIndex();
        _;
    }

    /**
     * @dev Set all addresses as immutable
     */
    constructor(
        address _buffer, 
        address _addressProvider,
        address _accessManager
    ) {
        buffer = _buffer;
        addressProvider = IMajoraAddressesProvider(_addressProvider);
        accessManager = IMajoraAccessManager(_accessManager);
        _disableInitializers();
    }

    /**
     * Externals Functions
     */

    /**
     * ---------------------- Initialization logic ----------------------
     */

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
    ) external initializer {
        __ERC20_init(_name, _symbol);
        __ERC20Permit_init(_name);
        __ERC4626_init(IERC20(_asset), buffer);

        erc3525 = _erc3525;
        factory = msg.sender;
        vaultIndexHighWaterMark = 10000;

        IERC20(_asset).safeIncreaseAllowance(buffer, type(uint256).max);
    }

    /**
     * ---------------------- ERC4626 logic ----------------------
     */

    /**
     * @dev Set the decimal value for the vault token.
     * @return The number of decimals for the vault token.
     */
    function decimals() public view virtual override(MajoraERC4626Upgradeable, ERC20Upgradeable) returns (uint8) {
        return MajoraERC4626Upgradeable.decimals();
    }

    /**
     * @dev Get the total assets (TVL) of the vault.
     * @return The total assets (TVL) of the vault.
     */
    function totalAssets() public view virtual override returns (uint256) {
        uint256 nativeTvl = _fetchNativeTVL();
        return nativeTvl < taxValueCumulated ? 0 : nativeTvl - taxValueCumulated;
    }

    /**
     * @dev Deposit assets into the vault and mint shares to the receiver.
     * @param assets The amount of assets to deposit.
     * @param receiver The address to receive the minted shares.
     * @return The amount of shares minted.
     */
    function deposit(uint256 assets,  address receiver) public virtual override nonReentrant updateIndex returns (uint256) {
        if (!stratInitialized) revert StrategyNotInitialized();

        address assetProvider = 
            msg.sender != factory ?
            msg.sender : addressProvider.userInteractions();

        _executeHooks(DataTypes.BlockExecutionType.ENTER);

        uint256 shares = previewDeposit(assets);

        _deposit(assetProvider, receiver, assets, shares);

        nativeTVL += assets;

        //Prevent user to loss on deposit in case of donation attack
        uint256 theoricalReturn = previewRedeem(shares);
        if(theoricalReturn < assets - (assets / 10000)) revert PreventRoundingLoss();
        if (shares == 0) revert NoSharesMinted();

        uint256 tSupply = totalSupply();
        uint256 currentVaultIndex = (totalAssets() * 10000) / tSupply;
        if(vaultIndexHighWaterMark > currentVaultIndex) {
            uint256 mintedSharesRatio = shares * 10000 / tSupply;
            vaultIndexHighWaterMark -= (vaultIndexHighWaterMark - currentVaultIndex) * mintedSharesRatio / 10000;
        }
        
        return shares;
    }

    /**
     * @dev Mint shares to the receiver.
     * @param shares The amount of shares to mint.
     * @param receiver The address to receive the minted shares.
     * @return The amount of assets minted.
     */
    function mint(uint256 shares, address receiver) public virtual override nonReentrant updateIndex returns (uint256) {
        if (!stratInitialized) revert StrategyNotInitialized();

        _executeHooks(DataTypes.BlockExecutionType.ENTER);

        address sender = _msgSender();
        uint256 assets = previewMint(shares);

        _deposit(sender, receiver, assets, shares);

        nativeTVL += assets;

        uint256 tSupply = totalSupply();
        uint256 currentVaultIndex = (totalAssets() * 10000) / tSupply;
        if(vaultIndexHighWaterMark > currentVaultIndex) {
            uint256 mintedSharesRatio = shares * 10000 / tSupply;
            vaultIndexHighWaterMark -= (vaultIndexHighWaterMark - currentVaultIndex) * mintedSharesRatio / 10000;
        }

        return assets;
    }

    /**
     * @dev Withdraw assets from the vault and burn the corresponding shares.
     * @param _assets The amount of assets to withdraw.
     * @param _receiver The address to receive the withdrawn assets.
     * @param __owner The owner of the shares being burned.
     * @return The amount of shares burned.
     */
    function withdraw(uint256 _assets, address _receiver, address __owner)
        public 
        virtual 
        override 
        nonReentrant
        updateIndex
        returns (uint256) 
    {
        address sender = _msgSender();
        _executeHooks(DataTypes.BlockExecutionType.EXIT);
        if (_assets > maxWithdraw(__owner)) revert WithdrawMoreThanMax();

        uint256 shares = previewWithdraw(_assets);
        _withdraw(sender, _receiver, __owner, _assets, shares);

        nativeTVL -= _assets;
        return shares;
    }

    /**
     * @dev Redeem shares for assets from the vault.
     * @param _shares The amount of shares to redeem.
     * @param _receiver The address to receive the redeemed assets.
     * @param __owner The owner of the shares being redeemed.
     * @return The amount of assets redeemed.
     */
    function redeem(uint256 _shares, address _receiver, address __owner) 
        public 
        virtual 
        override 
        nonReentrant 
        updateIndex 
        returns (uint256) 
    {

        address sender = _msgSender();
        _executeHooks(DataTypes.BlockExecutionType.EXIT);
        if (_shares > maxRedeem(__owner)) revert WithdrawMoreThanMax();

        uint256 assets = previewRedeem(_shares);
        _withdraw(sender, _receiver, __owner, assets, _shares);

        nativeTVL -= assets;

        return assets;
    }

    /**
     * @dev See {IERC4626-maxDeposit}.
     */
    function maxDeposit(address _user) public view override returns (uint256) {
        uint256 _maxMint = maxMint(_user);
        return convertToAssets(_maxMint);
    }

    /**
     * @dev See {IERC4626-maxMint}.
     */
    function maxMint(address _user) public view override returns (uint256) {
        DataTypes.VaultConfigurationMap memory config = _getConfiguration();
        uint256 mode = config.getLimitMode();

        //No limit set
        if (mode == 0) return type(uint256).max;

        uint256 maxVaultMintLimit = type(uint256).max;
        uint256 maxUserMintLimit = type(uint256).max;

        (, uint256 maxUserDeposit,, uint256 maxVaultDeposit) = _getVaultDepositLimits();
        uint256 userDeposited = balanceOf(_user);

        //Vault max limit set
        if (mode >= 4) {
            maxVaultMintLimit = maxVaultDeposit - totalSupply();
        }

        //User max limit set
        if (mode % 4 > 1) {
            maxUserMintLimit = maxUserDeposit - userDeposited;
        }

        return maxVaultMintLimit <= maxUserMintLimit ? maxVaultMintLimit : maxUserMintLimit;
    }

    /**
     * @dev See {IERC4626-maxWithdraw}.
     */
    function maxWithdraw(address __owner) public view override returns (uint256) {
        uint256 assetsInBuffer = _getBufferAllowance();
        uint256 maxWithdrawal = convertToAssets(balanceOf(__owner));
        return assetsInBuffer < maxWithdrawal ? assetsInBuffer : maxWithdrawal;
    }

    /**
     * @dev See {IERC4626-maxRedeem}.
     */
    function maxRedeem(address __owner) public view override returns (uint256) {
        uint256 assetsInBuffer = _getBufferAllowance();
        uint256 bufferShares = convertToShares(assetsInBuffer);
        uint256 ownerBal = balanceOf(__owner);
        return bufferShares < balanceOf(__owner) ? bufferShares : ownerBal;
    }

    /**
     * ---------------------- Majora logic ----------------------
     */

    /**
     * @notice return current owner of the vault
     * @return Owner of the vault
     */
    function owner() external view returns (address) {
        return _owner();
    }

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
    ) external onlyFactory {
        if (stratInitialized) revert StrategyAlreadyInitialized();

        IMajoraBlockRegistry r = IMajoraBlockRegistry(addressProvider.blockRegistry());

        uint256 _blocksToVerifyCurrentIndex = 0;
        uint256 _blocksToVerifyLength = _stratBlocks.length + _harvestBlocks.length;
        address[] memory _blocksToVerify = new address[](_blocksToVerifyLength);

        strategyBlocksLength = _stratBlocks.length;
        harvestBlocksLength = _harvestBlocks.length;

        for (uint256 i = 0; i < _stratBlocks.length; i++) {
            strategyBlocks[i] = _stratBlocks[i];
            _blocksToVerify[_blocksToVerifyCurrentIndex] = _stratBlocks[i];
            _blocksToVerifyCurrentIndex = _blocksToVerifyCurrentIndex + 1;

            isFinalBlock.push(_isFinalBlock[i]);

            LibBlock.setupStrategyBlockData(i, _stratBlocksParameters[i]);
        }

        for (uint256 i = 0; i < _harvestBlocks.length; i++) {
            harvestBlocks[i] = _harvestBlocks[i];
            _blocksToVerify[_blocksToVerifyCurrentIndex] = _harvestBlocks[i];
            _blocksToVerifyCurrentIndex = _blocksToVerifyCurrentIndex + 1;

            LibBlock.setupHarvestBlockData(i, _harvestBlocksParameters[i]);
        }

        if (!r.blocksValid(_blocksToVerify)) revert BlockListNotValid();

        for (uint256 i = 0; i < _positionManagers.length; i++) {
            isOwnedPositionManager[_positionManagers[i]] = true;
        }

        stratInitialized = true;

        emit MajoraVaultUpdate(
            MajoraVaultUpdateType.StrategyInitialized,
            abi.encode(_stratBlocks, _stratBlocksParameters, _harvestBlocks, _harvestBlocksParameters)
        );
    }

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
        )
    {
        uint256 strategyLength = strategyBlocksLength;
        uint256 harvestLength = harvestBlocksLength;

        _strategyBlocks = new address[](strategyLength);
        _strategyBlocksParameters = new bytes[](strategyLength);
        _isFinalBlock = new bool[](strategyLength);
        _harvestBlocks = new address[](harvestLength);
        _harvestBlocksParameters = new bytes[](harvestLength);

        for (uint256 i = 0; i < strategyLength; i++) {
            _strategyBlocks[i] = strategyBlocks[i];
            _isFinalBlock[i] = isFinalBlock[i];
            _strategyBlocksParameters[i] = LibBlock.getStrategyStorageByIndex(i);
        }

        for (uint256 i = 0; i < harvestLength; i++) {
            _harvestBlocks[i] = harvestBlocks[i];
            _harvestBlocksParameters[i] = LibBlock.getHarvestStorageByIndex(i);
        }
    }

    /**
     * @dev Function to execute the buffer rebalancing process. Only callable by the operator proxy.
     * @param _dynParamsIndex The array of dynamic parameter indices to rebalance strategy
     * @param _dynParams The array of dynamic parameters to rebalance strategy
     */
    function rebalance(
        uint256[] memory _dynParamsIndex,
        bytes[] memory _dynParams
    ) external onlyOperator {
        _rebalance(_dynParamsIndex, _dynParams);
    }
    

    /**
     * @dev Internal function to stop the strategy, harvest fees, and perform rebalancing. Only callable by the operator proxy.
     * @param _dynParamsIndex The array of dynamic parameter indices.
     * @param _dynParams The array of dynamic parameter values.
     */
    function stopStrategy(uint256[] memory _dynParamsIndex, bytes[] memory _dynParams) external onlyOperator {
        _storeDynamicParams(_dynParamsIndex, _dynParams);
        _exitStrategy(10000);
        _sendVaultAssetsInBuffer();
        _updateIndex();
        _purgeDynamicParams(_dynParamsIndex);

        isLive = false;
    }

    /**
     * @dev Internal function to harvest strategy rewards. Only callable by the operator proxy.
     * @param _dynParamsIndex The array of dynamic parameter indices.
     * @param _dynParams The array of dynamic parameter values.
     */
    function harvest(uint256[] memory _dynParamsIndex, bytes[] memory _dynParams) external onlyOperator {
        _storeDynamicParams(_dynParamsIndex, _dynParams);

        DataTypes.VaultConfigurationMap memory config = _getConfiguration();
        _harvestStrategy();
        _sendVaultAssetsInBuffer();
        _updateIndex();        

        uint256 distributedValue = taxValueCumulated;
        IERC20 _asset = IERC20(asset());
        uint256 bufferAllowance = _getBufferAllowance();

        // Avoid harvest stuck if buffer is too low
        if(bufferAllowance < distributedValue) {
            distributedValue = bufferAllowance;
        }

        uint256 totalFee = config.getProtocolFee() +
            config.getCreatorFee() +
            config.getHarvestFee();

        uint256 weightedCreatorFee = config.getCreatorFee() * 10000 / totalFee;
        uint256 weightedHarvestFee= config.getHarvestFee() * 10000 / totalFee;
        uint256 weightedProtocolFee = config.getProtocolFee() * 10000 / totalFee;

        //creatorFee
        uint256 creatorFeeAmount = (distributedValue * weightedCreatorFee) / 10000;
        _asset.safeTransferFrom(buffer, address(this), creatorFeeAmount);
        _asset.safeIncreaseAllowance(erc3525, creatorFeeAmount);
        IMajoraERC3525(erc3525).addRewards(creatorFeeAmount);

        //harvestFee
        _asset.safeTransferFrom(
            buffer,
            msg.sender,
            (distributedValue * weightedHarvestFee) / 10000
        );

        //protocolFee
        _asset.safeTransferFrom(
            buffer,
            addressProvider.feeCollector(),
            (distributedValue * weightedProtocolFee) / 10000
        );

        nativeTVL -= distributedValue;
        taxValueCumulated -= distributedValue;
        _purgeDynamicParams(_dynParamsIndex);
    }

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
    ) external onlyOperator updateIndex returns (uint256 totalWithdraw) {
        _storeDynamicParams(_dynParamsIndexExit, _dynParamsExit);

        /**
         * Exit strategy funds
         */
        IERC20 _asset = IERC20(asset());

        uint256 withdrawPercent = (_amount * 10000) / totalSupply();
        _executeHooks(DataTypes.BlockExecutionType.EXIT);
        _exitStrategy(withdrawPercent);
        uint256 totalBufferWithdraw = withdrawPercent * _getBufferAllowance() / 10000;
        _asset.safeTransferFrom(
            buffer, 
            address(this),
            totalBufferWithdraw
        );

        uint256 tAssets = _fetchNativeTVL();
        totalWithdraw = tAssets *  withdrawPercent / 10000;

        uint256 currentBalance = _asset.balanceOf(address(this));
        if(currentBalance < totalWithdraw) {
            uint256 diffPercent = (totalWithdraw - currentBalance) * 10000 / totalWithdraw;
            if(diffPercent < 250) { //less than 2.5% spread
                totalWithdraw = currentBalance;
            } else {
                revert WithdrawalRebalanceIssue();
            }
        }

        /**
         * @dev Execute user withdrawal with ERC4626 low level function
         */
        _burn(msg.sender, totalSupply().mulDiv(withdrawPercent, 10000, Math.Rounding.Ceil));
        _asset.safeTransfer(_user, totalWithdraw);
        emit Withdraw(msg.sender, msg.sender, msg.sender, totalWithdraw, _amount);
        
        /**
         * Calculate new buffer size and rebalance the vault
         */
        if(withdrawPercent == 10000) {
            isLive = false;
        }

        //UNAUDITED: instead of just do nativeTVL -= totalWithdraw, in the case of oracleExit underprice strategy out
        nativeTVL = totalWithdraw <= nativeTVL ? nativeTVL - totalWithdraw : 0;
        _purgeDynamicParams(_dynParamsIndexExit);
    }

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
    ) external onlyPositionManager {
        _storeDynamicParams(_dynParamsIndex, _dynParams);

        uint256 length = _from.length;
        if(_isEnter) {
            for (uint i = 0; i < length; i++) {
                for (uint256 j = _from[i]; j <= _to[i]; j++) {
                    LibBlock.executeStrategyEnter(strategyBlocks[j], j);
                }
            }
        } else {
            for (uint i = 0; i < length; i++) {
                for (uint256 j = _to[i]; j >= _from[i]; j--) {
                    LibBlock.executeStrategyExit(strategyBlocks[j], j, 10000);
                }
            }
            if(_neededTokenToRebalance != address(0))
                IERC20(_neededTokenToRebalance).safeTransfer(
                    msg.sender, 
                    IERC20(_neededTokenToRebalance).balanceOf(address(this))
                );
        }

        _purgeDynamicParams(_dynParamsIndex);
    }


    /**
     * Internal Functions
     */

    /**
     * @notice return current owner of the vault
     */
    function _owner() internal view returns (address) {
        return IMajoraERC3525(erc3525).ownerOf(1);
    }

    /**
     * @dev Get the strategy blocks for the vault.
     * @return config Array of strategy blocks.
     */
    function _getConfiguration() internal view returns (DataTypes.VaultConfigurationMap memory) {
        return IMajoraVaultFactory(factory).getVaultConfiguration(address(this));
    }

    function _getVaultDepositLimits() 
        internal 
        view 
        returns (
            uint256 _minUserDeposit,
            uint256 _maxUserDeposit,
            uint256 _minVaultDeposit,
            uint256 _maxVaultDeposit
        )
    {
        return IMajoraVaultFactory(factory).getVaultDepositLimits(address(this));
    }

    function _getBufferAllowance() internal view returns (uint256) {
        return IERC20(asset()).allowance(buffer, address(this));
    }


    /**
     * @dev Internal function to harvest strategy rewards.
     */
    function _harvestStrategy() private {
        uint256 _harvestBlocksLength = harvestBlocksLength;
        for (uint256 i = 0; i < _harvestBlocksLength; i++) {
            LibBlock.executeHarvest(harvestBlocks[i], i);
        }
    }

    /**
     * @dev Internal function to enter the vault assets into the strategy.
     */
    function _enterInStrategy() private {
        uint256 stratBlocksLength = strategyBlocksLength;
        for (uint256 i = 0; i < stratBlocksLength; i++) {
            LibBlock.executeStrategyEnter(strategyBlocks[i], i);
        }
    }

    /**
     * @dev Internal function to exit the vault from the strategy.
     * @param _percent The percentage of assets to exit from the strategy.
     */
    function _exitStrategy(uint256 _percent) private {
        uint256 stratBlocksLength = strategyBlocksLength;

        if (stratBlocksLength == 0) return;

        if (stratBlocksLength == 1) {
            LibBlock.executeStrategyExit(strategyBlocks[0], 0, _percent);
        } else {
            bool[] memory _isFinalBlock = isFinalBlock;
            uint256 revertedIndex = stratBlocksLength - 1;
            for (uint256 i = 0; i < stratBlocksLength; i++) {
                uint256 index = revertedIndex - i;
                if (_isFinalBlock[index]) {
                    LibBlock.executeStrategyExit(strategyBlocks[index], index, _percent);
                } else {
                    LibBlock.executeStrategyExit(strategyBlocks[index], index, 10000);
                }
            }
        }
    }

    /**
     * @dev Internal function to execute the buffer rebalancing process.
     * @param _dynParamsIndex The array of dynamic parameter indices for strategy .
     * @param _dynParams The array of dynamic parameters for strategy.
     */
    function _rebalance(
        uint256[] memory _dynParamsIndex,
        bytes[] memory _dynParams
    ) internal {
        uint256 _bufferAllowance = _getBufferAllowance();
        uint256 _nativeTVL = _getNativeTVL();

        if (_nativeTVL == 0) return;

        DataTypes.VaultConfigurationMap memory config = _getConfiguration();

        uint256 bufferSize = config.getBufferSize();
        uint256 currentBufferSize = (_bufferAllowance * 10000) / _nativeTVL;
        uint256 derivation = config.getBufferDerivation();

        _storeDynamicParams(_dynParamsIndex, _dynParams);

        /**
         * Buffer oversized
         */
        if (currentBufferSize > bufferSize + derivation) {
            if (_nativeTVL < IMajoraVaultFactory(factory).getVaultMinimalDepositLimits(address(this))) {
                return;
            }

            uint256 amountToDeposit = (_nativeTVL * (currentBufferSize - bufferSize)) / 10000;
            IERC20(asset()).safeTransferFrom(buffer, address(this), amountToDeposit);
            _enterInStrategy();
        }

        /**
         * Buffer undersized
         */
        if (currentBufferSize < bufferSize - derivation) {
            _exitStrategy(bufferSize - currentBufferSize);
            _sendVaultAssetsInBuffer();
        }

        isLive = true;
        _updateIndex();
        _purgeDynamicParams(_dynParamsIndex);
    }

    /**
     * @dev Internal function to store dynamic block parameters.
     * @param _dynParamsIndex The array of dynamic parameter indices.
     * @param _dynParams The array of dynamic parameter values.
     */
    function _storeDynamicParams(uint256[] memory _dynParamsIndex, bytes[] memory _dynParams) internal {
        uint256 arrLength = _dynParamsIndex.length;
        if(arrLength !=  _dynParams.length) revert DynamicParamsArrayLengthsMismatch();
        for (uint256 i = 0; i < arrLength; i++) {
            LibBlock.setupDynamicBlockData(_dynParamsIndex[i], _dynParams[i]);
        }
    }

    /**
     * @dev Internal function to purge dynamic block parameters.
     * @param _dynParamsIndex The array of dynamic parameter indices.
     */
    function _purgeDynamicParams(uint256[] memory _dynParamsIndex) internal {
        uint256 arrLength = _dynParamsIndex.length;
        for (uint256 i = 0; i < arrLength; i++) {
            LibBlock.purgeDynamicBlockData(_dynParamsIndex[i]);
        }
    }

    /**
     * @dev Transfer available assets on the vault contract to the buffer
     */
    function _sendVaultAssetsInBuffer() internal {
        IERC20 token = IERC20(asset());
        uint256 bal = token.balanceOf(address(this));
        if(bal > 0)
            IMajoraAssetBuffer(buffer).putInBuffer(address(token), bal);
    }

    /**
     * @dev Execute block hook functions
     */
    function _executeHooks(DataTypes.BlockExecutionType _executionType) internal {
        uint256 _stratBlocksLength = strategyBlocksLength;
        for (uint256 i = 0; i < _stratBlocksLength; i++) {
            LibBlock.executeHook(strategyBlocks[i], i, _executionType);
        }
    }

    /**
     * @dev Internal function to fetch the native TVL (Total Value Locked) of the vault.
     * @return The native TVL of the vault.
     */
    function _fetchNativeTVL() internal view returns (uint256) {
        if (lastNativeTVLUpdate == block.timestamp) return nativeTVL;
        return _getNativeTVL();
    }

    /**
     * @dev Internal function to get the native TVL (Total Value Locked) of the vault.
     * @return The native TVL of the vault.
     */
    function _getNativeTVL() internal view returns (uint256) {
        address _asset = asset();

        DataTypes.OracleState memory oracleState;
        oracleState.vault = address(this);
        oracleState.tokens = new address[](1);
        oracleState.tokensAmount = new uint256[](1);
        oracleState.tokens[0] = _asset;
        oracleState.tokensAmount[0] = IERC20(_asset).balanceOf(address(this));

        uint256 _strategyBlocksLength = strategyBlocksLength;
        if (_strategyBlocksLength == 0 || !isLive) {
            return IERC20(_asset).balanceOf(address(this)) + _getBufferAllowance();
        } else if (_strategyBlocksLength == 1) {
            oracleState =
                IMajoraStrategyBlock(strategyBlocks[0]).oracleExit(
                    oracleState, 
                    LibBlock.getStrategyStorageByIndex(0), 
                    10000
                );
        } else {
            uint256 revertedIndex = _strategyBlocksLength - 1;
            for (uint256 i = 0; i < _strategyBlocksLength; i++) {
                uint256 index = revertedIndex - i;
                oracleState = IMajoraStrategyBlock(strategyBlocks[index]).oracleExit(
                    oracleState, LibBlock.getStrategyStorageByIndex(index), 10000
                );
            }
        }

        return oracleState.findTokenAmount(_asset) + _getBufferAllowance();
    }

    /**
     * @dev Internal function to harvest fees from the vault.
     */
    function _updateIndex() internal {
        nativeTVL = _getNativeTVL();
        lastNativeTVLUpdate = block.timestamp;

        DataTypes.VaultConfigurationMap memory config = _getConfiguration();
        uint256 tSupply = totalSupply();
        uint256 _vaultIndexHighWaterMark = vaultIndexHighWaterMark;
        uint256 tAssets = totalAssets();

        if(tSupply == 0) return;

        uint256 currentVaultIndex = (tAssets * 10000) / tSupply;
        if (_vaultIndexHighWaterMark >= currentVaultIndex) {
            return;
        }

        uint256 _fees = config.getProtocolFee() +
            config.getCreatorFee() +
            config.getHarvestFee();

        uint256 tax = ((tSupply * (currentVaultIndex - _vaultIndexHighWaterMark) * _fees) / 100000000);

        vaultIndexHighWaterMark = (tAssets - tax) * 10000 / tSupply;
        taxValueCumulated += tax;
    }

    /**
     * @dev Emit custom log on shares transfer.
     */
    function _update(address from, address to, uint256 value) internal override {
        DataTypes.VaultConfigurationMap memory config = _getConfiguration();

        _applyMiddleware(from, to, value, config);    

        // if it's a shares transfer or a withdraw, verify timelock
        if(from != address(0) && to != address(0) || to == address(0)) {
            _applyTimelock(from);
        }

        //if it's a deposit, verify middleware
        if(from == address(0)) {
            _resetTimelock(to, value, config);
        }

        super._update(from, to, value);
        emit MajoraVaultUpdate(
            MajoraVaultUpdateType.Transfer,
            abi.encode(from, to, value)
        );
    }

    /**
     * @notice Applies the middleware strategy to the given deposit amount and vault total value.
     * @param _sender user
     * @param _receiver user
     * @param _amount shares amount
     */
    function _applyMiddleware(address _sender, address _receiver, uint256 _amount, DataTypes.VaultConfigurationMap memory config) internal view {
        uint256 s = config.getMiddlewareStrategy();

        //Check tvl limits
        _applyTvlLimits(_sender, _receiver, _amount, config);

        //Public
        if (s == 0) return;

        //if it is a transfer or a deposit check strategy middlewares
        if (_receiver != address(0) && !_skipMiddlewareFor(_receiver)) {
            //Whitelisted
            if (s == 1) {
                _applyWhitelisted(_receiver);
            }

            //Holder
            if (s == 2) {
                _applyHolder(_receiver);
            }
        }
    }

    /**
     * @notice Applies the total value locked (TVL) limits to the given deposit amount and vault total value.
     * @param _sender user
     * @param _receiver user
     * @param _amount Deposit amount
     */
    function _applyTvlLimits(address _sender, address _receiver, uint256 _amount, DataTypes.VaultConfigurationMap memory config) internal view {
        
        uint256 mode = config.getLimitMode();

        //No limit set
        if (mode == 0) return;

        (
            uint256 minUserDeposit,
            uint256 maxUserDeposit,
            ,
            uint256 maxVaultDeposit
        ) = _getVaultDepositLimits();

        //Deposit case 
        if(_sender == address(0)) {
            // if max vault deposit enabled check if it is exceeded
            if (mode >= 4 && totalSupply() + _amount > maxVaultDeposit) {
                revert MaxVaultDepositReached();
            }
        }

        uint256 receiverBalance = balanceOf(_receiver);

        //if max user deposit set -> in case of Deposit or transfer -> check max receiver deposit
        if(mode % 4 > 1) {
            if(_sender == address(0) || (_sender != address(0) && _receiver != address(0))) {
                if (receiverBalance + _amount > maxUserDeposit) {
                    revert MaxUserDepositReached();
                }
            }
        }
        

        //Minimum limit set
        if (mode % 2 == 1) {
            uint256 senderBalance = balanceOf(_sender);

            //If not a withdraw -> Check receiver min limit
            if (_receiver != address(0) && receiverBalance + _amount < minUserDeposit) {
                revert MinDepositNotReached();
            }

            //If not a deposit -> Check sender min limit
            if (_sender != address(0) && senderBalance > _amount && senderBalance - _amount < minUserDeposit) {
                revert MinDepositNotReached();
            }
        }
    }

    /**
     * @notice Checks if the sender's address is whitelisted.
     */
    function _applyWhitelisted(address _user) internal view {
        if (
            !IMajoraVaultFactory(factory).addressIsWhitelistedOnVault(address(this), _user)
        ) revert NotWhitelisted();
    }

    /**
     * @notice Checks if the sender's address holds the required amount of tokens.
     */
    function _applyHolder(address _user) internal view {
        (address holdToken, uint256 holdAmount) = IMajoraVaultFactory(factory).getVaultHoldingParams(address(this));
        if (holdAmount == 0) return;

        uint256 balance = IERC20(holdToken).balanceOf(_user);
        if (balance < holdAmount) revert HoldAmountNotReached();
    }

    /**
     * @notice Checks if the sender's address holds the required amount of tokens.
     */
    function _applyTimelock(address _user) internal view {
        if (timelocks[_user] > block.timestamp) revert TimelockNotReached();
    }

    /**
     * @notice return true if _user is the user interaction or portal address.
     */
    function _skipMiddlewareFor(address _user) internal view returns (bool) {
        return _user == addressProvider.userInteractions() || _user == addressProvider.portal();
    }

    /**
     * @notice Resets the deposited value for the given user address.
     * @param _user Address of the user
     */
    function _resetTimelock(address _user, uint256 _shares, DataTypes.VaultConfigurationMap memory config) internal {
        uint256 timelockDuration = config.getTimelockDuration();
        if(timelockDuration == 0)
            return;

        //if user is an address with the integrator role, the timelock isn't applied 
        (bool isMember,) = accessManager.hasRole(8, _user);
        if(!isMember) {
            uint256 currentTimelock = timelocks[_user];
            uint256 remainingTimelock = currentTimelock <= block.timestamp ? 0 : currentTimelock - block.timestamp;
            uint256 balance = balanceOf(_user);
            uint256 newTimelock = ((balance * remainingTimelock) + (_shares * timelockDuration)) / (balance + _shares);
            
            timelocks[_user] = block.timestamp + newTimelock;
        }
    }

    /**
     * ---------------------- ERC2771 logic ----------------------
     */

    function _msgSender() internal view virtual override returns (address sender) {
        if (msg.sender == factory) {
            // The assembly code is more direct than the Solidity version using `abi.decode`.
            /// @solidity memory-safe-assembly
            assembly {
                sender := shr(96, calldataload(sub(calldatasize(), 20)))
            }
        } else {
            return msg.sender;
        }
    }

    function _msgData() internal view virtual override returns (bytes calldata) {
        if (msg.sender == factory) {
            return msg.data[:msg.data.length - 20];
        } else {
            return msg.data;
        }
    }
}