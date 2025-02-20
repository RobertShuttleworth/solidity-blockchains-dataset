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

import {IRemoteHub, IXusdToken, IPayoutManager, IRoleManager, IExchange, IWrappedXusdToken, IMarket, IRemoteHubUpgrader, ChainItem} from "./contracts_interfaces_IRemoteHub.sol";
import {NonRebaseInfo} from "./contracts_interfaces_IPayoutManager.sol";

/**
 * @title RemoteHub
 * @notice This contract manages cross-chain communication and token transfers using Chainlink's CCIP
 */
contract RemoteHub is IRemoteHub, CCIPReceiver, Initializable, AccessControlUpgradeable, UUPSUpgradeable, PausableUpgradeable {
    using SafeERC20 for IERC20;

    struct MultichainCallItem {
        uint64 chainSelector;
        address receiver;
        address token;
        uint256 amount;
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

    ChainItem[] public chainItems;
    mapping(uint64 => ChainItem) public chainItemById;
    mapping(uint64 => mapping(address => bool)) public allowlistedDestinationAddresses;
    uint64 public chainSelector;
    uint64 public sourceChainSelector;
    uint256 public ccipGasLimit;

    // ---  events

    // Event emitted when a message is sent to another chain.
    event MessageSent(
        bytes32 indexed messageId, // The unique ID of the CCIP message.
        uint64 indexed destinationChainSelector, // The chain selector of the destination chain.
        address receiver, // The address of the receiver on the destination chain.
        bytes data, // The text being sent.
        address token, // The token address that was transferred.
        uint256 tokenAmount, // The token amount that was transferred.
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

    // ---  errors

    error NotEnoughBalance(uint256 currentBalance, uint256 calculatedFees); // Used to make sure contract has enough balance.
    error NothingToWithdraw(); // Used when trying to withdraw Ether but there's nothing to withdraw.
    error FailedToWithdrawEth(address owner, address target, uint256 value); // Used when the withdrawal of Ether fails.
    error DestinationChainNotAllowlisted(uint64 destinationChainSelector); // Used when the destination chain has not been allowlisted by the contract owner.
    error SourceChainNotAllowlisted(uint64 sourceChainSelector); // Used when the source chain has not been allowlisted by the contract owner.
    error SenderNotAllowlisted(address sender); // Used when the sender has not been allowlisted by the contract owner.
    error InvalidReceiverAddress(); // Used when the receiver address is 0.
    error ExecutorIsTheSameContract();

    // ---  initializer

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address _router) CCIPReceiver(_router) {
        _disableInitializers();
    }

    /**
     * @notice Initializes the contract
     * @param _chainSelector The chain selector for this contract
     */
    function initialize(uint64 _chainSelector, uint64 _sourceChainSelector) initializer public {
        __AccessControl_init();
        __Pausable_init();
        __UUPSUpgradeable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE(), msg.sender);
        chainSelector = _chainSelector;
        sourceChainSelector = _sourceChainSelector;
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

    function ccipPool() public view returns(address) {
        return chainItemById[chainSelector].ccipPool;
    }

    function xusd() public view returns(IXusdToken) {
        return IXusdToken(chainItemById[chainSelector].xusd);
    }

    function exchange() public view returns(IExchange) {
        return IExchange(chainItemById[chainSelector].exchange);
    }

    function payoutManager() public view returns(IPayoutManager) {
        return IPayoutManager(chainItemById[chainSelector].payoutManager);
    }

    function roleManager() public view returns(IRoleManager) {
        return IRoleManager(chainItemById[chainSelector].roleManager);
    }

    function remoteHub() public view returns(IRemoteHub) {
        return IRemoteHub(chainItemById[chainSelector].remoteHub);
    }

    function remoteHubUpgrader() public view returns(IRemoteHubUpgrader) {
        return IRemoteHubUpgrader(chainItemById[chainSelector].remoteHubUpgrader);
    }

    function wxusd() public view returns(IWrappedXusdToken) {
        return IWrappedXusdToken(chainItemById[chainSelector].wxusd);
    }

    function market() public view returns(IMarket) {
        return IMarket(chainItemById[chainSelector].market);
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

    modifier onlyExchanger() {
        require(address(exchange()) == msg.sender, "Caller is not the EXCHANGER");
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

    // ---  logic

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
     * @notice Adds or updates a chain item in the chainItems array and mapping
     * @param chainItem The chain item to add or update
     */
    function addChainItem(ChainItem memory chainItem) public onlyUpgrader {

        for (uint256 i = 0; i < chainItems.length; ++i) {
            ChainItem memory item = chainItems[i];

            if (item.chainSelector == chainItem.chainSelector) {
                chainItems[i] = chainItem;
                return;
            }
        }

        chainItems.push(chainItem);
        chainItemById[chainItem.chainSelector] = chainItem;
    }

    /**
     * @notice Removes a chain item from the chainItems array
     * @param _chainSelector The chain selector of the item to remove
     */
    function removeChainItem(uint64 _chainSelector) public onlyUpgrader {
        uint256 index = type(uint256).max;
        for (uint256 i = 0; i < chainItems.length; ++i) {
            if (chainItems[i].chainSelector == _chainSelector) {
                index = i;
            }
        }

        if (index != type(uint256).max) {
            ChainItem memory tempItem = chainItems[chainItems.length - 1];
            chainItems[index] = tempItem;
            chainItems.pop();
        }
    }

    function getChainItemById(uint64 key) public view returns(ChainItem memory) {
        return chainItemById[key];
    }

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

    // @notice Sends a message via CCIP
    function _sendViaCCIP(MultichainCallItem memory item) internal
        onlyAllowlistedDestinationChain(item.chainSelector)
        validateReceiver(item.receiver)
        returns (bytes32 messageId)
    {
        Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(item);
        IRouterClient router = IRouterClient(this.getRouter());
        uint256 fees = router.getFee(item.chainSelector, evm2AnyMessage);

        if (fees > address(this).balance)
            revert NotEnoughBalance(address(this).balance, fees);

        if (item.amount > 0) {
            IERC20(item.token).approve(address(router), 0); // because of race condition fix
            IERC20(item.token).approve(address(router), item.amount);
        }

        messageId = router.ccipSend{value: fees}(item.chainSelector, evm2AnyMessage);

        emit MessageSent(messageId, item.chainSelector, item.receiver, abi.encode(item.batchData), item.token, item.amount, address(0), fees);

        return messageId;
    }

    // @notice Handles received CCIP messages
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

    function _buildCCIPMessage(MultichainCallItem memory item) private view returns (Client.EVM2AnyMessage memory) {

        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({
            token: item.token,
            amount: item.amount
        });

        return
            Client.EVM2AnyMessage({
                receiver: abi.encode(item.receiver),
                data: abi.encode(item.batchData),
                tokenAmounts: (item.amount == 0) ? new Client.EVMTokenAmount[](0) : tokenAmounts,
                extraArgs: Client._argsToBytes(
                    Client.EVMExtraArgsV1({gasLimit: ccipGasLimit})
                ),
                feeToken: address(0)
            });
    }

    receive() external payable {}

    /**
     * @notice Withdraws native tokens from the contract
     * @param _beneficiary The address to receive the withdrawn tokens
     */
    function withdraw(address _beneficiary) public onlyUpgrader {
        uint256 amount = address(this).balance;

        if (amount == 0) {
            revert NothingToWithdraw();
        }

        (bool sent, ) = _beneficiary.call{value: amount}("");

        if (!sent) {
            revert FailedToWithdrawEth(msg.sender, _beneficiary, amount);
        }
    }

    /**
     * @notice Withdraws ERC20 tokens from the contract
     * @param _beneficiary The address to receive the withdrawn tokens
     * @param _token The address of the ERC20 token to withdraw
     */
    function withdrawToken(address _beneficiary, address _token) public onlyUpgrader {
        
        uint256 amount = IERC20(_token).balanceOf(address(this));

        if (amount == 0) {
            revert NothingToWithdraw();
        }

        IERC20(_token).safeTransfer(_beneficiary, amount);
    }

    /**
     * @notice Executes multiple cross-chain calls
     * @param multichainCallItems An array of MultichainCallItem structs representing the calls to be made
     */
    function multichainCall(MultichainCallItem[] memory multichainCallItems) public payable whenNotPaused onlyAdmin {
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

    /**
     * @notice Executes multi-chain payout
     * @param newDelta The new delta value for the payout
     */
    function execMultiPayout(uint256 newDelta) public payable whenNotPaused onlyExchanger {
        require(sourceChainSelector == chainSelector, "supported only on motherchain");
        for (uint256 i = 1; i < chainItems.length; ++i) {
            DataCallItem[] memory dataCallItems = new DataCallItem[](1);
            dataCallItems[0] = DataCallItem({
                executor: chainItems[i].exchange,
                data: abi.encodeWithSignature("payout(uint256)", newDelta)
            });
            MultichainCallItem memory multichainCallItem = MultichainCallItem({
                chainSelector: chainItems[i].chainSelector,
                receiver: chainItems[i].remoteHub,
                token: address(0),
                amount: 0,
                batchData: dataCallItems
            });
            _sendViaCCIP(multichainCallItem);
        }
    }

    /**
     * @notice Performs a cross-chain token transfer
     * @param _to The address to receive the tokens on the destination chain
     * @param _amount The amount of tokens to transfer
     * @param _destinationChainSelector The selector of the destination chain
     */
    function crossTransfer(address _to, uint256 _amount, uint64 _destinationChainSelector) 
    onlyAllowlistedDestinationChain(_destinationChainSelector)
    whenNotPaused 
    payable public {
        IXusdToken _xusd = xusd();
        IWrappedXusdToken _wxusd = wxusd();
        IERC20(address(_xusd)).safeTransferFrom(msg.sender, address(this), _amount);
        _xusd.approve(address(chainItemById[chainSelector].market), _xusd.balanceOf(address(this)));
        IMarket(chainItemById[chainSelector].market).wrap(address(_xusd), _xusd.balanceOf(address(this)), address(this));

        DataCallItem[] memory dataCallItems = new DataCallItem[](2);
        
        dataCallItems[0] = DataCallItem({
            executor: chainItemById[_destinationChainSelector].wxusd,
            data: abi.encodeWithSignature("approve(address,uint256)", chainItemById[_destinationChainSelector].market, _wxusd.balanceOf(address(this)))
        });
        dataCallItems[1] = DataCallItem({
            executor: chainItemById[_destinationChainSelector].market,
            data: abi.encodeWithSignature("unwrap(address,uint256,address)", chainItemById[_destinationChainSelector].xusd, _wxusd.balanceOf(address(this)), _to)
        });

        MultichainCallItem memory multichainCallItem = MultichainCallItem({
                chainSelector: _destinationChainSelector,
                receiver: chainItemById[_destinationChainSelector].remoteHub,
                token: chainItemById[chainSelector].wxusd,
                amount: _wxusd.balanceOf(address(this)),
                batchData: dataCallItems
            });

        _sendViaCCIP(multichainCallItem);
    }

}