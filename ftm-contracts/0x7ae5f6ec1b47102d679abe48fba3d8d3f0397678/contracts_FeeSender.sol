// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import './openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol';
import './openzeppelin_contracts_token_ERC20_IERC20.sol';

contract FeeSender {
    using SafeERC20 for IERC20;

    address public receiver40 = 0xf4475aC4B4a07b701C790d068a06eE6B33533218;
    address public receiver60 = 0x4a14507784fecB4bbeADF5e8d34dC5Cf5b7f22a7;
    
    function changeReceiver(address newReceiver) external {
        if(msg.sender == receiver40)
            receiver40 = newReceiver;
        if(msg.sender == receiver60)
            receiver60 = newReceiver;
    }

    function withdraw(address[] calldata tokens, bool withdrawGasToken) external {
        uint balance;
        IERC20 token;
        
        if(withdrawGasToken) {
            balance = address(this).balance;
            
            (bool sent, bytes memory data) = receiver60.call{value: balance * 6000 / 10000}("");
            require(sent, "Failed to send Ether");
            (sent, data) = receiver40.call{value: address(this).balance}("");
            require(sent, "Failed to send Ether");
        }
        
        for(uint i = 0; i < tokens.length; i++) {
            token = IERC20(tokens[i]);
            balance = token.balanceOf(address(this));
            
            token.transfer(receiver60, balance * 6000 / 10000);
            token.transfer(receiver40, token.balanceOf(address(this)));
        }
    }
    
    receive() external payable {}
} 