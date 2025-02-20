// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import {IERC20} from "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import {SafeERC20} from "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";
import {Ownable} from "./openzeppelin_contracts_access_Ownable.sol";
import {OApp, Origin, MessagingFee} from "./layerzerolabs_lz-evm-oapp-v2_contracts_oapp_OApp.sol";
import {OAppCore} from "./layerzerolabs_lz-evm-oapp-v2_contracts_oapp_OAppCore.sol";
import {IOAppComposer} from "./layerzerolabs_lz-evm-oapp-v2_contracts_oapp_interfaces_IOAppComposer.sol";
import {OFTComposeMsgCodec} from "./layerzerolabs_lz-evm-oapp-v2_contracts_oft_libs_OFTComposeMsgCodec.sol";
import {SendParam} from "./layerzerolabs_lz-evm-oapp-v2_contracts_oft_interfaces_IOFT.sol";

import {IEpochController} from './src_interfaces_IEpochController.sol';
import {currentEpoch} from "./src_libraries_EpochMath.sol";

import {Abra} from "./src_token_Abra.sol";
import {AbraStaking} from "./src_token_AbraStaking.sol";
import {OFTMediator} from "./src_token_OFTMediator.sol";
import {VoterV4} from "./src_VoterV4.sol";

struct LockupMessage {
    uint128 amount;
    uint32 end;
    address staker;
}

error AbraStakingRelay_InvalidOapp();
error AbraStakingRelay_InvalidEndpoint();
error AbraStakingRelay_AmountsDontMatch(uint256 amountSent, uint256 lockupAmount);
error AbraStakingRelay_Voting(uint256 lockupId);
error AbraStakingRelay_EpochNotClosed();

/// The point of this contract is not to be a real oApp but to be a receiver side of ABRA through OFT Compose,
/// and to allow *sending* staking positions only to *trusted* peers. Therefore the peers of this faux oApp are configured
/// as usual but this oApp does not receive nor send messages.
contract AbraStakingRelay is OAppCore, IOAppComposer {
    
    IERC20 public abra;
    VoterV4 public voter;
    AbraStaking public staking;
    OFTMediator public mediator;

    constructor(address _mediator, address _owner)
        OAppCore(address(OFTMediator(_mediator).endpoint()), _owner)
        Ownable(_owner)
    {
        mediator = OFTMediator(_mediator);
    }

    function setUp(address _voter) external onlyOwner {
        voter = VoterV4(_voter);
        staking = AbraStaking(voter.ve());
        abra = staking.abra();

        // give unlimited approve to the staking contract
        abra.approve(address(staking), type(uint256).max);
    }

    function oAppVersion() public pure virtual override returns (uint64 senderVersion, uint64 receiverVersion) {
        return (0, 0);
    }

    /// @notice Handles incoming composed messages from LayerZero.
    /// @dev Decodes the message payload to perform a token swap.
    ///      This method expects the encoded compose message to contain the swap amount and recipient address.
    /// @param _oApp The address of the originating OApp.
    /// @param /*_guid*/ The globally unique identifier of the message (unused in this mock).
    /// @param _message The encoded message content in the format of the OFTComposeMsgCodec.
    /// @param /*Executor*/ Executor address (unused in this mock).
    /// @param /*Executor Data*/ Additional data for checking for a specific executor (unused in this mock).
    function lzCompose(
        address _oApp,
        bytes32, /*_guid*/
        bytes calldata _message,
        address, /*Executor*/
        bytes calldata /*Executor Data*/
    ) external payable override {
        if (_oApp != address(mediator))      revert AbraStakingRelay_InvalidOapp();
        if (msg.sender != address(endpoint)) revert AbraStakingRelay_InvalidEndpoint();

        // Extract the composed message from the delivered message using the MsgCodec
        LockupMessage memory lockupMessage = abi.decode(OFTComposeMsgCodec.composeMsg(_message), (LockupMessage));
        uint256 _amountReceivedLD = OFTComposeMsgCodec.amountLD(_message);
        // we must check that we received enough funds along with the composed message
        if (_amountReceivedLD < lockupMessage.amount) {
            revert AbraStakingRelay_AmountsDontMatch(_amountReceivedLD, lockupMessage.amount);
        }
        IEpochController epochController = IEpochController(voter.epochController());
        if (epochController.openEpoch() < currentEpoch()) {
            revert AbraStakingRelay_EpochNotClosed();
        }
        staking.attach(lockupMessage.staker, lockupMessage.amount, lockupMessage.end); 
    }

    function _getSendParam(address staker, AbraStaking.Lockup memory lockup, uint32 eid, bytes calldata options)
        internal
        view
        returns (SendParam memory)
    {
        LockupMessage memory lockupMessage = LockupMessage({amount: lockup.amount, end: lockup.end, staker: staker});

        return SendParam({
            dstEid: eid, // Destination endpoint ID.
            to: peers[eid], // Recipient address.
            amountLD: lockup.amount, // Amount to send in local decimals.
            minAmountLD: lockup.amount, // Minimum amount to send in local decimals.
            extraOptions: options, // Additional options supplied by the caller to be used in the LayerZero message.
            composeMsg: abi.encode(lockupMessage), // The composed message for the send() operation.
            oftCmd: new bytes(0) // The OFT command to be executed, unused in default OFT implementations.
        });
    }

    function forward(uint256 lockupIndex, uint32 eid, bytes calldata options) external payable {
        _forward(lockupIndex, msg.sender, eid, options);
    }

    function quoteForward(uint256 lockupIndex, uint32 eid, bytes calldata options)
        external
        view
        returns (MessagingFee memory msgFee)
    {
        return _quoteForward(lockupIndex, msg.sender, eid, options);
    }

    function forward(uint256 lockupIndex, address receiver, uint32 eid, bytes calldata options) external payable {
        _forward(lockupIndex, receiver, eid, options);
    }

    function quoteForward(uint256 lockupIndex, address receiver, uint32 eid, bytes calldata options)
        external
        view
        returns (MessagingFee memory msgFee)
    {
        return _quoteForward(lockupIndex, receiver, eid, options);
    }

    function _forward(uint256 lockupIndex, address receiver, uint32 eid, bytes calldata options) internal {
        IEpochController epochController = IEpochController(voter.epochController());
        if (epochController.openEpoch() < currentEpoch()) {
            revert AbraStakingRelay_EpochNotClosed();
        }
        AbraStaking.Lockup memory lockup = staking.detach(msg.sender, lockupIndex);
        // user must first reset all their votes on the current chain
        if (voter.voted(lockup.id)) {
            revert AbraStakingRelay_Voting(lockup.id);
        }
        lockup.amount = uint128(mediator.removeDust(lockup.amount));
        SendParam memory sendParam = _getSendParam(receiver, lockup, eid, options);
        MessagingFee memory fee = MessagingFee({nativeFee: msg.value, lzTokenFee: 0});
        IERC20(mediator.token()).approve(address(mediator), sendParam.amountLD);
        mediator.send{value: msg.value}(sendParam, fee, receiver);
    }

    function _quoteForward(uint256 lockupIndex, address receiver, uint32 eid, bytes calldata options)
        internal
        view
        returns (MessagingFee memory msgFee)
    {
        AbraStaking.Lockup memory lockup = staking.lockups(msg.sender, lockupIndex);
        // user must first reset all their votes on the current chain
        if (voter.voted(lockup.id)) {
            revert AbraStakingRelay_Voting(lockup.id);
        }
        lockup.amount = uint128(mediator.removeDust(lockup.amount));
        SendParam memory sendParam = _getSendParam(receiver, lockup, eid, options);
        return mediator.quoteSend(sendParam, false);
    }

    function setMediator(OFTMediator _mediator) external onlyOwner {
        mediator = _mediator;
    }

    function setVoter(VoterV4 _voter) external onlyOwner {
        voter = _voter;
    }
}