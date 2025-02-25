// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import {Ownable} from "./openzeppelin_contracts_access_Ownable.sol";
import {IERC20} from "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import {SafeERC20} from "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";
import {ILogAutomation, Log} from "./chainlink_contracts_src_v0.8_automation_interfaces_ILogAutomation.sol";
import {IKeeperRegistryMaster} from "./chainlink_contracts_src_v0.8_automation_interfaces_v2_1_IKeeperRegistryMaster.sol";
import {IVoter} from "./vendor_velodrome-contracts_contracts_interfaces_IVoter.sol";
import {IPool} from "./vendor_velodrome-contracts_contracts_interfaces_IPool.sol";
import {IFactoryRegistry} from "./vendor_velodrome-contracts_contracts_interfaces_factories_IFactoryRegistry.sol";
import {IAutomationRegistrar} from "./contracts_interfaces_IAutomationRegistrar.sol";
import {IGaugeUpkeepManager} from "./contracts_interfaces_IGaugeUpkeepManager.sol";
import {ICronUpkeepFactory} from "./contracts_interfaces_ICronUpkeepFactory.sol";

contract GaugeUpkeepManager is IGaugeUpkeepManager, ILogAutomation, Ownable {
    using SafeERC20 for IERC20;

    /// @inheritdoc IGaugeUpkeepManager
    address public immutable override linkToken;
    /// @inheritdoc IGaugeUpkeepManager
    address public immutable override keeperRegistry;
    /// @inheritdoc IGaugeUpkeepManager
    address public immutable override automationRegistrar;
    /// @inheritdoc IGaugeUpkeepManager
    address public immutable override cronUpkeepFactory;
    /// @inheritdoc IGaugeUpkeepManager
    address public immutable override voter;
    /// @inheritdoc IGaugeUpkeepManager
    address public immutable override factoryRegistry;

    /// @inheritdoc IGaugeUpkeepManager
    uint96 public override newUpkeepFundAmount;
    /// @inheritdoc IGaugeUpkeepManager
    uint32 public override newUpkeepGasLimit;
    /// @inheritdoc IGaugeUpkeepManager
    mapping(address => bool) public override trustedForwarder;
    /// @inheritdoc IGaugeUpkeepManager
    mapping(address => bool) public override crosschainGaugeFactory;

    /// @inheritdoc IGaugeUpkeepManager
    mapping(address => uint256) public override gaugeUpkeepId;
    /// @inheritdoc IGaugeUpkeepManager
    uint256[] public override activeUpkeepIds;

    uint8 private constant CONDITIONAL_TRIGGER_TYPE = 0;
    string private constant UPKEEP_NAME = "cron upkeep";
    string private constant CRON_EXPRESSION = "0 0 * * 4";
    string private constant DISTRIBUTE_FUNCTION = "distribute(address[])";

    bytes32 private constant GAUGE_CREATED_SIGNATURE =
        0xef9f7d1ffff3b249c6b9bf2528499e935f7d96bb6d6ec4e7da504d1d3c6279e1;
    bytes32 private constant GAUGE_KILLED_SIGNATURE =
        0x04a5d3f5d80d22d9345acc80618f4a4e7e663cf9e1aed23b57d975acec002ba7;
    bytes32 private constant GAUGE_REVIVED_SIGNATURE =
        0xed18e9faa3dccfd8aa45f69c4de40546b2ca9cccc4538a2323531656516db1aa;

    constructor(
        address _linkToken,
        address _keeperRegistry,
        address _automationRegistrar,
        address _cronUpkeepFactory,
        address _voter,
        uint96 _newUpkeepFundAmount,
        uint32 _newUpkeepGasLimit,
        address[] memory _crosschainGaugeFactories
    ) {
        linkToken = _linkToken;
        keeperRegistry = _keeperRegistry;
        automationRegistrar = _automationRegistrar;
        cronUpkeepFactory = _cronUpkeepFactory;
        voter = _voter;
        newUpkeepFundAmount = _newUpkeepFundAmount;
        newUpkeepGasLimit = _newUpkeepGasLimit;

        // Initialize crosschain gauge factories
        for (uint256 i = 0; i < _crosschainGaugeFactories.length; i++) {
            crosschainGaugeFactory[_crosschainGaugeFactories[i]] = true;
        }
        factoryRegistry = IVoter(_voter).factoryRegistry();
    }

    /// @notice Called by the automation DON when a new log is emitted by the target contract
    /// @param _log the raw log data matching the filter that this contract has registered as a trigger
    /// @dev This function is called by the automation DON to check if any action is needed
    /// @return upkeepNeeded True if any action is needed according to the log
    /// @return performData Encoded action and data passed to performUpkeep if upkeepNeeded is true
    function checkLog(
        Log calldata _log,
        bytes memory
    ) external view override returns (bool upkeepNeeded, bytes memory performData) {
        bytes32 eventSignature = _log.topics[0];
        if (eventSignature == GAUGE_CREATED_SIGNATURE) {
            address gaugeFactory = _bytes32ToAddress(_log.topics[3]);
            address gauge = _extractGaugeFromCreatedLog(_log);
            if (gaugeUpkeepId[gauge] == 0 && !_isCrosschainGaugeFactory(gaugeFactory)) {
                return (true, abi.encode(PerformAction.REGISTER_UPKEEP, gauge));
            }
        } else if (eventSignature == GAUGE_KILLED_SIGNATURE) {
            address gauge = _bytes32ToAddress(_log.topics[1]);
            if (gaugeUpkeepId[gauge] != 0) {
                return (true, abi.encode(PerformAction.CANCEL_UPKEEP, gauge));
            }
        } else if (eventSignature == GAUGE_REVIVED_SIGNATURE) {
            address gauge = _bytes32ToAddress(_log.topics[1]);
            address gaugeFactory = _getGaugeFactoryFromGauge(gauge);
            if (gaugeUpkeepId[gauge] == 0 && !_isCrosschainGaugeFactory(gaugeFactory)) {
                return (true, abi.encode(PerformAction.REGISTER_UPKEEP, gauge));
            }
        }
    }

    /// @notice Perform the upkeep action according to the performData passed from checkUpkeep/checkLog
    /// @param _performData the data which was passed back from the checkData simulation
    /// @dev This function is called by the automation network to perform the upkeep action
    function performUpkeep(bytes calldata _performData) external override {
        if (!trustedForwarder[msg.sender]) {
            revert UnauthorizedSender();
        }
        (PerformAction action, address gauge) = abi.decode(_performData, (PerformAction, address));
        if (action == PerformAction.REGISTER_UPKEEP) {
            _registerGaugeUpkeep(gauge);
        } else if (action == PerformAction.CANCEL_UPKEEP) {
            _cancelGaugeUpkeep(gauge);
        } else {
            revert InvalidPerformAction();
        }
    }

    function _registerGaugeUpkeep(address _gauge) internal returns (uint256 upkeepId) {
        address[] memory gauges = new address[](1);
        gauges[0] = _gauge;
        address cronUpkeep = ICronUpkeepFactory(cronUpkeepFactory).newCronUpkeep(
            voter,
            abi.encodeWithSignature(DISTRIBUTE_FUNCTION, gauges),
            CRON_EXPRESSION
        );
        IAutomationRegistrar.RegistrationParams memory params = IAutomationRegistrar.RegistrationParams({
            name: UPKEEP_NAME,
            encryptedEmail: "",
            upkeepContract: address(cronUpkeep),
            gasLimit: newUpkeepGasLimit,
            adminAddress: address(this),
            triggerType: CONDITIONAL_TRIGGER_TYPE,
            checkData: "",
            triggerConfig: "",
            offchainConfig: "",
            amount: newUpkeepFundAmount
        });
        upkeepId = _registerUpkeep(params);
        activeUpkeepIds.push(upkeepId);
        gaugeUpkeepId[_gauge] = upkeepId;
        emit GaugeUpkeepRegistered(_gauge, upkeepId);
    }

    function _registerUpkeep(IAutomationRegistrar.RegistrationParams memory _params) internal returns (uint256) {
        IERC20(linkToken).approve(automationRegistrar, _params.amount);
        uint256 upkeepID = IAutomationRegistrar(automationRegistrar).registerUpkeep(_params);
        if (upkeepID != 0) {
            return upkeepID;
        } else {
            revert AutoApproveDisabled();
        }
    }

    function _cancelGaugeUpkeep(address _gauge) internal returns (uint256 upkeepId) {
        upkeepId = gaugeUpkeepId[_gauge];
        uint256 length = activeUpkeepIds.length;
        for (uint256 i = 0; i < length; i++) {
            if (activeUpkeepIds[i] == upkeepId) {
                activeUpkeepIds[i] = activeUpkeepIds[length - 1];
                activeUpkeepIds.pop();
                break;
            }
        }
        delete gaugeUpkeepId[_gauge];
        IKeeperRegistryMaster(keeperRegistry).cancelUpkeep(upkeepId);
        emit GaugeUpkeepCancelled(_gauge, upkeepId);
    }

    function _extractGaugeFromCreatedLog(Log memory _log) internal pure returns (address gauge) {
        (, , , gauge, ) = abi.decode(_log.data, (address, address, address, address, address));
    }

    function _bytes32ToAddress(bytes32 _address) internal pure returns (address) {
        return address(uint160(uint256(_address)));
    }

    function _getGaugeFactoryFromGauge(address _gauge) internal view returns (address gaugeFactory) {
        address pool = IVoter(voter).poolForGauge(_gauge);
        address poolFactory = IPool(pool).factory();
        (, gaugeFactory) = IFactoryRegistry(factoryRegistry).factoriesToPoolFactory(poolFactory);
    }

    function _isCrosschainGaugeFactory(address _gaugeFactory) internal view returns (bool) {
        return crosschainGaugeFactory[_gaugeFactory];
    }

    /// @inheritdoc IGaugeUpkeepManager
    function activeUpkeepsCount() external view override returns (uint256) {
        return activeUpkeepIds.length;
    }

    /// @inheritdoc IGaugeUpkeepManager
    function withdrawUpkeep(uint256 _upkeepId) external override onlyOwner {
        IKeeperRegistryMaster(keeperRegistry).withdrawFunds(_upkeepId, address(this));
        emit GaugeUpkeepWithdrawn(_upkeepId);
    }

    /// @inheritdoc IGaugeUpkeepManager
    function withdrawLinkBalance() external override onlyOwner {
        address receiver = owner();
        uint256 balance = IERC20(linkToken).balanceOf(address(this));
        if (balance == 0) {
            revert NoLinkBalance();
        }
        IERC20(linkToken).safeTransfer(receiver, balance);
        emit LinkBalanceWithdrawn(receiver, balance);
    }

    /// @inheritdoc IGaugeUpkeepManager
    function setNewUpkeepGasLimit(uint32 _newUpkeepGasLimit) external override onlyOwner {
        newUpkeepGasLimit = _newUpkeepGasLimit;
        emit NewUpkeepGasLimitSet(_newUpkeepGasLimit);
    }

    /// @inheritdoc IGaugeUpkeepManager
    function setNewUpkeepFundAmount(uint96 _newUpkeepFundAmount) external override onlyOwner {
        newUpkeepFundAmount = _newUpkeepFundAmount;
        emit NewUpkeepFundAmountSet(_newUpkeepFundAmount);
    }

    /// @inheritdoc IGaugeUpkeepManager
    function setTrustedForwarder(address _trustedForwarder, bool _isTrusted) external override onlyOwner {
        if (_trustedForwarder == address(0)) {
            revert AddressZeroNotAllowed();
        }
        trustedForwarder[_trustedForwarder] = _isTrusted;
        emit TrustedForwarderSet(_trustedForwarder, _isTrusted);
    }

    /// @inheritdoc IGaugeUpkeepManager
    function registerGaugeUpkeeps(
        address[] calldata _gauges
    ) external override onlyOwner returns (uint256[] memory upkeepIds) {
        address gauge;
        address gaugeFactory;
        uint256 length = _gauges.length;
        for (uint256 i = 0; i < length; i++) {
            gauge = _gauges[i];
            if (gaugeUpkeepId[gauge] != 0) {
                revert GaugeUpkeepExists(gauge);
            }
            if (!IVoter(voter).isGauge(gauge)) {
                revert NotGauge(gauge);
            }
            gaugeFactory = _getGaugeFactoryFromGauge(gauge);
            if (_isCrosschainGaugeFactory(gaugeFactory)) {
                revert CrosschainGaugeNotAllowed(gauge);
            }
        }
        upkeepIds = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            upkeepIds[i] = _registerGaugeUpkeep(_gauges[i]);
        }
    }

    /// @inheritdoc IGaugeUpkeepManager
    function deregisterGaugeUpkeeps(
        address[] calldata _gauges
    ) external override onlyOwner returns (uint256[] memory upkeepIds) {
        address gauge;
        uint256 length = _gauges.length;
        for (uint256 i = 0; i < length; i++) {
            gauge = _gauges[i];
            if (gaugeUpkeepId[gauge] == 0) {
                revert GaugeUpkeepNotFound(gauge);
            }
        }
        upkeepIds = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            upkeepIds[i] = _cancelGaugeUpkeep(_gauges[i]);
        }
    }
}