// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

/*@@@@@@@       @@@@@@@@@
 @@@@@@@@@       @@@@@@@@@
  @@@@@@@@@       @@@@@@@@@
   @@@@@@@@@       @@@@@@@@@
    @@@@@@@@@@@@@@@@@@@@@@@@@
     @@@@@  HYPERLANE  @@@@@@@
    @@@@@@@@@@@@@@@@@@@@@@@@@
   @@@@@@@@@       @@@@@@@@@
  @@@@@@@@@       @@@@@@@@@
 @@@@@@@@@       @@@@@@@@@
@@@@@@@@@       @@@@@@@@*/

// ============ Internal Imports ============
import {InterchainAccountMessage} from "./hyperlane-xyz_core_contracts_middleware_libs_InterchainAccountMessage.sol";
import {CallLib} from "./hyperlane-xyz_core_contracts_middleware_libs_Call.sol";
import {StandardHookMetadata} from "./hyperlane-xyz_core_contracts_hooks_libs_StandardHookMetadata.sol";

import {EnumerableMapExtended} from "./hyperlane-xyz_core_contracts_libs_EnumerableMapExtended.sol";
import {TypeCasts} from "./hyperlane-xyz_core_contracts_libs_TypeCasts.sol";
import {HRouter} from "./contracts_client_HRouter.sol";
import {HOwnable} from "./contracts_access_HOwnable.sol";

// ============ External Imports ============
import {Create2} from "./openzeppelin_contracts_utils_Create2.sol";
import {Address} from "./openzeppelin_contracts_utils_Address.sol";
import {Ownable} from "./openzeppelin_contracts_access_Ownable.sol";
import {IERC20} from "./openzeppelin_contracts_token_ERC20_IERC20.sol";

import {IUniswapV2Router02} from "./contracts_interfaces_IUniswapV2Router02.sol";
import {IV3SwapRouter} from "./contracts_interfaces_IV3SwapRouter.sol";

/*
 * @title A contract that allows accounts on chain A to call contracts via a
 * proxy contract on chain B.
 */
contract HInterchainBridge is HOwnable, HRouter {

    // ============ Libraries ============

    using TypeCasts for address;
    using TypeCasts for bytes32;

    bytes32 public lastSender;
    bytes public lastData;

    struct AccountOwner {
        uint32 origin;
        bytes32 owner; // remote owner
    }

    event ReceivedMessage(
        uint32 indexed origin,
        bytes32 indexed sender,
        uint256 indexed value,
        string message
    );

    // ============ Public Storage ============

    mapping(uint32 => bytes32) public isms;
    mapping(address => AccountOwner) public accountOwners;

    uint256[47] private __GAP;

    IUniswapV2Router02 public uniswapV2Router;
    IV3SwapRouter public uniswapV3Router;
    address public uniswapV2RouterAddress;
    address public uniswapV3RouterAddress;
    address public usdcTokenAddress;
    address public nativeTokenAddress;

    address public feeTo;
    uint256[] public tierLimits;
    uint256[] public tierFees;
    mapping(address => uint8) public tokenDecimals;

    address mailbox_address;

    uint24 public poolFee; // to make path for multi hop swap on uniswap v3
    
    // ============ Events ============

    /**
     * @notice Emitted when a default ISM is set for a remote domain
     * @param domain The remote domain
     * @param ism The address of the remote ISM
     */
    event RemoteIsmEnrolled(uint32 indexed domain, bytes32 ism);

    /**
     * @notice Emitted when an interchain call is dispatched to a remote domain
     * @param destination The destination domain on which to make the call
     * @param owner The local owner of the remote ICA
     * @param router The address of the remote router
     * @param ism The address of the remote ISM
     */
    event RemoteCallDispatched(
        uint32 indexed destination,
        address indexed owner,
        bytes32 router,
        bytes32 ism
    );

    /**
     * @notice Emitted when an interchain account contract is deployed
     * @param origin The domain of the chain where the message was sent from
     * @param owner The address of the account that sent the message
     * @param ism The address of the local ISM
     * @param account The address of the proxy account that was created
     */
    event InterchainAccountCreated(
        uint32 indexed origin,
        bytes32 indexed owner,
        address ism,
        address account
    );

    event messageDataDecoded(bytes32 sender, bytes32 ism, bytes data);

    // ============ Constructor ============

    constructor(
        address _mailbox,
        address _customHook,
        address _interchainSecurityModule
    ) HRouter(_mailbox) {
        _MailboxClient_initialize(_customHook, _interchainSecurityModule);
        mailbox_address = _mailbox;
        tierLimits.push(100);
        tierFees.push(1000);
        tierLimits.push(500);
        tierFees.push(800);
        tierLimits.push(1000);
        tierFees.push(500);
        tierLimits.push(type(uint256).max);
        tierFees.push(200);
        poolFee = uint24(3000);
    }

    function calculateTierFee(uint256 amount) internal view returns (uint256) {
        uint8 decimals = 6;
        if (tokenDecimals[nativeTokenAddress] >= 0) {
            decimals = tokenDecimals[nativeTokenAddress];
        }
        for (uint256 i = 0; i < tierLimits.length; i++) {
            if (amount <= tierLimits[i] * 10 ** decimals) {
                return (amount * tierFees[i]) / 10000;
            }
        }
        return 0;
    }

     // ============ Functions ============

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * @param newOwner The address of the new owner.
     */
    function updateOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner is the zero address");
        _transferOwnership(newOwner);
    }

    // ============ External Functions ============
    /**
     * @notice Dispatches a single remote call to be made by an owner's
     * interchain account on the destination domain
     * @dev Uses the default router and ISM addresses for the destination
     * domain, reverting if none have been configured
     * @param _destination The remote domain of the chain to make calls on
     * @param _walletAddress The destination wallet address
     * @param _token The address of the token to send
     * @param _value The value to include in the call
     * @return The Hyperlane message ID
     */
    function callRemote(
        uint32 _destination,
        address _walletAddress,
        address _token,
        uint256 _value,
        bool _v3
    ) external payable returns (bytes32) {
        require(
            block.chainid != 24116 && block.chainid != 6278,
            "You cannot bridge from rails to other"
        );

        uint256 usdcAmount = 0;

        if (_token == nativeTokenAddress || _token == address(0)) {
            address[] memory path = new address[](2);
            path[0] = nativeTokenAddress;
            path[1] = usdcTokenAddress;

            uint256[] memory amounts = uniswapV2Router.swapExactETHForTokens{
                value: msg.value - 1
            }(0, path, address(this), block.timestamp);
            usdcAmount = amounts[1];
        } else if (_token == usdcTokenAddress) {
            IERC20 token = IERC20(_token);
            token.transferFrom(msg.sender, address(this), _value);
            usdcAmount = _value;
        } else {
            address uniswapRouterAddress = uniswapV2RouterAddress;
            if (_v3 == true) {
                uniswapRouterAddress = uniswapV3RouterAddress;
            }

            IERC20 token = IERC20(_token);
            token.transferFrom(msg.sender, address(this), _value);
            IERC20(_token).approve(uniswapRouterAddress, _value);

            if (_v3 == true) {
                bytes memory path =
                    abi.encodePacked(_token, poolFee, nativeTokenAddress, poolFee, usdcTokenAddress);
                    
                IV3SwapRouter.ExactInputParams memory params = IV3SwapRouter
                    .ExactInputParams({
                    path: path,
                    recipient: msg.sender,
                    amountIn: _value,
                    amountOutMinimum: 0
                });

                usdcAmount = uniswapV3Router.exactInput(params);
            } else {
                address[] memory path = new address[](3);
                path[0] = _token;
                path[1] = nativeTokenAddress;
                path[2] = usdcTokenAddress;

                uint256[] memory amounts = uniswapV2Router.swapExactTokensForTokens(
                    _value,
                    0,
                    path,
                    address(this),
                    block.timestamp
                );
                usdcAmount = amounts[2];
            }
        }

        IERC20 usdc = IERC20(usdcTokenAddress);

        uint256 fee = calculateTierFee(usdcAmount);

        usdc.transfer(feeTo, fee);

        uint256 transferAmount = usdcAmount - fee;

        if (block.chainid == 56) {
            transferAmount = transferAmount / (10 ** 12);
        }

        bytes32 _router = routers(_destination);
        bytes32 _ism = isms[_destination];
        bytes memory _body = InterchainAccountMessage.encode(
            msg.sender,
            _ism,
            _walletAddress,
            transferAmount,
            bytes("Hello World!")
        );
        return _dispatchMessage(_destination, _router, _ism, _body);
    }

    function handle(
        uint32 _origin,
        bytes32 _sender,
        bytes calldata _data
    ) external payable virtual override {
        require(msg.sender == mailbox_address, "Invalid caller");
        bytes32 _router = routers(_origin);
        require(_sender == _router, "Invalid sender");

        emit ReceivedMessage(_origin, _sender, msg.value, string(_data));
        (
            bytes32 _messageSender,
            bytes32 _messageIsm,
            CallLib.Call[] memory _calls
        ) = InterchainAccountMessage.decode(_data);

        CallLib.Call memory _messageData = _calls[0];
        emit messageDataDecoded(
            _messageSender,
            _messageIsm,
            bytes(_messageData.data)
        );
        lastSender = _sender;
        lastData = bytes(_messageData.data);

        if (block.chainid == 24116 || block.chainid == 6278) {
            address[] memory _path = new address[](2);
            _path[0] = usdcTokenAddress;
            _path[1] = nativeTokenAddress;

            uint256 _amount = uint256(_messageData.value);

            require(
                IERC20(usdcTokenAddress).balanceOf(address(this)) >
                    uint256(_messageData.value),
                "Bridge does not have enough usdc"
            );

            IERC20(usdcTokenAddress).approve(uniswapV2RouterAddress, _amount);

            uniswapV2Router.swapExactTokensForETH(
                _amount,
                0,
                _path,
                address(uint160(uint256(_messageData.to))),
                block.timestamp
            );
        } else {
            IERC20(usdcTokenAddress).transfer(
                address(uint160(uint256(_messageData.to))),
                uint256(_messageData.value)
            );
        }
    }

    /**
     * @dev Required for use of Router, compiler will not include this function in the bytecode
     */
    function _handle(uint32, bytes32, bytes calldata) internal pure override {
        assert(false);
    }

    function _dispatchMessage(
        uint32 _destination,
        bytes32 _router,
        bytes32 _ism,
        bytes memory _body
    ) private returns (bytes32) {
        require(_router != bytes32(0), "no router specified for destination");
        emit RemoteCallDispatched(_destination, msg.sender, _router, _ism);
        uint256 _gas = _quoteDispatch(_destination, "");
        if (block.chainid == 24116 || block.chainid == 6278) {
            return mailbox.dispatch{value: _gas}(_destination, _router, _body);
        } else {
            return mailbox.dispatch{value: _gas}(_destination, _router, _body);
        }
    }

    /**
     * @notice Returns the gas payment required to dispatch a message to the given domain's router.
     * @param _destination The domain of the destination router.
     * @return _gasPayment Payment computed by the registered hooks via MailboxClient.
     */
    function quoteGasPayment(
        uint32 _destination
    ) external view returns (uint256 _gasPayment) {
        return _quoteDispatch(_destination, "");
    }

    /**
     * @notice Returns the gas payment required to dispatch a given messageBody to the given domain's router with gas limit override.
     * @param _destination The domain of the destination router.
     * @param _messageBody The message body to be dispatched.
     * @param gasLimit The gas limit to override with.
     */
    function quoteGasPayment(
        uint32 _destination,
        bytes calldata _messageBody,
        uint256 gasLimit
    ) external view returns (uint256 _gasPayment) {
        bytes32 _router = _mustHaveRemoteRouter(_destination);
        return
            mailbox.quoteDispatch(
                _destination,
                _router,
                _messageBody,
                StandardHookMetadata.overrideGasLimit(gasLimit)
            );
    }

    function setTierLimit(uint256 tier, uint256 limit) external onlyOwner {
        require(tier < tierLimits.length, "Invalid tier");
        tierLimits[tier] = limit;
    }

    function setTierFee(uint256 tier, uint256 fee) external onlyOwner {
        require(tier < tierFees.length, "Invalid tier");
        tierFees[tier] = fee;
    }

    function setTokenDecimals(
        address _token,
        uint8 _decimals
    ) external onlyOwner {
        tokenDecimals[_token] = _decimals;
    }

    function setAddresses(
        address _usdcTokenAddress,
        address _nativeTokenAddress,
        address _uniswapV2RouterAddress,
        address _uniswapV3RouterAddress,
        address _feeTo
    ) external onlyOwner {
        usdcTokenAddress = _usdcTokenAddress;
        nativeTokenAddress = _nativeTokenAddress;
        uniswapV2RouterAddress = _uniswapV2RouterAddress;
        uniswapV3RouterAddress = _uniswapV3RouterAddress;
        feeTo = _feeTo;
        uniswapV2Router = IUniswapV2Router02(uniswapV2RouterAddress);
        uniswapV3Router = IV3SwapRouter(uniswapV3RouterAddress);
    }

    function setPoolFee(
        uint256 _fee
    ) external onlyOwner {
        poolFee = uint24(_fee);
    }

    function depositeToken(address _token, uint256 _amount) public {
        IERC20 token = IERC20(_token);
        require(
            token.balanceOf(msg.sender) >= _amount,
            "Enough amount in wallet"
        );
        token.transferFrom(msg.sender, address(this), _amount);
    }

    function withdrawToken(address _token, uint256 _amount) external onlyOwner {
        IERC20 token = IERC20(_token);
        require(
            token.balanceOf(address(this)) >= _amount,
            "Enough amount in contract"
        );
        token.transfer(msg.sender, _amount);
    }

    function balanceOf(address _token) public view returns (uint256) {
        IERC20 token = IERC20(_token);
        return token.balanceOf(address(this));
    }
}