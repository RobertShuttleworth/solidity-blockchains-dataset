// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import { ISpectra } from "./src_interfaces_ISpectra.sol";
import { IVotingEscrowLegacy } from "./src_interfaces_IVotingEscrowLegacy.sol";

import { AccessManagedUpgradeable } from "./node_modules_openzeppelin_contracts-upgradeable_access_manager_AccessManagedUpgradeable.sol";

// LayerZero
import { OAppUpgradeable } from "./lib_oapp-upgradeable_OAppUpgradeable.sol";
import { MessagingFee, Origin } from "./node_modules_layerzerolabs_oapp-evm_contracts_oapp_OApp.sol";
import { MessagingReceipt } from "./node_modules_layerzerolabs_oapp-evm_contracts_oapp_OAppSender.sol";

contract SpectraBridge is OAppUpgradeable, AccessManagedUpgradeable {
    ISpectra public spectra;

    /* ERRORS
     *****************************************************************************************************************/
    error ZeroAmount();

    /* EVENTS
     *****************************************************************************************************************/
    event SpectraBridgeInitiated(
        uint32 indexed destEid,
        address indexed user,
        address indexed receiver,
        uint256 amount
    );
    event SpectraBridgeCompleted(uint32 indexed srcEid, address indexed user, address indexed receiver, uint256 amount);

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _initialAuthority,
        address _endpoint,
        address _delegate,
        address _spectra
    ) public initializer {
        __AccessManaged_init(_initialAuthority);
        _initializeOAppCore(_endpoint, _delegate);
        spectra = ISpectra(_spectra);
    }

    /**
     * @notice Burns SPECTRA tokens and sends a message to the destination chain to mint SPECTRA.
     * @param amount The amount of SPECTRA tokens to burn.
     * @param options The options for the message.
     * @return receipt The receipt for the sent message.
     *      - guid: The unique identifier for the sent message.
     *      - nonce: The nonce of the sent message.
     *      - fee: The LayerZero fee incurred for the message.
     */
    function bridge(
        uint32 destEid,
        address receiver,
        uint256 amount,
        bytes calldata options
    ) external payable returns (MessagingReceipt memory receipt) {
        if (amount == 0) {
            revert ZeroAmount();
        }
        spectra.burnFrom(msg.sender, amount);
        // Encode the message payload
        bytes memory payload = abi.encode(msg.sender, receiver, amount);
        // Send message
        receipt = _lzSend(destEid, payload, options, MessagingFee(msg.value, 0), payable(msg.sender));
        emit SpectraBridgeInitiated(destEid, msg.sender, receiver, amount);
    }

    /**
     * @dev Internal function to implement lzReceive logic without needing to copy the basic parameter validation.
     */
    function _lzReceive(
        Origin calldata origin,
        bytes32,
        bytes calldata _message,
        address,
        bytes calldata
    ) internal override {
        (address user, address receiver, uint256 amount) = abi.decode(_message, (address, address, uint256));
        spectra.mint(receiver, amount);
        emit SpectraBridgeCompleted(origin.srcEid, user, receiver, amount);
    }

    /* Quotes the fee for bridging SPECTRA */
    function quote(uint32 destEid, bytes calldata options) external view returns (MessagingFee memory) {
        // Pass an empty payload (user, receiver, amount)
        return _quote(destEid, abi.encode(address(0), address(0), 0), options, false);
    }
}