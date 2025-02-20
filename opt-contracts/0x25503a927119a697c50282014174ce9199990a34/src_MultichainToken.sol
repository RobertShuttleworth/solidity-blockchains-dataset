// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "./lib_openzeppelin-contracts_contracts_token_ERC20_ERC20.sol";
import {IMultichainSender} from "./src_interfaces_IMultichainSender.sol";

contract MultichainToken is ERC20 {

    error InvalidFee();

    /// @notice Crosschain messenger.
    address public immutable messenger;

    /// @notice Token metadata.
    string public tokenMetadata;

    constructor(
        string memory name,
        string memory symbol,
        string memory _tokenMetadata,
        address deployer,
        uint256 initialSupply,
        uint256 initialChain
    ) ERC20(name, symbol) {
        messenger = msg.sender;
        tokenMetadata = _tokenMetadata;
        if (block.chainid == initialChain) {
            _mint(deployer, initialSupply);
        }
    }

    function quoteSend(uint32 destination, uint256 amount, bytes memory option)
        public
        view
        returns (uint256 fee)
    {
        uint32[] memory destinations = new uint32[](1);
        destinations[0] = destination;
        bytes[] memory options = new bytes[](1);
        options[0] = option;
        bytes memory callData = abi.encodeWithSelector(this.receiveTokens.selector, msg.sender, amount);
        (, fee) = IMultichainSender(messenger).quoteCall(destinations, callData, options);
    }

    function sendTokens(uint32 destination, uint256 amount, bytes memory option, uint256 fee)
        public
        payable
    {
        if (fee != msg.value) revert InvalidFee();
        _burn(msg.sender, amount);
        uint32[] memory destinations = new uint32[](1);
        destinations[0] = destination;
        bytes[] memory options = new bytes[](1);
        options[0] = option;
        uint256[] memory fees = new uint256[](1);
        fees[0] = fee;
        bytes memory callData = abi.encodeWithSelector(this.receiveTokens.selector, msg.sender, amount);
        IMultichainSender(messenger).transmitCallMessage{value: msg.value}(
            destinations, callData, options, fees, payable(msg.sender), false
        );
    }

    function receiveTokens(address to, uint256 amount) public {
        require(msg.sender == messenger, "MultichainToken: not messenger");
        _mint(to, amount);
    }

}