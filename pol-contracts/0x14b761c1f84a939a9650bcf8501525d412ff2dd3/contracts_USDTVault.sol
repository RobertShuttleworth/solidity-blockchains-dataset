// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./openzeppelin_contracts_utils_ReentrancyGuard.sol";
import "./openzeppelin_contracts_access_Ownable.sol";

contract USDTVault is ReentrancyGuard, Ownable(msg.sender) {
    IERC20 public usdt;
    
    // Mapping to track user balances
    mapping(address => uint256) public balances;
    
    // Events
    event Deposit(address indexed user, uint256 amount);
    event Withdrawal(address indexed user, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    
    // USDT contract address on Polygon
    constructor(address _usdtAddress) {
        usdt = IERC20(_usdtAddress);
    }

    /**
     * @dev Allows users to approve the contract to spend USDT on their behalf
     * @param amount The amount of USDT to approve
     */
    function approve(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        require(usdt.approve(address(this), amount), "Approve failed");
        emit Approval(msg.sender, address(this), amount);
    }
    
    /**
     * @dev Allows users to deposit USDT into the contract
     * @param amount The amount of USDT to deposit
     */
    function deposit(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        require(usdt.approve(address(this), amount), "Approve failed");
        require(usdt.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        
        balances[msg.sender] += amount;
        emit Deposit(msg.sender, amount);
    }
    
    /**
     * @dev Allows users to withdraw their USDT from the contract
     * @param amount The amount of USDT to withdraw
     */
    function withdraw(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        require(balances[msg.sender] >= amount, "Insufficient balance");
        
        balances[msg.sender] -= amount;
        require(usdt.transfer(msg.sender, amount), "Transfer failed");
        
        emit Withdrawal(msg.sender, amount);
    }
    
    /**
     * @dev Returns the USDT balance of a user
     * @param user The address of the user
     */
    function getBalance(address user) external view returns (uint256) {
        return balances[user];
    }
    
    
    /**
     * @dev Emergency function to recover stuck tokens
     * @param token The address of the token to recover
     * @param amount The amount to recover
     */
    function recoverToken(address token, uint256 amount) external onlyOwner {
        require(token != address(usdt), "Cannot recover vault token");
        require(IERC20(token).transfer(owner(), amount), "Token recovery failed");
    }
}