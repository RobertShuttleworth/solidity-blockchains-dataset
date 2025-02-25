// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./src_bridges_across_interfaces_acrossV3.sol";
import "./src_bridges_BridgeImplBase.sol";
import {SafeTransferLib} from "./lib_solmate_src_utils_SafeTransferLib.sol";
import {ERC20} from "./lib_solmate_src_tokens_ERC20.sol";
import {ACROSS} from "./src_static_RouteIdentifiers.sol";

/**
 * @title Across-Route Implementation
 * @notice Route implementation with functions to bridge ERC20 and Native via Across-Bridge
 * Called via SocketGateway if the routeId in the request maps to the routeId of AcrossImplementation
 * Contains function to handle bridging as post-step i.e linked to a preceeding step for swap
 * RequestData is different to just bride and bridging chained with swap
 * @author Socket dot tech.
 */
contract AcrossImplV3 is BridgeImplBase {
    /// @notice SafeTransferLib - library for safe and optimised operations on ERC20 tokens
    using SafeTransferLib for ERC20;

    bytes32 public immutable AcrossIdentifier = ACROSS;

    uint256 private immutable UINT256_MAX = type(uint256).max;

    /// @notice Function-selector for ERC20-token bridging on Across-Route
    /// @dev This function selector is to be used while buidling transaction-data to bridge ERC20 tokens
    bytes4 public immutable ACROSS_ERC20_EXTERNAL_BRIDGE_FUNCTION_SELECTOR =
        bytes4(
            keccak256(
                "bridgeERC20To(uint256,(address[],address[],uint256[],uint32[],uint256,bytes32))"
            )
        );

    /// @notice Function-selector for Native bridging on Across-Route
    /// @dev This function selector is to be used while buidling transaction-data to bridge Native tokens
    bytes4 public immutable ACROSS_NATIVE_EXTERNAL_BRIDGE_FUNCTION_SELECTOR =
        bytes4(
            keccak256(
                "bridgeNativeTo(uint256,(address[],address,uint256[],uint32[],uint256,bytes32))"
            )
        );

    bytes4 public immutable ACROSS_SWAP_BRIDGE_SELECTOR =
        bytes4(
            keccak256(
                "swapAndBridge(uint32,bytes,(address[],address,uint256[],uint32[],uint256,bytes32))"
            )
        );

    /// @notice spokePool Contract instance used to deposit ERC20 and Native on to Across-Bridge
    /// @dev contract instance is to be initialized in the constructor using the spokePoolAddress passed as constructor argument
    SpokePool public immutable spokePool;
    address public immutable spokePoolAddress;

    /// @notice address of WETH token to be initialised in constructor
    address public immutable WETH;

    /// @notice Struct to be used in decode step from input parameter - a specific case of bridging after swap.
    /// @dev the data being encoded in offchain or by caller should have values set in this sequence of properties in this struct
    struct AcrossBridgeDataNoToken {
        address[] senderReceiverAddresses; // 0 - sender, 1 - receiver
        address outputToken;
        uint256[] outputAmountToChainIdArray; // 0 -output amount, 1 - tochainId
        uint32[] quoteAndDeadlineTimeStamps; // 0 - quoteTimestamp, 1 - fillDeadline
        uint256 bridgeFee; // incase of swap involved in the tx, bridgeFee is deducted from swapped amount
        bytes32 metadata;
    }

    struct AcrossBridgeData {
        address[] senderReceiverAddresses; // 0 - sender, 1 - receiver
        address[] inputOutputTokens; // 0 - input token, 1 - output token
        uint256[] outputAmountToChainIdArray; // 0 -output amount, 1 - tochainId
        uint32[] quoteAndDeadlineTimeStamps; // 0 - quoteTimestamp, 1 - fillDeadline
        uint256 bridgeFee; // incase of swap involved in the tx, bridgeFee is deducted from swapped amount
        bytes32 metadata;
    }

    /// @notice socketGatewayAddress to be initialised via storage variable BridgeImplBase
    /// @dev ensure spokepool, weth-address are set properly for the chainId in which the contract is being deployed
    constructor(
        address _spokePool,
        address _wethAddress,
        address _socketGateway,
        address _socketDeployFactory
    ) BridgeImplBase(_socketGateway, _socketDeployFactory) {
        spokePool = SpokePool(_spokePool);
        spokePoolAddress = _spokePool;
        WETH = _wethAddress;
    }

    function acrossBridgeErc20(
        uint256 amount,
        address token,
        AcrossBridgeDataNoToken memory acrossBridgeData
    ) private {
        spokePool.depositV3(
            acrossBridgeData.senderReceiverAddresses[0],
            acrossBridgeData.senderReceiverAddresses[1],
            token,
            acrossBridgeData.outputToken,
            amount,
            amount - acrossBridgeData.bridgeFee, // incase of swap involved in the tx, bridgeFee is deducted from swapped amount
            acrossBridgeData.outputAmountToChainIdArray[1],
            address(0),
            acrossBridgeData.quoteAndDeadlineTimeStamps[0],
            acrossBridgeData.quoteAndDeadlineTimeStamps[1],
            0,
            ""
        );
    }

    function acrossBridgeNative(
        uint256 amount,
        AcrossBridgeDataNoToken memory acrossBridgeData
    ) private {
        /// @notice As per across docs https://docs.across.to/introduction/developer-notes#what-is-the-behavior-of-eth-weth-in-transfers
        /// If a bridge transfer is being sent to an EOA, the EOA will receive ETH (not WETH)
        /// If a bridge transfer is being sent to a contract, the contract will receive WETH (not ETH)
        spokePool.depositV3{value: amount}(
            acrossBridgeData.senderReceiverAddresses[0],
            acrossBridgeData.senderReceiverAddresses[1],
            WETH,
            acrossBridgeData.outputToken,
            amount,
            amount - acrossBridgeData.bridgeFee, // incase of swap involved in the tx, bridgeFee is deducted from swapped amount
            acrossBridgeData.outputAmountToChainIdArray[1],
            address(0),
            acrossBridgeData.quoteAndDeadlineTimeStamps[0],
            acrossBridgeData.quoteAndDeadlineTimeStamps[1],
            0,
            ""
        );
    }

    /**
     * @notice function to bridge tokens after swap.
     * @notice this is different from swapAndBridge, this function is called when the swap has already happened at a different place.
     * @notice This method is payable because the caller is doing token transfer and briding operation
     * @dev for usage, refer to controller implementations
     *      encodedData for bridge should follow the sequence of properties in AcrossBridgeData struct
     * @param amount amount of tokens being bridged. this can be ERC20 or native
     * @param bridgeData encoded data for AcrossBridge
     */
    function bridgeAfterSwap(
        uint256 amount,
        bytes calldata bridgeData
    ) external payable override {
        AcrossBridgeData memory acrossBridgeData = abi.decode(
            bridgeData,
            (AcrossBridgeData)
        );

        if (acrossBridgeData.inputOutputTokens[0] == NATIVE_TOKEN_ADDRESS) {
            /// @notice As per across docs https://docs.across.to/introduction/developer-notes#what-is-the-behavior-of-eth-weth-in-transfers
            /// If a bridge transfer is being sent to an EOA, the EOA will receive ETH (not WETH)
            /// If a bridge transfer is being sent to a contract, the contract will receive WETH (not ETH)
            spokePool.depositV3{value: amount}(
                acrossBridgeData.senderReceiverAddresses[0],
                acrossBridgeData.senderReceiverAddresses[1],
                WETH,
                acrossBridgeData.inputOutputTokens[1],
                amount,
                amount - acrossBridgeData.bridgeFee,
                acrossBridgeData.outputAmountToChainIdArray[1],
                address(0),
                acrossBridgeData.quoteAndDeadlineTimeStamps[0],
                acrossBridgeData.quoteAndDeadlineTimeStamps[1],
                0,
                ""
            );
        } else {
            if (
                amount >
                ERC20(acrossBridgeData.inputOutputTokens[0]).allowance(
                    address(this),
                    address(spokePoolAddress)
                )
            ) {
                ERC20(acrossBridgeData.inputOutputTokens[0]).safeApprove(
                    address(spokePoolAddress),
                    UINT256_MAX
                );
            }
            spokePool.depositV3(
                acrossBridgeData.senderReceiverAddresses[0],
                acrossBridgeData.senderReceiverAddresses[1],
                acrossBridgeData.inputOutputTokens[0],
                acrossBridgeData.inputOutputTokens[1],
                amount,
                amount - acrossBridgeData.bridgeFee,
                acrossBridgeData.outputAmountToChainIdArray[1],
                address(0),
                acrossBridgeData.quoteAndDeadlineTimeStamps[0],
                acrossBridgeData.quoteAndDeadlineTimeStamps[1],
                0,
                ""
            );
        }

        emit SocketBridge(
            amount,
            acrossBridgeData.inputOutputTokens[0],
            acrossBridgeData.outputAmountToChainIdArray[1],
            AcrossIdentifier,
            msg.sender,
            acrossBridgeData.senderReceiverAddresses[1],
            acrossBridgeData.metadata
        );
    }

    /**
     * @notice function to bridge tokens after swap.
     * @notice this is different from bridgeAfterSwap since this function holds the logic for swapping tokens too.
     * @notice This method is payable because the caller is doing token transfer and briding operation
     * @dev for usage, refer to controller implementations
     *      encodedData for bridge should follow the sequence of properties in AcrossBridgeData struct
     * @param swapId routeId for the swapImpl
     * @param swapData encoded data for swap
     * @param acrossBridgeData encoded data for AcrossBridge
     */
    function swapAndBridge(
        uint32 swapId,
        bytes calldata swapData,
        AcrossBridgeDataNoToken calldata acrossBridgeData
    ) external payable {
        (bool success, bytes memory result) = socketRoute
            .getRoute(swapId)
            .delegatecall(swapData);

        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }

        (uint256 bridgeAmount, address token) = abi.decode(
            result,
            (uint256, address)
        );
        if (token == NATIVE_TOKEN_ADDRESS) {
            acrossBridgeNative(bridgeAmount, acrossBridgeData);
        } else {
            if (
                bridgeAmount >
                ERC20(token).allowance(address(this), address(spokePoolAddress))
            ) {
                ERC20(token).safeApprove(
                    address(spokePoolAddress),
                    UINT256_MAX
                );
            }
            acrossBridgeErc20(bridgeAmount, token, acrossBridgeData);
        }

        emit SocketBridge(
            bridgeAmount,
            token,
            acrossBridgeData.outputAmountToChainIdArray[1],
            AcrossIdentifier,
            msg.sender,
            acrossBridgeData.senderReceiverAddresses[1],
            acrossBridgeData.metadata
        );
    }

    /**
     * @notice function to handle ERC20 bridging to receipent via Across-Bridge
     * @notice This method is payable because the caller is doing token transfer and briding operation
     */
    function bridgeERC20To(
        uint256 amount,
        AcrossBridgeData memory acrossBridgeData
    ) external payable {
        ERC20 tokenInstance = ERC20(acrossBridgeData.inputOutputTokens[0]);
        tokenInstance.safeTransferFrom(msg.sender, socketGateway, amount);

        if (
            amount >
            ERC20(acrossBridgeData.inputOutputTokens[0]).allowance(
                address(this),
                address(spokePoolAddress)
            )
        ) {
            ERC20(acrossBridgeData.inputOutputTokens[0]).safeApprove(
                address(spokePoolAddress),
                UINT256_MAX
            );
        }
        spokePool.depositV3(
            acrossBridgeData.senderReceiverAddresses[0],
            acrossBridgeData.senderReceiverAddresses[1],
            acrossBridgeData.inputOutputTokens[0],
            acrossBridgeData.inputOutputTokens[1],
            amount,
            acrossBridgeData.outputAmountToChainIdArray[0],
            acrossBridgeData.outputAmountToChainIdArray[1],
            address(0),
            acrossBridgeData.quoteAndDeadlineTimeStamps[0],
            acrossBridgeData.quoteAndDeadlineTimeStamps[1],
            0,
            ""
        );

        emit SocketBridge(
            amount,
            acrossBridgeData.inputOutputTokens[0],
            acrossBridgeData.outputAmountToChainIdArray[1],
            AcrossIdentifier,
            msg.sender,
            acrossBridgeData.senderReceiverAddresses[1],
            acrossBridgeData.metadata
        );
    }

    /**
     * @notice function to handle Native bridging to receipent via Across-Bridge
     * @notice This method is payable because the caller is doing token transfer and briding operation
     */
    function bridgeNativeTo(
        uint256 amount,
        AcrossBridgeDataNoToken memory acrossBridgeData
    ) external payable {
        /// @notice As per across docs https://docs.across.to/introduction/developer-notes#what-is-the-behavior-of-eth-weth-in-transfers
        /// If a bridge transfer is being sent to an EOA, the EOA will receive ETH (not WETH)
        /// If a bridge transfer is being sent to a contract, the contract will receive WETH (not ETH)
        spokePool.depositV3{value: amount}(
            acrossBridgeData.senderReceiverAddresses[0],
            acrossBridgeData.senderReceiverAddresses[1],
            WETH,
            acrossBridgeData.outputToken,
            amount,
            acrossBridgeData.outputAmountToChainIdArray[0],
            acrossBridgeData.outputAmountToChainIdArray[1],
            address(0),
            acrossBridgeData.quoteAndDeadlineTimeStamps[0],
            acrossBridgeData.quoteAndDeadlineTimeStamps[1],
            0,
            ""
        );

        emit SocketBridge(
            amount,
            NATIVE_TOKEN_ADDRESS,
            acrossBridgeData.outputAmountToChainIdArray[1],
            AcrossIdentifier,
            msg.sender,
            acrossBridgeData.senderReceiverAddresses[1],
            acrossBridgeData.metadata
        );
    }
}