// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity 0.8.22;

import { ReentrancyGuard } from './openzeppelin_contracts_security_ReentrancyGuard.sol';
import { OFTComposeMsgCodec } from './layerzerolabs_oft-evm_contracts_libs_OFTComposeMsgCodec.sol';
import { MessagingFee, OFTReceipt, SendParam } from './layerzerolabs_lz-evm-oapp-v2_contracts_oft_interfaces_IOFT.sol';
import { OptionsBuilder } from './layerzerolabs_lz-evm-oapp-v2_contracts_oapp_libs_OptionsBuilder.sol';
import { IStargate } from './stargatefinance_stg-evm-v2_src_interfaces_IStargate.sol';
import { IGateway } from './contracts_crosschain_interfaces_IGateway.sol';
import { IGatewayClient } from './contracts_crosschain_interfaces_IGatewayClient.sol';
import { GatewayBase } from './contracts_crosschain_GatewayBase.sol';
import { SystemVersionId } from './contracts_SystemVersionId.sol';
import { ZeroAddressError } from './contracts_Errors.sol';
import '../../helpers/AddressHelper.sol' as AddressHelper;
import '../../helpers/GasReserveHelper.sol' as GasReserveHelper;
import '../../helpers/TransferHelper.sol' as TransferHelper;
import '../../Constants.sol' as Constants;
import '../../DataStructures.sol' as DataStructures;

/**
 * @title StargateGateway
 * @notice The contract implementing the cross-chain messaging logic specific to Stargate
 */
contract StargateGateway is SystemVersionId, GatewayBase {
    using OptionsBuilder for bytes;

    /**
     * @notice Chain/endpoint ID pair structure
     * @dev See https://docs.layerzero.network/v2/developers/evm/technical-reference/deployed-contracts
     * @param standardId The standard EVM chain ID
     * @param layerZeroEid The LayerZero endpoint ID
     */
    struct ChainIdPair {
        uint256 standardId;
        uint32 layerZeroEid;
    }

    /**
     * @notice Type-to-addresses structure for asset data values
     * @dev Is used as an array parameter item to perform multiple settings
     * @param assetType Asset type
     * @param assetAddress Asset address
     * @param carrierAddress Carrier address
     */
    struct AssetDataItem {
        uint256 assetType;
        address assetAddress;
        address carrierAddress;
    }

    /**
     * @dev LayerZero V2 endpoint contract reference
     */
    address public endpoint;

    /**
     * @dev Registered asset types
     */
    uint256[] public assetTypeList;

    /**
     * @dev Registered asset type indices
     */
    mapping(uint256 assetType => DataStructures.OptionalValue assetTypeIndex)
        public assetTypeIndexMap;

    /**
     * @dev Registered asset addresses by asset type
     */
    mapping(uint256 assetType => address assetAddress) public assetMap;

    /**
     * @dev Registered carrier addresses by asset type
     */
    mapping(uint256 assetType => address carrierAddress) public carrierMap;

    /**
     * @dev Registered asset flags by address
     */
    mapping(address account => bool isAsset) public isAssetAddress;

    /**
     * @dev Registered carrier flags by address
     */
    mapping(address account => bool isCarrier) public isCarrierAddress;

    /**
     * @dev The correspondence between standard EVM chain IDs and LayerZero chain IDs
     */
    mapping(uint256 standardId => uint32 layerZeroEid) public standardToLayerZeroChainId;

    /**
     * @dev The correspondence between LayerZero chain IDs and standard EVM chain IDs
     */
    mapping(uint32 layerZeroEid => uint256 standardId) public layerZeroToStandardChainId;

    /**
     * @dev The default value of minimum target gas
     */
    uint256 public minTargetGasDefault;

    /**
     * @dev The custom values of minimum target gas by standard chain IDs
     */
    mapping(uint256 standardChainId => DataStructures.OptionalValue minTargetGas)
        public minTargetGasCustom;

    /**
     * @dev The address of the processing fee collector
     */
    address public processingFeeCollector;

    /**
     * @notice Emitted when the cross-chain endpoint contract reference is set
     * @param endpoint The address of the cross-chain endpoint contract
     */
    event SetEndpoint(address indexed endpoint);

    /**
     * @notice Emitted when the carrier contract reference is set
     * @param assetType The type of the asset
     * @param assetAddress The address of the asset
     * @param carrierAddress The address of the carrier contract
     */
    event SetAsset(
        uint256 indexed assetType,
        address indexed assetAddress,
        address indexed carrierAddress
    );

    /**
     * @notice Emitted when the asset is removed
     * @param assetType The type of the asset
     */
    event RemoveAsset(uint256 indexed assetType);

    /**
     * @notice Emitted when a chain ID pair is added or updated
     * @param standardId The standard EVM chain ID
     * @param layerZeroEid The LayerZero endpoint ID
     */
    event SetChainIdPair(uint256 indexed standardId, uint32 indexed layerZeroEid);

    /**
     * @notice Emitted when a chain ID pair is removed
     * @param standardId The standard EVM chain ID
     * @param layerZeroEid The LayerZero chain ID
     */
    event RemoveChainIdPair(uint256 indexed standardId, uint32 indexed layerZeroEid);

    /**
     * @notice Emitted when the default value of minimum target gas is set
     * @param minTargetGas The value of minimum target gas
     */
    event SetMinTargetGasDefault(uint256 minTargetGas);

    /**
     * @notice Emitted when the custom value of minimum target gas is set
     * @param standardChainId The standard EVM chain ID
     * @param minTargetGas The value of minimum target gas
     */
    event SetMinTargetGasCustom(uint256 standardChainId, uint256 minTargetGas);

    /**
     * @notice Emitted when the custom value of minimum target gas is removed
     * @param standardChainId The standard EVM chain ID
     */
    event RemoveMinTargetGasCustom(uint256 standardChainId);

    /**
     * @notice Emitted when the address of the processing fee collector is set
     * @param processingFeeCollector The address of the processing fee collector
     */
    event SetProcessingFeeCollector(address indexed processingFeeCollector);

    /**
     * @notice Emitted when no carrier is set for the requested carrier asset
     */
    error CarrierNotSetError();

    /**
     * @notice Emitted when there is no registered LayerZero endpoint ID matching the standard EVM chain ID
     */
    error LayerZeroEidNotSetError();

    /**
     * @notice Emitted when the message source chain ID is not registered on the target chain
     * @param sourceChainId The ID of the message source chain
     */
    event TargetFromChainFailure(uint256 indexed sourceChainId);

    /**
     * @notice Emitted when the provided target gas value is not sufficient for the message processing
     */
    error MinTargetGasError();

    /**
     * @notice Emitted when the provided call value is not sufficient for the message processing
     */
    error ProcessingFeeError();

    /**
     * @notice Emitted when the caller is not the LayerZero endpoint contract
     */
    error OnlyEndpointError();

    /**
     * @notice Emitted when the specified asset address is duplicate
     */
    error DuplicateAssetAddressError(address account);

    /**
     * @notice Emitted when the specified carrier address is duplicate
     */
    error DuplicateCarrierAddressError(address account);

    /**
     * @dev Modifier to check if the caller is the LayerZero endpoint contract
     */
    modifier onlyEndpoint() {
        if (msg.sender != endpoint) {
            revert OnlyEndpointError();
        }

        _;
    }

    /**
     * @notice Deploys the LayerZeroGateway contract
     * @param _endpoint The cross-chain endpoint address
     * @param _assetData The asset data
     * @param _chainIdPairs The correspondence between standard EVM chain IDs and LayerZero chain IDs
     * @param _minTargetGasDefault The default value of minimum target gas
     * @param _minTargetGasCustomData The custom values of minimum target gas by standard chain IDs
     * @param _targetGasReserve The initial gas reserve value for target chain action processing
     * @param _processingFeeCollector The initial address of the processing fee collector
     * @param _owner The address of the initial owner of the contract
     * @param _managers The addresses of initial managers of the contract
     * @param _addOwnerToManagers The flag to optionally add the owner to the list of managers
     */
    constructor(
        address _endpoint,
        AssetDataItem[] memory _assetData,
        ChainIdPair[] memory _chainIdPairs,
        uint256 _minTargetGasDefault,
        DataStructures.KeyToValue[] memory _minTargetGasCustomData,
        uint256 _targetGasReserve,
        address _processingFeeCollector,
        address _owner,
        address[] memory _managers,
        bool _addOwnerToManagers
    ) {
        _setEndpoint(_endpoint);

        for (uint256 index; index < _assetData.length; index++) {
            AssetDataItem memory assetDataItem = _assetData[index];

            _setAsset(
                assetDataItem.assetType,
                assetDataItem.assetAddress,
                assetDataItem.carrierAddress
            );
        }

        for (uint256 index; index < _chainIdPairs.length; index++) {
            ChainIdPair memory chainIdPair = _chainIdPairs[index];

            _setChainIdPair(chainIdPair.standardId, chainIdPair.layerZeroEid);
        }

        _setMinTargetGasDefault(_minTargetGasDefault);

        for (uint256 index; index < _minTargetGasCustomData.length; index++) {
            DataStructures.KeyToValue memory minTargetGasCustomEntry = _minTargetGasCustomData[
                index
            ];

            _setMinTargetGasCustom(minTargetGasCustomEntry.key, minTargetGasCustomEntry.value);
        }

        _setTargetGasReserve(_targetGasReserve);

        _setProcessingFeeCollector(_processingFeeCollector);

        _initRoles(_owner, _managers, _addOwnerToManagers);
    }

    /**
     * @notice The standard "receive" function
     */
    receive() external payable {}

    /**
     * @notice Sets the cross-chain endpoint contract reference
     * @param _endpointAddress The address of the cross-chain endpoint contract
     */
    function setEndpoint(address _endpointAddress) external onlyManager {
        _setEndpoint(_endpointAddress);
    }

    /**
     * @notice Adds or updates a registered asset
     * @param _assetType The type of the registered asset
     * @param _assetAddress The address of the registered asset
     * @param _carrierAddress The address of the carrier contract
     */
    function setAsset(
        uint256 _assetType,
        address _assetAddress,
        address _carrierAddress
    ) external onlyManager {
        _setAsset(_assetType, _assetAddress, _carrierAddress);
    }

    /**
     * @notice Removes a registered asset
     * @param _assetType The type of the registered asset
     */
    function removeAsset(uint256 _assetType) external onlyManager {
        address assetAddress = assetMap[_assetType];
        address carrierAddress = carrierMap[_assetType];

        if (assetAddress == address(0) || carrierAddress == address(0)) {
            revert CarrierNotSetError();
        }

        DataStructures.combinedDoubleMapRemove(
            assetMap,
            carrierMap,
            assetTypeList,
            assetTypeIndexMap,
            _assetType
        );

        delete isAssetAddress[assetAddress];
        delete isCarrierAddress[carrierAddress];

        emit RemoveAsset(_assetType);
    }

    /**
     * @notice Adds or updates registered chain ID pairs
     * @param _chainIdPairs The list of chain ID pairs
     */
    function setChainIdPairs(ChainIdPair[] calldata _chainIdPairs) external onlyManager {
        for (uint256 index; index < _chainIdPairs.length; index++) {
            ChainIdPair calldata chainIdPair = _chainIdPairs[index];

            _setChainIdPair(chainIdPair.standardId, chainIdPair.layerZeroEid);
        }
    }

    /**
     * @notice Removes registered chain ID pairs
     * @param _standardChainIds The list of standard EVM chain IDs
     */
    function removeChainIdPairs(uint256[] calldata _standardChainIds) external onlyManager {
        for (uint256 index; index < _standardChainIds.length; index++) {
            uint256 standardId = _standardChainIds[index];

            _removeChainIdPair(standardId);
        }
    }

    /**
     * @notice Sets the default value of minimum target gas
     * @param _minTargetGas The value of minimum target gas
     */
    function setMinTargetGasDefault(uint256 _minTargetGas) external onlyManager {
        _setMinTargetGasDefault(_minTargetGas);
    }

    /**
     * @notice Sets the custom value of minimum target gas by the standard chain ID
     * @param _standardChainId The standard EVM ID of the target chain
     * @param _minTargetGas The value of minimum target gas
     */
    function setMinTargetGasCustom(
        uint256 _standardChainId,
        uint256 _minTargetGas
    ) external onlyManager {
        _setMinTargetGasCustom(_standardChainId, _minTargetGas);
    }

    /**
     * @notice Removes the custom value of minimum target gas by the standard chain ID
     * @param _standardChainId The standard EVM ID of the target chain
     */
    function removeMinTargetGasCustom(uint256 _standardChainId) external onlyManager {
        _removeMinTargetGasCustom(_standardChainId);
    }

    /**
     * @notice Sets the address of the processing fee collector
     * @param _processingFeeCollector The address of the processing fee collector
     */
    function setProcessingFeeCollector(address _processingFeeCollector) external onlyManager {
        _setProcessingFeeCollector(_processingFeeCollector);
    }

    /**
     * @notice Send a cross-chain message
     * @dev The settings parameter contains an ABI-encoded uint256 value of the target chain gas
     * @param _targetChainId The message target chain ID
     * @param _appMessage The app message content
     * @param _settings The gateway-specific settings
     * @param _assetAmountData The asset amount data
     */
    function sendMessage(
        uint256 _targetChainId,
        bytes calldata _appMessage,
        bytes calldata _settings,
        AssetAmountData calldata _assetAmountData
    ) external payable onlyClient whenNotPaused {
        address peerAddress = _checkPeerAddress(_targetChainId);

        uint32 targetLayerZeroEid = standardToLayerZeroChainId[_targetChainId];

        if (targetLayerZeroEid == 0) {
            revert LayerZeroEidNotSetError();
        }

        (uint128 targetGas, uint256 processingFee) = _checkSettings(_settings, _targetChainId);

        // - - - Processing fee transfer - - -

        if (msg.value < processingFee) {
            revert ProcessingFeeError();
        }

        if (processingFee > 0 && processingFeeCollector != address(0)) {
            TransferHelper.safeTransferNative(processingFeeCollector, processingFee);
        }

        address token = assetMap[_assetAmountData.assetType];
        address carrierAddress = carrierMap[_assetAmountData.assetType];

        TransferHelper.safeTransferFrom(token, msg.sender, address(this), _assetAmountData.amount);

        TransferHelper.safeApprove(token, carrierAddress, _assetAmountData.amount);

        bytes calldata appMessage = _appMessage; // stack too deep

        (
            uint256 valueToSend,
            SendParam memory sendParam,
            MessagingFee memory messagingFee
        ) = _prepareParameters(
                carrierAddress,
                targetLayerZeroEid,
                _assetAmountData.amount,
                peerAddress,
                appMessage,
                targetGas
            );

        IStargate(carrierAddress).sendToken{ value: valueToSend }(
            sendParam,
            messagingFee,
            msg.sender
        );
    }

    function lzCompose(
        address _from,
        bytes32 /*_guid*/,
        bytes calldata _message,
        address /*_executor*/,
        bytes calldata /*_extraData*/
    ) external payable nonReentrant onlyEndpoint {
        require(isCarrierAddress[_from], '!carrier');

        uint32 sourceEid = OFTComposeMsgCodec.srcEid(_message);
        uint256 sourceStandardChainId = layerZeroToStandardChainId[sourceEid];

        bool condition = (sourceStandardChainId != 0 &&
            peerMap[sourceStandardChainId] != address(0));

        if (!condition) {
            emit TargetFromChainFailure(sourceStandardChainId);

            return;
        }

        address assetAddress = IStargate(_from).token();
        uint256 assetAmount = OFTComposeMsgCodec.amountLD(_message);
        bytes memory appMessage = OFTComposeMsgCodec.composeMsg(_message);

        TransferHelper.safeApprove(assetAddress, address(client), assetAmount);

        (bool hasGasReserve, uint256 gasAllowed) = GasReserveHelper.checkGasReserve(
            targetGasReserve
        );

        if (hasGasReserve) {
            try
                client.handleExecutionPayload{ gas: gasAllowed }(
                    sourceStandardChainId,
                    appMessage,
                    assetAddress,
                    assetAmount
                )
            {} catch {
                emit TargetExecutionFailure();
            }
        } else {
            emit TargetGasReserveFailure(sourceStandardChainId);
        }

        TransferHelper.safeApprove(assetAddress, address(client), 0);
    }

    /**
     * @notice Cross-chain message fee estimation (native token fee only)
     * @param _targetChainId The ID of the target chain
     * @param _appMessage The app message content
     * @param _settings The gateway-specific settings
     * @param _assetAmountData The asset amount data
     * @return nativeFee Message fee (native token)
     */
    function messageFee(
        uint256 _targetChainId,
        bytes calldata _appMessage,
        bytes calldata _settings,
        AssetAmountData calldata _assetAmountData
    ) external view returns (uint256 nativeFee) {
        address peerAddress = _checkPeer(_targetChainId);

        uint32 targetLayerZeroEid = standardToLayerZeroChainId[_targetChainId];

        if (targetLayerZeroEid == 0) {
            revert LayerZeroEidNotSetError();
        }

        (uint128 targetGas, ) = _checkSettings(_settings, _targetChainId);

        address carrierAddress = carrierMap[_assetAmountData.assetType];

        bytes calldata appMessage = _appMessage; // stack too deep

        (, , MessagingFee memory messagingFee) = _prepareParameters(
            carrierAddress,
            targetLayerZeroEid,
            _assetAmountData.amount,
            peerAddress,
            appMessage,
            targetGas
        );

        return messagingFee.nativeFee;
    }

    /**
     * @notice Target chain amount estimation
     * @param _targetChainId The ID of the target chain
     * @param _appMessage The app message content
     * @param _settings The gateway-specific settings
     * @param _assetAmountData The asset amount data
     * @return amount Target chain amount
     */
    function targetAmount(
        uint256 _targetChainId,
        bytes calldata _appMessage,
        bytes calldata _settings,
        AssetAmountData calldata _assetAmountData
    ) external view returns (uint256 amount) {
        address peerAddress = _checkPeer(_targetChainId);

        uint32 targetLayerZeroEid = standardToLayerZeroChainId[_targetChainId];

        if (targetLayerZeroEid == 0) {
            revert LayerZeroEidNotSetError();
        }

        (uint128 targetGas, ) = _checkSettings(_settings, _targetChainId);

        address carrierAddress = carrierMap[_assetAmountData.assetType];

        bytes calldata appMessage = _appMessage; // stack too deep

        (, SendParam memory sendParam, ) = _prepareParameters(
            carrierAddress,
            targetLayerZeroEid,
            _assetAmountData.amount,
            peerAddress,
            appMessage,
            targetGas
        );

        return sendParam.minAmountLD;
    }

    /**
     * @notice Asset address by type
     * @param _assetType The asset type
     * @return The asset address
     */
    function assetByType(uint256 _assetType) external view returns (address) {
        return assetMap[_assetType];
    }

    /**
     * @notice The value of minimum target gas by the standard chain ID
     * @param _standardChainId The standard EVM ID of the target chain
     * @return The value of minimum target gas
     */
    function minTargetGas(uint256 _standardChainId) public view returns (uint256) {
        DataStructures.OptionalValue storage optionalValue = minTargetGasCustom[_standardChainId];

        if (optionalValue.isSet) {
            return optionalValue.value;
        }

        return minTargetGasDefault;
    }

    function _setEndpoint(address _endpoint) private {
        AddressHelper.requireContract(_endpoint);

        endpoint = _endpoint;

        emit SetEndpoint(_endpoint);
    }

    function _setAsset(uint256 _assetType, address _assetAddress, address _carrierAddress) private {
        address previousAssetAddress = assetMap[_assetType];
        address previousCarrierAddress = carrierMap[_assetType];

        if (_assetAddress != previousAssetAddress || _carrierAddress != previousCarrierAddress) {
            if (isAssetAddress[_assetAddress]) {
                revert DuplicateAssetAddressError(_assetAddress); // The address is set for another asset type
            }

            if (isCarrierAddress[_carrierAddress]) {
                revert DuplicateCarrierAddressError(_carrierAddress); // The address is set for another asset type
            }

            AddressHelper.requireContract(_assetAddress);
            AddressHelper.requireContract(_carrierAddress);

            DataStructures.combinedDoubleMapSet(
                assetMap,
                carrierMap,
                assetTypeList,
                assetTypeIndexMap,
                _assetType,
                _assetAddress,
                _carrierAddress,
                Constants.LIST_SIZE_LIMIT_DEFAULT
            );

            if (previousAssetAddress != address(0)) {
                delete isAssetAddress[previousAssetAddress];
            }

            isCarrierAddress[_carrierAddress] = true;

            if (previousCarrierAddress != address(0)) {
                delete isCarrierAddress[previousCarrierAddress];
            }

            isCarrierAddress[_carrierAddress] = true;
        }

        emit SetAsset(_assetType, _assetAddress, _carrierAddress);
    }

    function _setChainIdPair(uint256 _standardId, uint32 _layerZeroEid) private {
        standardToLayerZeroChainId[_standardId] = _layerZeroEid;
        layerZeroToStandardChainId[_layerZeroEid] = _standardId;

        emit SetChainIdPair(_standardId, _layerZeroEid);
    }

    function _removeChainIdPair(uint256 _standardId) private {
        uint32 layerZeroEid = standardToLayerZeroChainId[_standardId];

        delete standardToLayerZeroChainId[_standardId];
        delete layerZeroToStandardChainId[layerZeroEid];

        emit RemoveChainIdPair(_standardId, layerZeroEid);
    }

    function _setMinTargetGasDefault(uint256 _minTargetGas) private {
        minTargetGasDefault = _minTargetGas;

        emit SetMinTargetGasDefault(_minTargetGas);
    }

    function _setMinTargetGasCustom(uint256 _standardChainId, uint256 _minTargetGas) private {
        minTargetGasCustom[_standardChainId] = DataStructures.OptionalValue({
            isSet: true,
            value: _minTargetGas
        });

        emit SetMinTargetGasCustom(_standardChainId, _minTargetGas);
    }

    function _removeMinTargetGasCustom(uint256 _standardChainId) private {
        delete minTargetGasCustom[_standardChainId];

        emit RemoveMinTargetGasCustom(_standardChainId);
    }

    function _setProcessingFeeCollector(address _processingFeeCollector) private {
        processingFeeCollector = _processingFeeCollector;

        emit SetProcessingFeeCollector(_processingFeeCollector);
    }

    function _checkSettings(
        bytes calldata _settings,
        uint256 _targetChainId
    ) private view returns (uint128 targetGas, uint256 processingFee) {
        (targetGas, processingFee) = abi.decode(_settings, (uint128, uint256));

        uint256 minTargetGasValue = minTargetGas(_targetChainId);

        if (targetGas < minTargetGasValue) {
            revert MinTargetGasError();
        }
    }

    function _checkPeer(uint256 _chainId) private view returns (address) {
        address peerAddress = peerMap[_chainId];

        if (peerAddress == address(0)) {
            revert PeerNotSetError();
        }

        return peerAddress;
    }

    function _prepareParameters(
        address _stargate,
        uint32 _dstEid,
        uint256 _amount,
        address _composer,
        bytes memory _composeMsg,
        uint128 _gas
    )
        internal
        view
        returns (uint256 valueToSend, SendParam memory sendParam, MessagingFee memory messagingFee)
    {
        bytes memory extraOptions = _gas > 0
            ? OptionsBuilder.newOptions().addExecutorLzComposeOption(0, _gas, 0) // compose gas limit
            : bytes('');

        sendParam = SendParam({
            dstEid: _dstEid,
            to: _addressToBytes32(_composer),
            amountLD: _amount,
            minAmountLD: _amount,
            extraOptions: extraOptions,
            composeMsg: _composeMsg,
            oftCmd: ''
        });

        IStargate stargate = IStargate(_stargate);

        (, , OFTReceipt memory receipt) = stargate.quoteOFT(sendParam);
        sendParam.minAmountLD = receipt.amountReceivedLD;

        messagingFee = stargate.quoteSend(sendParam, false);
        valueToSend = messagingFee.nativeFee;

        if (stargate.token() == address(0)) {
            valueToSend += sendParam.amountLD;
        }
    }

    function _addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }
}