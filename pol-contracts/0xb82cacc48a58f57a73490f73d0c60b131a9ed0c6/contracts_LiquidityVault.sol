// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./openzeppelin_contracts_access_Ownable.sol";

contract LiquidityVault is Ownable {
    IERC20 public token;
    address public presaleContract;
    
    constructor(address _token) {
        require(_token != address(0), "Invalid token address");
        token = IERC20(_token);
    }
    
    function setPresaleContract(address _presale) external onlyOwner {
        require(_presale != address(0), "Invalid presale address");
        require(presaleContract == address(0), "Presale already set");
        presaleContract = _presale;
    }
    
    function approvePresale() external onlyOwner {
        require(presaleContract != address(0), "Presale not set");
        uint256 balance = token.balanceOf(address(this));
        token.approve(presaleContract, balance);
    }
}