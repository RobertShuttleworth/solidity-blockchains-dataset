// SPDX-License-Identifier: UNLICENSED
// Shezmu.io
pragma solidity ^0.8.24;

// AKA ShezNight
contract ShezDrop {
    address public owner;

    // Define custom errors
    error CallerNotOwner();
    error InvalidNewOwner();

    // Define modifiers
    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert CallerNotOwner();
        }
        _;
    }
    // Define events
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    // Define constructor
    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), owner);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) {
            revert InvalidNewOwner();
        }
        owner = newOwner;
        emit OwnershipTransferred(owner, newOwner);
    }

    // (c) GasliteDrop
    function airdropERC20(
        address _token,
        address[] calldata _addresses,
        uint256[] calldata _amounts,
        uint256 _totalAmount
    ) external payable onlyOwner {
        assembly {
            // Check that the number of addresses matches the number of amounts
            if iszero(eq(_amounts.length, _addresses.length)) {
                revert(0, 0)
            }

            // transferFrom(address from, address to, uint256 amount)
            mstore(0x00, hex"23b872dd")
            // from address
            mstore(0x04, caller())
            // to address (this contract)
            mstore(0x24, address())
            // total amount
            mstore(0x44, _totalAmount)

            // transfer total amount to this contract
            if iszero(call(gas(), _token, 0, 0x00, 0x64, 0, 0)) {
                revert(0, 0)
            }

            // transfer(address to, uint256 value)
            mstore(0x00, hex"a9059cbb")

            // end of array
            let end := add(_addresses.offset, shl(5, _addresses.length))
            // diff = _addresses.offset - _amounts.offset
            let diff := sub(_addresses.offset, _amounts.offset)

            // Loop through the addresses
            for {
                let addressOffset := _addresses.offset
            } 1 {

            } {
                // to address
                mstore(0x04, calldataload(addressOffset))
                // amount
                mstore(0x24, calldataload(sub(addressOffset, diff)))
                // transfer the tokens
                if iszero(call(gas(), _token, 0, 0x00, 0x64, 0, 0)) {
                    revert(0, 0)
                }
                // increment the address offset
                addressOffset := add(addressOffset, 0x20)
                // if addressOffset >= end, break
                if iszero(lt(addressOffset, end)) {
                    break
                }
            }
        }
    }
}