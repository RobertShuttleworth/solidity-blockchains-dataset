// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity 0.8.22;

import { ReentrancyGuard } from './openzeppelin_contracts_security_ReentrancyGuard.sol';
import { IActionDataStructures } from './contracts_interfaces_IActionDataStructures.sol';
import { IGateway } from './contracts_crosschain_interfaces_IGateway.sol';
import { IGatewayClient } from './contracts_crosschain_interfaces_IGatewayClient.sol';
import { IRegistry } from './contracts_interfaces_IRegistry.sol';
import { ISettings } from './contracts_interfaces_ISettings.sol';
import { BalanceManagement } from './contracts_BalanceManagement.sol';
import { CallerGuard } from './contracts_CallerGuard.sol';
import { Pausable } from './contracts_Pausable.sol';
import { SystemVersionId } from './contracts_SystemVersionId.sol';
import { ZeroAddressError } from './contracts_Errors.sol';
import './helpers/AddressHelper.sol' as AddressHelper;
import './helpers/GasReserveHelper.sol' as GasReserveHelper;
import './helpers/RefundHelper.sol' as RefundHelper;
import './helpers/TransferHelper.sol' as TransferHelper;
import './Constants.sol' as Constants;

/**
 * @title ActionExecutor
 * @notice The main contract for cross-chain swaps
 */
contract ActionExecutor is
    SystemVersionId,
    Pausable,
    ReentrancyGuard,
    CallerGuard,
    BalanceManagement,
    IGatewayClient,
    ISettings,
    IActionDataStructures
{
    /**
     * @dev The contract for action settings
     */
    IRegistry public registry;

    uint256 private lastActionId = block.chainid * 1e11 + 55555 ** 2;

    /**
     * @notice Emitted when source chain action is performed
     * @param actionId The ID of the action
     * @param targetChainId The ID of the target chain
     * @param sourceSender The address of the user on the source chain
     * @param targetRecipient The address of the recipient on the target chain
     * @param gatewayType The type of cross-chain gateway
     * @param sourceToken The address of the input token on the source chain
     * @param targetToken The address of the output token on the target chain
     * @param amount The amount of the vault asset used for the action, with decimals set to 18
     * @param fee The fee amount, measured in vault asset with decimals set to 18
     * @param timestamp The timestamp of the action (in seconds)
     */
    event ActionSource(
        uint256 indexed actionId,
        uint256 indexed targetChainId,
        address indexed sourceSender,
        address targetRecipient,
        uint256 gatewayType,
        address sourceToken,
        address targetToken,
        uint256 amount,
        uint256 fee,
        uint256 timestamp
    );

    /**
     * @notice Emitted when target chain action is performed
     * @param actionId The ID of the action
     * @param sourceChainId The ID of the source chain
     * @param isSuccess The status of the action execution
     * @param timestamp The timestamp of the action (in seconds)
     */
    event ActionTarget(
        uint256 indexed actionId,
        uint256 indexed sourceChainId,
        bool indexed isSuccess,
        uint256 timestamp
    );

    /**
     * @notice Emitted for source chain and single-chain actions when user's funds processing is completed
     * @param actionId The ID of the action
     * @param isLocal The action type flag, is true for single-chain actions
     * @param sender The address of the user
     * @param routerType The type of the swap router
     * @param fromTokenAddress The address of the swap input token
     * @param toTokenAddress The address of the swap output token
     * @param fromAmount The input token amount
     * @param resultAmount The swap result token amount
     */
    event SourceProcessed(
        uint256 indexed actionId,
        bool indexed isLocal,
        address indexed sender,
        uint256 routerType,
        address fromTokenAddress,
        address toTokenAddress,
        uint256 fromAmount,
        uint256 resultAmount
    );

    /**
     * @notice Emitted for target chain actions when the user's funds processing is completed
     * @param actionId The ID of the action
     * @param recipient The address of the recipient
     * @param routerType The type of the swap router
     * @param fromTokenAddress The address of the swap input token
     * @param toTokenAddress The address of the swap output token
     * @param fromAmount The input token amount
     * @param resultAmount The swap result token amount
     */
    event TargetProcessed(
        uint256 indexed actionId,
        address indexed recipient,
        uint256 routerType,
        address fromTokenAddress,
        address toTokenAddress,
        uint256 fromAmount,
        uint256 resultAmount
    );

    /**
     * @notice Emitted when the Registry contract address is updated
     * @param registryAddress The address of the Registry contract
     */
    event SetRegistry(address indexed registryAddress);

    /**
     * @notice Emitted when the caller is not a registered cross-chain gateway
     */
    error OnlyGatewayError();

    /**
     * @notice Emitted when the call is not from the current contract
     */
    error OnlySelfError();

    /**
     * @notice Emitted when a cross-chain swap is attempted with the target chain ID matching the current chain
     */
    error SameChainIdError();

    /**
     * @notice Emitted when the native token value of the transaction does not correspond to the swap amount
     */
    error NativeTokenValueError();

    /**
     * @notice Emitted when the requested cross-chain gateway type is not set
     */
    error GatewayNotSetError();

    /**
     * @notice Emitted when the requested swap router type is not set
     */
    error RouterNotSetError();

    /**
     * @notice Emitted when the swap process results in an error
     */
    error SwapError();

    /**
     * @notice Emitted when the target amount is insufficient
     * @param expectedAmount Expected amount
     * @param actualAmount Actual amount
     */
    error TargetAmountError(uint256 expectedAmount, uint256 actualAmount);

    /**
     * @dev Modifier to check if the caller is a registered cross-chain gateway
     */
    modifier onlyGateway() {
        if (!registry.isGatewayAddress(msg.sender)) {
            revert OnlyGatewayError();
        }

        _;
    }

    /**
     * @dev Modifier to check if the caller is the current contract
     */
    modifier onlySelf() {
        if (msg.sender != address(this)) {
            revert OnlySelfError();
        }

        _;
    }

    /**
     * @notice Deploys the ActionExecutor contract
     * @param _registry The address of the action settings registry contract
     * @param _actionIdOffset The initial offset of the action ID value
     * @param _owner The address of the initial owner of the contract
     * @param _managers The addresses of initial managers of the contract
     * @param _addOwnerToManagers The flag to optionally add the owner to the list of managers
     */
    constructor(
        IRegistry _registry,
        uint256 _actionIdOffset,
        address _owner,
        address[] memory _managers,
        bool _addOwnerToManagers
    ) {
        _setRegistry(_registry);

        lastActionId += _actionIdOffset;

        _initRoles(_owner, _managers, _addOwnerToManagers);
    }

    /**
     * @notice The standard "receive" function
     * @dev Is payable to allow receiving native token funds from a target swap router
     */
    receive() external payable {}

    /**
     * @notice Sets the address of the action settings registry contract
     * @param _registry The address of the action settings registry contract
     */
    function setRegistry(IRegistry _registry) external onlyManager {
        _setRegistry(_registry);
    }

    /**
     * @notice Executes a cross-chain action
     * @param _action The parameters of the action
     */
    function execute(
        Action calldata _action
    ) external payable whenNotPaused nonReentrant checkCaller returns (uint256 actionId) {
        if (_action.targetChainId == block.chainid) {
            revert SameChainIdError();
        }

        // For cross-chain swaps of the native token,
        // the value of the transaction should be greater or equal to the swap amount
        if (
            _action.sourceTokenAddress == Constants.NATIVE_TOKEN_ADDRESS &&
            msg.value < _action.sourceSwapInfo.fromAmount
        ) {
            revert NativeTokenValueError();
        }

        uint256 initialBalance = address(this).balance - msg.value;

        lastActionId++;
        actionId = lastActionId;

        SourceSettings memory settings = registry.sourceSettings(
            _action.gatewayType,
            _action.sourceSwapInfo.routerType
        );

        if (settings.gateway == address(0)) {
            revert GatewayNotSetError();
        }

        address gatewayAssetAddress = IGateway(settings.gateway).assetByType(_action.assetType);

        (uint256 processedAmount, uint256 nativeTokenSpent) = _processSource(
            actionId,
            _action.sourceTokenAddress,
            gatewayAssetAddress,
            _action.sourceSwapInfo,
            settings.router,
            settings.routerTransfer
        );

        bytes memory targetMessageData = abi.encode(
            TargetMessage({
                actionId: actionId,
                sourceSender: msg.sender,
                assetType: _action.assetType,
                targetTokenAddress: _action.targetTokenAddress,
                targetSwapInfo: _action.targetSwapInfo,
                targetRecipient: _action.targetRecipient == address(0)
                    ? msg.sender
                    : _action.targetRecipient,
                targetGasReserveOverride: _action.targetGasReserveOverride
            })
        );

        AssetAmountData memory assetAmountData = AssetAmountData({
            assetType: _action.assetType,
            amount: processedAmount
        });

        uint256 targetAmount = IGateway(settings.gateway).targetAmount(
            _action.targetChainId,
            targetMessageData,
            _action.gatewaySettings,
            assetAmountData
        );

        if (targetAmount < _action.targetSwapInfo.fromAmount) {
            revert TargetAmountError(_action.targetSwapInfo.fromAmount, targetAmount);
        }

        _sendMessage(
            settings,
            _action,
            targetMessageData,
            assetAmountData,
            msg.value - nativeTokenSpent
        );

        // - - - Extra balance transfer - - -

        RefundHelper.refundExtraBalance(address(this), initialBalance, payable(msg.sender));

        // - - -

        _emitActionSourceEvent(actionId, _action, processedAmount);
    }

    /**
     * @notice Cross-chain message handler on the target chain
     * @dev The function is called by cross-chain gateways
     * @param _messageSourceChainId The ID of the message source chain
     * @param _payloadData The content of the cross-chain message
     * @param _assetAddress The asset address
     * @param _assetAmount The asset amount
     */
    function handleExecutionPayload(
        uint256 _messageSourceChainId,
        bytes calldata _payloadData,
        address _assetAddress,
        uint256 _assetAmount
    ) external payable whenNotPaused onlyGateway {
        TargetMessage memory targetMessage = abi.decode(_payloadData, (TargetMessage));

        if (_assetAmount < targetMessage.targetSwapInfo.fromAmount) {
            revert TargetAmountError(targetMessage.targetSwapInfo.fromAmount, _assetAmount);
        }

        TargetSettings memory settings = registry.targetSettings(
            targetMessage.targetSwapInfo.routerType
        );

        TransferHelper.safeTransferFrom(_assetAddress, msg.sender, address(this), _assetAmount);

        uint256 extraAssetAmount = _assetAmount - targetMessage.targetSwapInfo.fromAmount;
        bool selfCallSuccess;

        (bool hasGasReserve, uint256 gasAllowed) = GasReserveHelper.checkGasReserve(
            targetMessage.targetGasReserveOverride != 0
                ? targetMessage.targetGasReserveOverride
                : settings.gasReserve
        );

        if (hasGasReserve) {
            try this.selfCallTarget{ gas: gasAllowed }(settings, targetMessage, _assetAddress) {
                selfCallSuccess = true;
            } catch {
                extraAssetAmount = _assetAmount;
            }
        }

        if (extraAssetAmount > 0) {
            TransferHelper.safeTransfer(
                _assetAddress,
                targetMessage.targetRecipient,
                extraAssetAmount
            );
        }

        emit ActionTarget(
            targetMessage.actionId,
            _messageSourceChainId,
            selfCallSuccess,
            block.timestamp
        );
    }

    /**
     * @notice Controllable processing of the target chain logic
     * @dev Is called by the current contract to enable error handling
     * @param _settings Target action settings
     * @param _targetMessage The content of the cross-chain message
     * @param _tokenAddress The token address
     */
    function selfCallTarget(
        TargetSettings calldata _settings,
        TargetMessage calldata _targetMessage,
        address _tokenAddress
    ) external onlySelf {
        _processTarget(
            _settings,
            _targetMessage.actionId,
            _tokenAddress,
            _targetMessage.targetTokenAddress,
            _targetMessage.targetSwapInfo,
            _targetMessage.targetRecipient
        );
    }

    function _processSource(
        uint256 _actionId,
        address _fromTokenAddress,
        address _toTokenAddress,
        SwapInfo memory _sourceSwapInfo,
        address _routerAddress,
        address _routerTransferAddress
    ) private returns (uint256 resultAmount, uint256 nativeTokenSpent) {
        if (_fromTokenAddress == Constants.NATIVE_TOKEN_ADDRESS) {
            if (_toTokenAddress == Constants.NATIVE_TOKEN_ADDRESS) {
                resultAmount = _sourceSwapInfo.fromAmount;
                nativeTokenSpent = resultAmount;
            } else {
                uint256 toTokenBalanceBefore = tokenBalance(_toTokenAddress);

                if (_routerAddress == address(0)) {
                    revert RouterNotSetError();
                }

                // - - - Source swap (native token) - - -

                (bool routerCallSuccess, ) = payable(_routerAddress).call{
                    value: _sourceSwapInfo.fromAmount
                }(_sourceSwapInfo.routerData);

                if (!routerCallSuccess) {
                    revert SwapError();
                }

                // - - -

                resultAmount = tokenBalance(_toTokenAddress) - toTokenBalanceBefore;
                nativeTokenSpent = _sourceSwapInfo.fromAmount;
            }
        } else {
            uint256 toTokenBalanceBefore = tokenBalance(_toTokenAddress);

            TransferHelper.safeTransferFrom(
                _fromTokenAddress,
                msg.sender,
                address(this),
                _sourceSwapInfo.fromAmount
            );

            if (_fromTokenAddress != _toTokenAddress) {
                if (_routerAddress == address(0)) {
                    revert RouterNotSetError();
                }

                // - - - Source swap (non-native token) - - -

                TransferHelper.safeApprove(
                    _fromTokenAddress,
                    _routerTransferAddress,
                    _sourceSwapInfo.fromAmount
                );

                (bool routerCallSuccess, ) = _routerAddress.call(_sourceSwapInfo.routerData);

                if (!routerCallSuccess) {
                    revert SwapError();
                }

                TransferHelper.safeApprove(_fromTokenAddress, _routerTransferAddress, 0);

                // - - -
            }

            resultAmount = tokenBalance(_toTokenAddress) - toTokenBalanceBefore;
            nativeTokenSpent = 0;
        }

        emit SourceProcessed(
            _actionId,
            false, // compatibility: isLocal = false
            msg.sender,
            _sourceSwapInfo.routerType,
            _fromTokenAddress,
            _toTokenAddress,
            _sourceSwapInfo.fromAmount,
            resultAmount
        );
    }

    function _processTarget(
        TargetSettings memory _settings,
        uint256 _actionId,
        address _fromTokenAddress,
        address _toTokenAddress,
        SwapInfo memory _targetSwapInfo,
        address _targetRecipient
    ) private {
        uint256 resultAmount;

        if (_toTokenAddress == _fromTokenAddress) {
            resultAmount = _targetSwapInfo.fromAmount;
        } else {
            if (_settings.router == address(0)) {
                revert RouterNotSetError();
            }

            uint256 toTokenBalanceBefore = tokenBalance(_toTokenAddress);

            // - - - Target swap - - -

            TransferHelper.safeApprove(
                _fromTokenAddress,
                _settings.routerTransfer,
                _targetSwapInfo.fromAmount
            );

            (bool success, ) = _settings.router.call(_targetSwapInfo.routerData);

            if (!success) {
                revert SwapError();
            }

            TransferHelper.safeApprove(_fromTokenAddress, _settings.routerTransfer, 0);

            // - - -

            resultAmount = tokenBalance(_toTokenAddress) - toTokenBalanceBefore;
        }

        if (_toTokenAddress == Constants.NATIVE_TOKEN_ADDRESS) {
            TransferHelper.safeTransferNative(_targetRecipient, resultAmount);
        } else {
            TransferHelper.safeTransfer(_toTokenAddress, _targetRecipient, resultAmount);
        }

        emit TargetProcessed(
            _actionId,
            _targetRecipient,
            _targetSwapInfo.routerType,
            _fromTokenAddress,
            _toTokenAddress,
            _targetSwapInfo.fromAmount,
            resultAmount
        );
    }

    function _setRegistry(IRegistry _registry) private {
        AddressHelper.requireContract(address(_registry));

        registry = _registry;

        emit SetRegistry(address(_registry));
    }

    function _sendMessage(
        SourceSettings memory _settings,
        Action calldata _action,
        bytes memory _messageData,
        AssetAmountData memory _assetAmountData,
        uint256 _availableValue
    ) private {
        address token = IGateway(_settings.gateway).assetByType(_assetAmountData.assetType);

        if (token == address(0)) {
            revert ZeroAddressError();
        }

        TransferHelper.safeApprove(token, _settings.gateway, _assetAmountData.amount);

        IGateway(_settings.gateway).sendMessage{ value: _availableValue }(
            _action.targetChainId,
            _messageData,
            _action.gatewaySettings,
            _assetAmountData
        );

        TransferHelper.safeApprove(token, _settings.gateway, 0);
    }

    function _emitActionSourceEvent(
        uint256 _actionId,
        Action calldata _action,
        uint256 _amount
    ) private {
        emit ActionSource(
            _actionId,
            _action.targetChainId,
            msg.sender,
            _action.targetRecipient,
            _action.gatewayType,
            _action.sourceTokenAddress,
            _action.targetTokenAddress,
            _amount,
            0, // compatibility: fee = 0
            block.timestamp
        );
    }
}