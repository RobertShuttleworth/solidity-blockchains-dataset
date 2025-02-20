// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./openzeppelin_contracts_proxy_Clones.sol";
import "./contracts_MyToken.sol";

contract TheBarracks {
    address public implementation;
    address public feeRecipient;
    uint256 public mintFee = 10 ether; // Example mint fee

    event TokenCreated(address indexed proxy);

    constructor(address _implementation, address _feeRecipient) {
        implementation = _implementation;
        feeRecipient = _feeRecipient;
    }

    function createToken(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) external payable returns (address) {
        require(msg.value >= mintFee, "Insufficient mint fee");

        // Transfer the fee to the recipient
        (bool success, ) = feeRecipient.call{value: msg.value}("");
        require(success, "Fee transfer failed");

        // Clone and initialize the token
        address clone = Clones.clone(implementation);
        TheCryptoArmy(clone).initialize(name, symbol, initialSupply, msg.sender);

        emit TokenCreated(clone);
        return clone;
    }

    function updateMintFee(uint256 newFee) external {
        require(msg.sender == feeRecipient, "Only fee recipient can update fee");
        mintFee = newFee;
    }
}