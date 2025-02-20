// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IWETH} from "./wormhole_interfaces_IWETH.sol";

import {OwnableUpgradeable} from "./openzeppelin_contracts-upgradeable_access_OwnableUpgradeable.sol";
import {PausableUpgradeable} from "./openzeppelin_contracts-upgradeable_utils_PausableUpgradeable.sol";
import {Initializable} from "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";
import {IERC20} from "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import {SafeERC20} from "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";
import {ISpoke} from "./src_interfaces_ISpoke.sol";
import {IHub} from "./src_interfaces_IHub.sol";
import {IWormholeTunnel} from "./src_interfaces_IWormholeTunnel.sol";

import {HubSpokeStructs} from "./src_contracts_HubSpokeStructs.sol";
import {HubSpokeEvents} from "./src_contracts_HubSpokeEvents.sol";

import {TokenBridgeUtilities} from "./src_contracts_wormhole_TokenBridgeUtilities.sol";
import {TunnelMessageBuilder} from "./src_contracts_wormhole_TunnelMessageBuilder.sol";
import {SpokeOptimisticFinalityLogic} from "./src_libraries_logic_optimisticFinality_SpokeOptimisticFinalityLogic.sol";
import {CommonAccountingLogic} from "./src_libraries_logic_accounting_CommonAccountingLogic.sol";
import {SpokeAccountingLogic} from "./src_libraries_logic_accounting_SpokeAccountingLogic.sol";

import "./wormhole_Utils.sol";

/**
 * @title Spoke
 * @notice The Spoke contract is the point of entry for cross-chain actions; users initiate an action by calling any of
 * the `public payable` functions (ex: `#depositCollateral`, `#withdrawCollateral`) with their desired asset and amount,
 * and using Wormhole we send the payload/tokens to the Hub on the target chain; if the action concludes with sending
 * tokens back to the user, we receive the final payload/tokens from the Hub before sending tokens to the user. This
 * contract also implements wormhole's CCTP contracts to send/receive USDC.
 */

contract Spoke is ISpoke, Initializable, OwnableUpgradeable, PausableUpgradeable, HubSpokeEvents {
    using SafeERC20 for IERC20;
    using SpokeOptimisticFinalityLogic for HubSpokeStructs.SpokeOptimisticFinalityState;

    HubSpokeStructs.SpokeCommunicationState commState;
    HubSpokeStructs.SpokeOptimisticFinalityState ofState;
    IWETH public weth;

    modifier onlyWormholeTunnel() {
        if (msg.sender != address(commState.wormholeTunnel)) {
            revert OnlyWormholeTunnel();
        }
        _;
    }

    modifier onlyHubSender(IWormholeTunnel.MessageSource calldata source) {
        if (source.sender != commState.hubContractAddress || source.chainId != commState.hubChainId) {
            revert OnlyHubSender();
        }
        _;
    }

    /**
     * @notice Spoke initializer - Initializes a new spoke with given parameters
     * @param _hubChainId: Chain ID of the Hub
     * @param _hubContractAddress: Contract address of the Hub contract (on the Hub chain)
     * @param _tunnel: The Wormhole tunnel contract
     */
    function initialize(
        uint16 _hubChainId,
        address _hubContractAddress,
        IWormholeTunnel _tunnel,
        IWETH _weth
    ) public initializer {
        OwnableUpgradeable.__Ownable_init(msg.sender);
        PausableUpgradeable.__Pausable_init();
        commState.hubChainId = _hubChainId;
        commState.hubContractAddress = toWormholeFormat(_hubContractAddress);
        commState.wormholeTunnel = _tunnel;
        commState.defaultGasLimitRoundtrip = 5_000_000;

        ofState.avgTransactionsPerTopUp = 10;

        weth = _weth;
    }

    /**
     * @notice Allows the contract deployer to set the default gas limit used in wormhole relay quotes
     *
     * @param value: the new value for `defaultGasLimitRoundtrip`
     */
    function setDefaultGasLimitRoundtrip(uint256 value) external onlyOwner {
        commState.defaultGasLimitRoundtrip = value;
    }

    function getCommState() public view returns (HubSpokeStructs.SpokeCommunicationState memory) {
        return commState;
    }

    function setLimits(address _token, uint256 _creditLimit, uint256 _custodyLimit, uint256 _transactionLimit) external onlyOwner {
        ofState.setLimits(_token, _creditLimit, _custodyLimit, _transactionLimit);
    }

    function getSpokeBalances(address _token) external view returns (HubSpokeStructs.SpokeBalances memory) {
        return ofState.tokenBalances[toWormholeFormat(_token)];
    }

    function getCredit(address _user, uint256 _nonce) external view returns (HubSpokeStructs.Credit memory) {
        return ofState.storedCredits[_user][_nonce];
    }

    function getInstantMessageFee(HubSpokeStructs.ActionDirection _direction) external view returns (uint256) {
        return _direction == HubSpokeStructs.ActionDirection.Inbound ? ofState.inboundTokenInstantMessageFee : ofState.outboundTokenInstantMessageFee;
    }

    function getLastUserActionNonce(address _user) external view returns (uint256) {
        return ofState.lastInstantActionNonces[_user];
    }

    // getter for backward compatibility
    function defaultGasLimitRoundtrip() external view returns (uint256) {
        return commState.defaultGasLimitRoundtrip;
    }

    function setInstantMessageFees(uint256 _inboundTokenInstantMessageFee, uint256 _outboundTokenInstantMessageFee) external onlyOwner {
        ofState.setInstantMessageFees(_inboundTokenInstantMessageFee, _outboundTokenInstantMessageFee);
    }

    function setHub(uint16 _hubChainId, address _hubContractAddress) external onlyOwner {
        commState.hubChainId = _hubChainId;
        commState.hubContractAddress = toWormholeFormat(_hubContractAddress);
    }

    function _checkAndConvertNativeOutboundAsset(HubSpokeStructs.Action action, IERC20 asset) internal view returns (IERC20) {
        if (action == HubSpokeStructs.Action.BorrowNative || action == HubSpokeStructs.Action.WithdrawNative) {
            if (address(asset) != address(0)) {
                revert UnusedParameterMustBeZero();
            }
            asset = IERC20(address(weth));
        }
        return asset;
    }

    function userActions(HubSpokeStructs.Action action, IERC20 asset, uint256 amount, uint256 costForReturnDelivery) external payable {
        asset = _checkAndConvertNativeOutboundAsset(action, asset);
        uint256 totalCost = getDeliveryCostRoundtrip(costForReturnDelivery);
        if (msg.value < totalCost) {
            revert InsufficientMsgValue();
        }
        uint256 valueToSend = msg.value;
        address assetAddress = address(asset);
        // this remaps the action, asset and amount in case of native transfers
        (action, assetAddress, amount, valueToSend) = CommonAccountingLogic.handleInboundTokensAndAdjustAction(action, assetAddress, amount, weth, totalCost);

        _doAction(action, IERC20(assetAddress), amount, costForReturnDelivery, valueToSend);
    }

    function instantActions(
        HubSpokeStructs.Action action,
        IERC20 asset,
        uint256 amount,
        uint256[] calldata costForReturnDelivery
    )  external payable {
        asset = _checkAndConvertNativeOutboundAsset(action, asset);
        SpokeOptimisticFinalityLogic.handleInstantAction(ofState, commState, weth, action, address(asset), amount, costForReturnDelivery);
    }

    /**
     * @notice Get the quote for the wormhole delivery cost, accounting for a forward() call on the Hub (in case of potential
     * reverts or to receive tokens on borrow/withdraw)
     *
     * @param costForReturnDelivery: the result of Hub#getCostForReturnDelivery()
     * @return cost for the forward() call on the Hub
     */
    function getDeliveryCostRoundtrip(uint256 costForReturnDelivery)
        public
        view
        returns (uint256)
    {
        return commState.wormholeTunnel.getMessageCost(
            commState.hubChainId,
            commState.defaultGasLimitRoundtrip,
            costForReturnDelivery,
            true // there is always a token transfer. either inbound for deposit/repay or outbound for withdraw/borrow
        );
    }

    function getInstantActionDeliveryCosts(HubSpokeStructs.Action action, uint256[] calldata returnCosts) public view returns (uint256 total, uint256[] memory costs) {
        return SpokeOptimisticFinalityLogic.getInstantActionDeliveryCosts(ofState, commState, action, returnCosts);
    }

    function getReserveAmount(address asset) public view returns (uint256) {
        return SpokeAccountingLogic.getReserveAmount(ofState, asset);
    }

    function withdrawReserves(address asset, uint256 amount, address recipient) external onlyOwner {
        SpokeAccountingLogic.withdrawReserves(ofState, asset, amount, recipient);
    }

    /**
     * @dev Initiates an action (deposit, borrow, withdraw, or repay) on the spoke by sending
     * a Wormhole message (potentially a TokenBridge message with tokens) to the Hub
     * @param action - the action to be performed. It can be Deposit, Borrow, Withdraw, Repay, DepositNative, RepayNative.
     * @param asset - the address of the relevant asset. For native tokens like ETH, AVAX, this will be the zero address.
     * @param assetAmount - the amount of the asset to be involved in the action.
     * @param costForReturnDelivery - the cost to forward tokens back from the Hub
     */
    function _doAction(
        HubSpokeStructs.Action action,
        IERC20 asset,
        uint256 assetAmount,
        uint256 costForReturnDelivery,
        uint256 valueToSend
    ) internal {
        if (assetAmount == 0 || !commState.wormholeTunnel.isValidAmount(IERC20(asset), assetAmount)) {
            revert InvalidAmount();
        }

        if (
            (action == HubSpokeStructs.Action.Withdraw || action == HubSpokeStructs.Action.Borrow) &&
            costForReturnDelivery == 0
        ) {
            revert InvalidDeliveryCost();
        }

        IWormholeTunnel.TunnelMessage memory message;

        message.source.refundRecipient = toWormholeFormat(msg.sender);
        message.source.sender = toWormholeFormat(address(this));

        message.target.chainId = commState.hubChainId;
        message.target.recipient = commState.hubContractAddress;
        message.target.selector = IHub.userActionMessage.selector;
        message.target.payload = abi.encode(HubSpokeStructs.UserActionPayload({
            user: toWormholeFormat(msg.sender),
            action: action,
            asset: toWormholeFormat(address(asset)),
            amount: assetAmount
        }));

        if (costForReturnDelivery > 0) {
            // if sending ETH for return delivery, add it to the message
            message.receiverValue = costForReturnDelivery;
        }

        uint256 cost;
        if (_isTokenSend(action)) {
            message.token = toWormholeFormat(address(asset));
            message.amount = assetAmount;

            cost = getDeliveryCostRoundtrip(0);
            asset.forceApprove(address(commState.wormholeTunnel), assetAmount);
        } else {
            cost = getDeliveryCostRoundtrip(costForReturnDelivery);
            message.finality = IWormholeTunnel.MessageFinality.INSTANT;
        }

        commState.wormholeTunnel.sendEvmMessage{value: valueToSend}(
            message,
            commState.defaultGasLimitRoundtrip
        );
    }

    function _isTokenSend(HubSpokeStructs.Action action) internal pure returns (bool) {
        return action == HubSpokeStructs.Action.Deposit || action == HubSpokeStructs.Action.Repay;
    }

    function unwrapWethToTarget(
        IWormholeTunnel.MessageSource calldata,
        IERC20 token,
        uint256 amount,
        bytes calldata payload
    ) external payable onlyWormholeTunnel {
        if (address(token) != address(weth)) {
            revert InvalidWethForUnwrap();
        }
        // the sender is always the tunnel here
        token.safeTransferFrom(msg.sender, address(this), amount);

        address target = fromWormholeFormat(abi.decode(payload, (bytes32)));
        // unwrap and transfer to recipient
        weth.withdraw(amount);
        (bool success,) = payable(target).call{value: msg.value + amount}("");
        if (!success) {
            revert TransferFailed();
        }
    }

    function releaseFunds(
        IWormholeTunnel.MessageSource calldata source,
        IERC20,
        uint256,
        bytes calldata payload
    ) external payable onlyWormholeTunnel onlyHubSender(source) {
        SpokeOptimisticFinalityLogic.handleReleaseFunds(ofState, weth, payload);
    }

    function topUp(
        IWormholeTunnel.MessageSource calldata source,
        IERC20 token,
        uint256 amount,
        bytes calldata
    ) external payable onlyWormholeTunnel onlyHubSender(source) {
        SpokeOptimisticFinalityLogic.handleTopUp(ofState, commState, source, token, amount);
    }

    function confirmCredit(
        IWormholeTunnel.MessageSource calldata source,
        IERC20,
        uint256,
        bytes calldata payload
    ) external payable onlyWormholeTunnel onlyHubSender(source) {
        SpokeOptimisticFinalityLogic.handleConfirmCredit(ofState, payload);
    }

    function finalizeCredit(
        IWormholeTunnel.MessageSource calldata source,
        IERC20,
        uint256,
        bytes calldata payload
    ) external payable onlyWormholeTunnel onlyHubSender(source) {
        SpokeOptimisticFinalityLogic.handleFinalizeCredit(ofState, payload);
    }

    function fixLostCredit(IERC20 token, uint256 amount, bool fromReserves) external payable onlyOwner {
        SpokeOptimisticFinalityLogic.handleFixLostCredit(ofState, commState, token, amount, fromReserves);
    }

    function refundCredit(address _user, uint256 _nonce) external onlyOwner {
        SpokeOptimisticFinalityLogic.handleRefundCredit(ofState, _user, _nonce);
    }

    // last resort setter in case some unpredicted reverts happen and Spoke balances need to be corrected
    function overrideBalances(address token, uint256 creditGiven, uint256 unlocksPending, uint256 deposits) external onlyOwner {
        HubSpokeStructs.SpokeBalances storage balance = ofState.tokenBalances[toWormholeFormat(token)];
        balance.creditGiven = creditGiven;
        balance.unlocksPending = unlocksPending;
        balance.deposits = deposits;
    }

    /**
     * @notice Pauses the contract
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpauses the contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice fallback function to receive unwrapped native asset
     */
    fallback() external payable {}

    receive() external payable {}
}