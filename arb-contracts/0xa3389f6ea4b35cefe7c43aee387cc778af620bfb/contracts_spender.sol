// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract NativeTokenSpender {
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    function spendNativeToken(
        address signer,
        string memory message,
        bytes memory signature,
        address payable recipient,
        uint256 amount
    ) public {
        require(verify(signer, message, signature), "Invalid signature");
        require(address(this).balance >= amount, "Insufficient balance");

        // Transfer native token
        recipient.transfer(amount);
    }

    function verify(
        address signer,
        string memory message,
        bytes memory signature
    ) public pure returns (bool) {
        bytes32 messageHash = keccak256(abi.encodePacked(message));
        bytes32 ethSignedMessageHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
        );

        (bytes32 r, bytes32 s, uint8 v) = splitSignature(signature);
        address recoveredSigner = ecrecover(ethSignedMessageHash, v, r, s);

        return recoveredSigner == signer;
    }

    function splitSignature(bytes memory sig)
        internal
        pure
        returns (
            bytes32 r,
            bytes32 s,
            uint8 v
        )
    {
        require(sig.length == 65, "Invalid signature length");

        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
    }

    // Function to receive Ether
    receive() external payable {}
}