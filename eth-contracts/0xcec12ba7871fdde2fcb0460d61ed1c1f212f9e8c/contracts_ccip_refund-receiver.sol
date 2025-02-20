// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;
import "./openzeppelin_contracts_access_Ownable.sol";
import "./chainlink_contracts-ccip_src_v0.8_ccip_interfaces_IRouterClient.sol";
import "./openzeppelin_contracts_proxy_Clones.sol";
import "./chainlink_contracts-ccip_src_v0.8_ccip_libraries_Client.sol";
import "./chainlink_contracts-ccip_src_v0.8_ccip_applications_CCIPReceiver.sol";
import "./contracts_lib_IIronballLibrary.sol";
import "./hardhat_console.sol";

interface IIronballNFT {
    function refundFromSideChain(uint256[] memory tokenIds, address tokenOwner) external returns(bool);
    function symbol() external view returns (string memory);
    function batchUpgradeFromSideChain(uint256[] calldata tokenIds, address tokenOwner)  external;
}

contract RefundReceiver is CCIPReceiver,Ownable {

    mapping (address => bool) allowedSenders;

    event MessageReceived(
        bytes32 indexed messageId, // The unique ID of the message.
        uint64 indexed sourceChainSelector, // The chain selector of the source chain.
        address sender, // The address of the sender from the source chain.
        ActionData text // The text that was received.
    );

    constructor(address _router) CCIPReceiver(_router) {
    }

    function setAllowSenders(address[] memory senders, bool allowed) public onlyOwner() {
        for(uint256 i = 0; i < senders.length; i++){
            allowedSenders[senders[i]] = allowed;
        }
    }

    /// handle a received message
    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    ) internal override {
        require( allowedSenders[abi.decode(any2EvmMessage.sender, (address))], "Sender not allowed");
        ActionData memory data = abi.decode(any2EvmMessage.data, (ActionData)); // abi-decoding of the sent text
        if(data.action == Action.UPGRADE){
            IIronballNFT(data.nftAddress).batchUpgradeFromSideChain(data.tokenIds, data.by);
        } else if(data.action == Action.REFUND){
            IIronballNFT(data.nftAddress).refundFromSideChain(data.tokenIds, data.by);
        }
    }
    
}