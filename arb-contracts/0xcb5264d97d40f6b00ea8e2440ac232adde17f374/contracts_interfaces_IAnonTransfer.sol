pragma solidity ^0.8.24;

import './contracts_common_types.sol';
import './fhevm_lib_TFHE.sol';

interface IAnonTransfer {

    event TransferInitiated(uint transferId, address from, address token);
    event TransferCompleted(uint transferId, address from, address token);

    function anonymousTransfer(address token, einput _target, einput _amount, bytes calldata inputProof) external returns (uint);

    function withdraw(uint _transferId) external;
}