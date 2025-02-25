// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

// @dev Import the 'MessagingFee' so it's exposed to OApp implementers
// solhint-disable-next-line no-unused-import
import { OAppSenderUpgradeable, MessagingFee } from "./lib_oapp-upgradeable_OAppSenderUpgradeable.sol";
// @dev Import the 'Origin' so it's exposed to OApp implementers
// solhint-disable-next-line no-unused-import
import { OAppReceiverUpgradeable, Origin } from "./lib_oapp-upgradeable_OAppReceiverUpgradeable.sol";
import { OAppCoreUpgradeable } from "./lib_oapp-upgradeable_OAppCoreUpgradeable.sol";

/**
 * @title OAppUpgradeable
 * @dev Abstract contract serving as the base for OAppUpgradeable implementation, combining OAppSenderUpgradeable and
 * OAppReceiverUpgradeable functionality.
 * @author Zodomo, https://github.com/Zodomo/LayerZero-v2
 */
abstract contract OAppUpgradeable is OAppSenderUpgradeable, OAppReceiverUpgradeable {
    /**
     * @dev Initializer for the upgradeable OApp with the provided endpoint and owner.
     * @param _endpoint The address of the LOCAL LayerZero endpoint.
     * @param _owner The address of the owner of the OApp.
     */
    function _initializeOApp(address _endpoint, address _owner) internal virtual onlyInitializing {
        _initializeOAppCore(_endpoint, _owner);
    }

    /**
     * @notice Retrieves the OApp version information.
     * @return senderVersion The version of the OAppSender.sol implementation.
     * @return receiverVersion The version of the OAppReceiver.sol implementation.
     */
    function oAppVersion()
        public
        pure
        virtual
        override(OAppSenderUpgradeable, OAppReceiverUpgradeable)
        returns (uint64 senderVersion, uint64 receiverVersion)
    {
        return (SENDER_VERSION, RECEIVER_VERSION);
    }
}