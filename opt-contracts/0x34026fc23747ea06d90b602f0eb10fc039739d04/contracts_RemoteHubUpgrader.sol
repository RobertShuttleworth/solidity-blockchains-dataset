// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {IRouterClient} from "./chainlink_contracts-ccip_src_v0.8_ccip_interfaces_IRouterClient.sol";
import {Client} from "./chainlink_contracts-ccip_src_v0.8_ccip_libraries_Client.sol";
import {CCIPReceiver} from "./chainlink_contracts-ccip_src_v0.8_ccip_applications_CCIPReceiver.sol";
import {IERC20} from "./chainlink_contracts-ccip_src_v0.8_vendor_openzeppelin-solidity_v4.8.3_contracts_token_ERC20_IERC20.sol";
import {SafeERC20} from "./chainlink_contracts-ccip_src_v0.8_vendor_openzeppelin-solidity_v4.8.3_contracts_token_ERC20_utils_SafeERC20.sol";
import {Initializable} from "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";
import {AccessControlUpgradeable, IAccessControlUpgradeable, IERC165Upgradeable} from "./openzeppelin_contracts-upgradeable_access_AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "./openzeppelin_contracts-upgradeable_proxy_utils_UUPSUpgradeable.sol";
import {PausableUpgradeable} from "./openzeppelin_contracts-upgradeable_security_PausableUpgradeable.sol";

import {IRemoteHub, IPayoutManager, IRoleManager, IExchange, IRemoteHubUpgrader} from "./contracts_interfaces_IRemoteHub.sol";
import {NonRebaseInfo} from "./contracts_interfaces_IPayoutManager.sol";

contract RemoteHubUpgrader is CCIPReceiver, Initializable, AccessControlUpgradeable, UUPSUpgradeable, PausableUpgradeable, IRemoteHubUpgrader {

    address public constant ZERO_ADDRESS = 0x0000000000000000000000000000000000000000;

    struct MultichainCallUpgradeItem {
        uint64 chainSelector;
        address receiver;
        DataCallItem[] batchData;
    }

    struct DataCallItem {
        address executor;
        bytes data;
    }

    // Mapping to keep track of allowlisted destination chains.
    mapping(uint64 => bool) public allowlistedDestinationChains;

    // Mapping to keep track of allowlisted source chains.
    mapping(uint64 => bool) public allowlistedSourceChains;

    // Mapping to keep track of allowlisted senders.
    mapping(address => bool) public allowlistedSenders;

    mapping(uint64 => mapping(address => bool)) public allowlistedDestinationAddresses;
    
    IRemoteHub public remoteHub;

    uint64 public chainSelector;
    uint256 public ccipGasLimit;

    // ---  events

    // Event emitted when a message is sent to another chain.
    event MessageSent(
        bytes32 indexed messageId, // The unique ID of the CCIP message.
        uint64 indexed destinationChainSelector, // The chain selector of the destination chain.
        address receiver, // The address of the receiver on the destination chain.
        bytes data, // The text being sent.
        address feeToken, // the token address used to pay CCIP fees.
        uint256 fees // The fees paid for sending the message.
    );

    // Event emitted when a message is received from another chain.
    event MessageReceived(
        bytes32 indexed messageId, // The unique ID of the CCIP message.
        uint64 indexed sourceChainSelector, // The chain selector of the source chain.
        address sender, // The address of the sender from the source chain.
        DataCallItem[] data, // The text that was received.
        address token, // The token address that was transferred.
        uint256 tokenAmount // The token amount that was transferred.
    );

    event CallExecuted(
        address indexed target,
        bool success,
        bytes data
    );

    event RemoteHubUpdated(address remoteHub);

    // ---  errors

    error NotEnoughBalance(uint256 currentBalance, uint256 calculatedFees); // Used to make sure contract has enough balance.
    error DestinationChainNotAllowlisted(uint64 destinationChainSelector); // Used when the destination chain has not been allowlisted by the contract owner.
    error SourceChainNotAllowlisted(uint64 sourceChainSelector); // Used when the source chain has not been allowlisted by the contract owner.
    error SenderNotAllowlisted(address sender); // Used when the sender has not been allowlisted by the contract owner.
    error InvalidReceiverAddress(); // Used when the receiver address is 0.
    error ExecutorIsTheSameContract();

    // ---  initializer

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address _router, address _remoteHub) CCIPReceiver(_router) {
        _disableInitializers();
        remoteHub = IRemoteHub(_remoteHub);
    }

    /**
     * @notice Initializes the contract
     * @param _chainSelector The chain selector for this contract
     */
    function initialize(uint64 _chainSelector) initializer public {
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE(), msg.sender);
        chainSelector = _chainSelector;
        ccipGasLimit = 500_000;
    }

    /**
     * @notice Checks if the contract supports a given interface
     * @param interfaceId The interface identifier
     * @return bool True if the interface is supported
     */
    function supportsInterface(bytes4 interfaceId) public view override(CCIPReceiver, AccessControlUpgradeable) returns (bool) {
        return (interfaceId == type(IAccessControlUpgradeable).interfaceId) || 
               (interfaceId == type(IERC165Upgradeable).interfaceId) || 
               CCIPReceiver.supportsInterface(interfaceId);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyUpgrader {}

    // ---  remoteHub getters

    function exchange() public view returns(IExchange) {
        return remoteHub.exchange();
    }

    function roleManager() public view returns(IRoleManager) {
        return remoteHub.roleManager();
    }

    // ---  modifiers

    /// @dev Modifier that checks if the chain with the given destinationChainSelector is allowlisted.
    /// @param _destinationChainSelector The selector of the destination chain.
    modifier onlyAllowlistedDestinationChain(uint64 _destinationChainSelector) {
        if (!allowlistedDestinationChains[_destinationChainSelector])
            revert DestinationChainNotAllowlisted(_destinationChainSelector);
        _;
    }

    /// @dev Modifier that checks if the chain with the given sourceChainSelector is allowlisted and if the sender is allowlisted.
    /// @param _sourceChainSelector The selector of the destination chain.
    /// @param _sender The address of the sender.
    modifier onlyAllowlisted(uint64 _sourceChainSelector, address _sender) {
        if (!allowlistedSourceChains[_sourceChainSelector])
            revert SourceChainNotAllowlisted(_sourceChainSelector);
        if (!allowlistedSenders[_sender]) revert SenderNotAllowlisted(_sender);
        _;
    }

    /// @dev Modifier that checks the receiver address is not 0.
    /// @param _receiver The receiver address.
    modifier validateReceiver(address _receiver) {
        if (_receiver == address(0)) revert InvalidReceiverAddress();
        _;
    }

    modifier onlyAdmin() {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Caller doesn't have DEFAULT_ADMIN_ROLE role");
        _;
    }

    modifier onlyPortfolioAgent() {
        require(roleManager().hasRole(roleManager().PORTFOLIO_AGENT_ROLE(), msg.sender), "Caller doesn't have PORTFOLIO_AGENT_ROLE role");
        _;
    }

    modifier onlyUpgrader() {
        require(hasRole(UPGRADER_ROLE(), msg.sender), "Caller doesn't have UPGRADER_ROLE role");
        _;
    }

    function UPGRADER_ROLE() public pure returns(bytes32) {
        return keccak256("UPGRADER_ROLE");
    }

    // --- setters

    /**
     * @notice Pauses the contract
     */
    function pause() public onlyPortfolioAgent {
        _pause();
    }

    /**
     * @notice Unpauses the contract
     */
    function unpause() public onlyPortfolioAgent {
        _unpause();
    }

    /**
     * @notice Sets the RemoteHub address
     * @param _remoteHub The new RemoteHub address
     */
    function setRemoteHub(address _remoteHub) external onlyUpgrader {
        remoteHub = IRemoteHub(_remoteHub);
        emit RemoteHubUpdated(_remoteHub);
    }

    // ---  logic

    /**
     * @notice Updates the allowlist status of a destination chain for transactions
     * @param _destinationChainSelector The selector of the destination chain
     * @param allowed The new allowlist status
     */
    function allowlistDestinationChain(uint64 _destinationChainSelector, bool allowed) external onlyUpgrader {
        allowlistedDestinationChains[_destinationChainSelector] = allowed;
    }

    /**
     * @notice Updates the allowlist status of a source chain for transactions
     * @param _sourceChainSelector The selector of the source chain
     * @param allowed The new allowlist status
     */
    function allowlistSourceChain(uint64 _sourceChainSelector, bool allowed) external onlyUpgrader {
        allowlistedSourceChains[_sourceChainSelector] = allowed;
    }

    /**
     * @notice Updates the allowlist status of a sender for transactions
     * @param _sender The address of the sender
     * @param allowed The new allowlist status
     */
    function allowlistSender(address _sender, bool allowed) external onlyUpgrader {
        allowlistedSenders[_sender] = allowed;
    }

    /**
     * @notice Set new gasLimit for CCIP send
     * @param _ccipGasLimit The new gas limit for CCIP transactions
     */
    function setCcipGasLimit(uint256 _ccipGasLimit) external onlyUpgrader {
        ccipGasLimit = _ccipGasLimit;
    }

    function _sendViaCCIP(MultichainCallUpgradeItem memory item) internal
        onlyAllowlistedDestinationChain(item.chainSelector)
        validateReceiver(item.receiver)
        returns (bytes32 messageId)
    {   
        Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(item);
        IRouterClient router = IRouterClient(this.getRouter());
        uint256 fees = router.getFee(item.chainSelector, evm2AnyMessage);

        if (fees > address(this).balance)
            revert NotEnoughBalance(address(this).balance, fees);

        messageId = router.ccipSend{value: fees}(item.chainSelector, evm2AnyMessage);
        emit MessageSent(messageId, item.chainSelector, item.receiver, abi.encode(item.batchData), address(0), fees);

        return messageId;
    }

    /// handle a received message
    function _ccipReceive(Client.Any2EVMMessage memory any2EvmMessage) internal override
        onlyAllowlisted(any2EvmMessage.sourceChainSelector, abi.decode(any2EvmMessage.sender, (address))) 
    {
        DataCallItem[] memory receivedData = abi.decode(any2EvmMessage.data, (DataCallItem[]));
        for (uint i = 0; i < receivedData.length; ++i) {
            if (receivedData[i].executor == address(this)) {
                revert ExecutorIsTheSameContract();
            } else {
                (bool success, bytes memory data) = receivedData[i].executor.call(receivedData[i].data);
                require(success, "Call failed");
                emit CallExecuted(receivedData[i].executor, success, data);
            }
        }

        emit MessageReceived(
            any2EvmMessage.messageId,
            any2EvmMessage.sourceChainSelector,
            abi.decode(any2EvmMessage.sender, (address)),
            abi.decode(any2EvmMessage.data, (DataCallItem[])),
            any2EvmMessage.destTokenAmounts.length == 0 ? address(0) : any2EvmMessage.destTokenAmounts[0].token,
            any2EvmMessage.destTokenAmounts.length == 0 ? 0 : any2EvmMessage.destTokenAmounts[0].amount
        );
    }

    function _buildCCIPMessage(MultichainCallUpgradeItem memory item) private view returns (Client.EVM2AnyMessage memory) {
        
        return
            Client.EVM2AnyMessage({
                receiver: abi.encode(item.receiver),
                data: abi.encode(item.batchData),
                tokenAmounts: new Client.EVMTokenAmount[](0),
                extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: ccipGasLimit})),
                feeToken: address(0)
            });
    }

    receive() external payable {}

    /**
     * @notice Executes multiple cross-chain calls
     * @param multichainCallItems An array of MultichainCallUpgradeItem structs representing the calls to be made
     */
    function multichainCall(MultichainCallUpgradeItem[] memory multichainCallItems) public payable whenNotPaused onlyAdmin {
        for (uint256 i; i < multichainCallItems.length; ++i) {
            if (multichainCallItems[i].chainSelector == chainSelector && multichainCallItems[i].receiver != address(this)) {
            } else if (multichainCallItems[i].chainSelector == chainSelector && multichainCallItems[i].receiver == address(this)) {
                for (uint j = 0; j < multichainCallItems[i].batchData.length; ++j) {
                    (bool success, bytes memory data) = multichainCallItems[i].batchData[j].executor.call(multichainCallItems[i].batchData[j].data);
                    require(success, "Call failed");
                    emit CallExecuted(address(this), success, data);
                }
            } else {
                _sendViaCCIP(multichainCallItems[i]);
            }
        }
    }

}