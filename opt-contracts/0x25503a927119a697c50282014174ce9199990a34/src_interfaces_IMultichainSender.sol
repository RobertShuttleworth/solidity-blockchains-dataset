// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8;

interface IMultichainSender {
    /// @notice Returns the ETH value necessary to send a message to the given destinations.
    /// @param destinations The LZ chain IDs of the destinations.
    /// @param data The message data that will be used in the call.
    /// @param options LZ options for each destination.
    function quoteCall(uint32[] memory destinations, bytes memory data, bytes[] memory options)
        external
        view
        returns (uint256[] memory fees, uint256 totalFee);

    /// @notice Returns the ETH value necessary to create a contract on the given destinations.
    /// @param destinations The LZ chain IDs of the destinations.
    /// @param creationCode The contract creation code.
    /// @param initData The initialization data for the contract.
    /// @param options LZ options for each destination.
    function quoteCreate(
        uint32[] memory destinations,
        bytes memory creationCode,
        bytes memory initData,
        bytes[] memory options
    ) external view returns (uint256[] memory fees, uint256 totalFee);

    /// @notice Returns the ETH value necessary to create a contract on the given destinations using CREATE2.
    /// @param destinations The LZ chain IDs of the destinations.
    /// @param saltString The salt string for CREATE2.
    /// @param creationCode The contract creation code.
    /// @param initData The initialization data for the contract.
    /// @param options LZ options for each destination.
    /// @dev The salt string is hashed together with msg.sender to generate the create2 salt value.
    function quoteCreate2(
        uint32[] memory destinations,
        string memory saltString,
        bytes memory creationCode,
        bytes memory initData,
        bytes[] memory options
    ) external view returns (uint256[] memory fees, uint256 totalFee);

    /// @notice Returns the ETH value necessary to create proxy & implementation contracts on the given destinations using CREATE2.
    /// @param destinations The LZ chain IDs of the destinations.
    /// @param saltString The salt string for CREATE2.
    /// @param creationCode The contract creation code.
    /// @param initData The initialization data for the contract.
    /// @param options LZ options for each destination.
    /// @dev The salt string is hashed together with msg.sender to generate the create2 salt value.
    function quoteCreateUUPSProxy(
        uint32[] memory destinations,
        string memory saltString,
        bytes memory creationCode,
        bytes memory initData,
        bytes[] memory options
    ) external view returns (uint256[] memory fees, uint256 totalFee);

    /// @notice Sends a message to msg.sender on the other chain(s)
    /// @param destinations The LZ chain IDs of the destinations.
    /// @param data The message data that will be used in the call.
    /// @param options LZ options for each destination.
    /// @param fee The fee to be paid for each destination.
    /// @param refundAddress The address to refund the excess value sent.
    /// @param callLocally If true, the message will be executed locally as well.
    function transmitCallMessage(
        uint32[] memory destinations,
        bytes memory data,
        bytes[] calldata options,
        uint256[] memory fee,
        address payable refundAddress,
        bool callLocally
    ) external payable;

    /// @notice Sends a message to other chain(s) create a contract.
    /// @param destinations The LZ chain IDs of the destinations.
    /// @param creationCode The contract creation code.
    /// @param initData The initialization data for the contract.
    /// @param options LZ options for each destination.
    /// @param fee The fee to be paid for each destination.
    /// @param refundAddress The address to refund the excess value sent.
    /// @param callLocally If true, the contract will be created locally as well.
    function transmitCreateMessage(
        uint32[] memory destinations,
        bytes memory creationCode,
        bytes memory initData,
        bytes[] calldata options,
        uint256[] memory fee,
        address payable refundAddress,
        bool callLocally
    ) external payable;

    /// @notice Sends a message to other chain(s) create a contract using CREATE2.
    /// @param destinations The LZ chain IDs of the destinations.
    /// @param saltString The salt string for CREATE2.
    /// @param creationCode The contract creation code.
    /// @param initData The initialization data for the contract.
    /// @param options LZ options for each destination.
    /// @param fee The fee to be paid for each destination.
    /// @param refundAddress The address to refund the excess value sent.
    /// @param callLocally If true, the message will be created locally as well.
    function transmitCreate2Message(
        uint32[] memory destinations,
        string memory saltString,
        bytes memory creationCode,
        bytes memory initData,
        bytes[] calldata options,
        uint256[] memory fee,
        address payable refundAddress,
        bool callLocally
    ) external payable;

    /// @notice Sends a message to other chain(s) create proxy & implementation contracts using CREATE2.
    /// @param destinations The LZ chain IDs of the destinations.
    /// @param saltString The salt string for CREATE2.
    /// @param creationCode The contract creation code.
    /// @param initData The initialization data for the contract.
    /// @param options LZ options for each destination.
    /// @param fee The fee to be paid for each destination.
    /// @param refundAddress The address to refund the excess value sent.
    /// @param callLocally If true, the contracts will be created locally as well.
    function transmitCreateUUPSProxyMessage(
        uint32[] memory destinations,
        string memory saltString,
        bytes memory creationCode,
        bytes memory initData,
        bytes[] calldata options,
        uint256[] memory fee,
        address payable refundAddress,
        bool callLocally
    ) external payable;
}