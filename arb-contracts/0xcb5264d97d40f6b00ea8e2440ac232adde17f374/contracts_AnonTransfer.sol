// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.24;

import './fhevm_lib_TFHE.sol';
import './contracts_common_types.sol';
import './contracts_interfaces_IAnonTransfer.sol';
import './contracts_interfaces_IEERC20.sol';

contract AnonTransfer is IAnonTransfer {
    mapping(uint => Transfer) public transfers;
    
    uint public transferIndex = 0;
    
    constructor() {
        TFHE.setFHEVM(FHEVMConfig.defaultConfig());
    }

    function anonymousTransfer(address _token, einput _target, einput _amount, bytes calldata inputProof) external returns (uint transferId) {

        IEERC20 token = IEERC20(_token);
        euint32 spenderAllowance = token.allowance(msg.sender, address(this));

        euint32 amount = TFHE.asEuint32(_amount, inputProof);
        eaddress target = TFHE.asEaddress(_target, inputProof);

        TFHE.allow(amount, address(this));
        TFHE.allow(target, address(this));

        ebool isTransferValid = TFHE.le(amount, spenderAllowance);
        euint32 transferAmount = TFHE.select(isTransferValid, amount, TFHE.asEuint32(0));

        TFHE.allow(transferAmount, _token);
        TFHE.allow(transferAmount, address(this));
        require(token.transferFrom(msg.sender, address(this), transferAmount), "AnonTransfer: Transfer failed");

        transfers[++transferIndex] = Transfer({
            to: target,
            token: _token,
            amount: transferAmount
        });

        emit TransferInitiated(transferIndex, msg.sender, _token);

        return transferIndex;
    }

    function withdraw(uint _transferIndex) external {
        ebool isAddressCorrect = TFHE.eq(transfers[_transferIndex].to, TFHE.asEaddress(msg.sender));
        require(TFHE.isInitialized(transfers[_transferIndex].amount), "AnonTransfer: Transfer not found");
        euint32 amount = TFHE.select(isAddressCorrect, transfers[_transferIndex].amount, TFHE.asEuint32(0));
        transfers[_transferIndex].amount = TFHE.select(isAddressCorrect, TFHE.asEuint32(0), transfers[_transferIndex].amount);

        IEERC20 token = IEERC20(transfers[_transferIndex].token);
        TFHE.allow(amount, address(token));
        token.transfer(msg.sender, amount);   
    }
}