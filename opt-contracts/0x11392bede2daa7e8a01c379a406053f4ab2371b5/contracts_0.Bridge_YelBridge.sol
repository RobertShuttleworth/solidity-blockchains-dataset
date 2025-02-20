// SPDX-License-Identifier: MIT

pragma solidity ^0.8.22;

import { OApp, MessagingFee, Origin } from "./layerzerolabs_oapp-evm_contracts_oapp_OApp.sol";
import { OAppOptionsType3 } from "./layerzerolabs_oapp-evm_contracts_oapp_libs_OAppOptionsType3.sol";
import { Ownable } from "./openzeppelin_contracts_access_Ownable.sol";
import "./openzeppelin_contracts_security_Pausable.sol";

interface IERC20 {
    function mint(address to, uint amount) external;
    function burn(uint amount) external;
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external;
}

contract YelBridge is OApp, OAppOptionsType3, Pausable {
    IERC20 public BRIDGE_TOKEN;
    uint immutable public DEN = 10000;
    uint public FEE = 30; //0.3%
    bytes public options = hex"000301001101000000000000000000000000000186a0";

    event BridgeSend(address user, uint amount, uint toChain);
    event BridgeReceived(address user, uint amount, uint fromChain);

    /**
     * @dev Constructs a new PingPong contract instance.
     * @param _endpoint The LayerZero endpoint for this contract to interact with.
     * @param _owner The owner address that will be set as the owner of the contract.
     * @param _tokenForBridge The token address that will be bridged.
     */
    constructor(address _endpoint, address _owner, address _tokenForBridge) OApp(_endpoint, _owner) Ownable() {
        BRIDGE_TOKEN = IERC20(_tokenForBridge);
    }

    /**
     * @notice Returns the estimated messaging fee for a given message.
     * @param _dstEid Destination endpoint ID where the message will be sent.
     * @param _user TX sender.
     * @param _bridgeAmount Yel amount for bridge.
     * @return fee The estimated messaging fee.
     */
    function quote(
        uint32 _dstEid,
        uint256 _bridgeAmount,
        address _user
    ) public view returns (MessagingFee memory fee) {
        bytes memory payload = encodeMessage(_user, _bridgeAmount);
        fee = _quote(_dstEid, payload, options, false);
    }

    function send(uint32 _dstEid, uint bridgedAmount, address to) external payable whenNotPaused {
        require(bridgedAmount > 0, 'NO-0');

        BRIDGE_TOKEN.transferFrom(msg.sender, address(this), bridgedAmount);
        uint fee = (bridgedAmount * FEE) / DEN;
        uint amountAfterFee = bridgedAmount - fee;

        BRIDGE_TOKEN.transfer(owner(), fee);
        BRIDGE_TOKEN.burn(amountAfterFee);

        bytes memory _payload = encodeMessage(to, amountAfterFee); // Encodes message as bytes.
        _lzSend(
            _dstEid, // Destination chain's endpoint ID.
            _payload, // Encoded message payload being sent.
            options, // Message execution options (e.g., gas to use on destination).
            MessagingFee(msg.value, 0), // Fee struct containing native gas and ZRO token.
            payable(msg.sender) // The refund address in case the send call reverts.
        );

        emit BridgeSend(msg.sender, bridgedAmount, _dstEid);
    }

    /**
     * @notice Internal function to handle receiving messages from another chain.
     * @dev Decodes and processes the received message based on its type.
     * @param _origin Data about the origin of the received message.
     * @param message The received message content.
     */
    function _lzReceive(
        Origin calldata _origin,
        bytes32 /*guid*/,
        bytes calldata message,
        address,  // Executor address as specified by the OApp.
        bytes calldata  // Any extra data or options to trigger on receipt.
    ) internal override whenNotPaused {
        (address receiver, uint256 bridgedAmount) = decodeMessage(message);

        BRIDGE_TOKEN.mint(receiver, bridgedAmount);

        emit BridgeReceived(receiver, bridgedAmount, _origin.srcEid);
    }

    function decodeMessage(bytes calldata encodedMessage) public pure returns (address receiver, uint256 bridgedAmount) {
        (receiver, bridgedAmount) = abi.decode(encodedMessage, (address, uint256));

        return (receiver, bridgedAmount);
    }

    function encodeMessage(address receiver, uint256 bridgedAmount) public pure returns (bytes memory) {
        return abi.encode(receiver, bridgedAmount);
    }

    function setOptions(bytes memory newOptions) public onlyOwner {
        options = newOptions;
    }

    function setFee(uint fee) public onlyOwner {
        FEE = fee;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    receive() external payable {}
}