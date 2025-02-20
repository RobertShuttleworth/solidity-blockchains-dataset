// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";
import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./openzeppelin_contracts_utils_ReentrancyGuard.sol";
import "./openzeppelin_contracts_access_Ownable.sol";

/**
 * @title USDTVault
 * @dev A vault contract for depositing and withdrawing USDT tokens
 */
contract USDTVault is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;
    
    IERC20 public usdt;
    
    // Mapping of user addresses to their USDT balances
    mapping(address => uint256) public balances;
    
    // Events
    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    
    /**
     * @dev Constructor sets the USDT token address
     * @param _usdtAddress The address of the USDT token contract on Polygon
     */
    constructor(address _usdtAddress) Ownable(msg.sender) {
        require(_usdtAddress != address(0), "Invalid USDT address");
        usdt = IERC20(_usdtAddress);
    }
    
    /**
     * @dev Allows users to deposit USDT tokens
     * @param _amount The amount of USDT to deposit
     */
    function deposit(uint256 _amount) external nonReentrant {
        require(_amount > 0, "Amount must be greater than 0");
        require(usdt.balanceOf(msg.sender) >= _amount, "Insufficient USDT balance");
        
        // Check if the contract has sufficient allowance
        uint256 allowance = usdt.allowance(msg.sender, address(this));
        require(allowance >= _amount, "Insufficient allowance. Please approve tokens first");
        
        // Transfer USDT from user to contract using safeTransferFrom
        usdt.safeTransferFrom(msg.sender, address(this), _amount);
        
        // Update user's balance
        balances[msg.sender] += _amount;
        
        emit Deposited(msg.sender, _amount);
    }
    
    /**
     * @dev Allows users to withdraw their deposited USDT tokens
     * @param _amount The amount of USDT to withdraw
     */
    function withdraw(uint256 _amount) external nonReentrant {
        require(_amount > 0, "Amount must be greater than 0");
        require(balances[msg.sender] >= _amount, "Insufficient balance");
        
        // Update user's balance before transfer to prevent reentrancy
        balances[msg.sender] -= _amount;
        
        // Transfer USDT from contract to user using safeTransfer
        usdt.safeTransfer(msg.sender, _amount);
        
        emit Withdrawn(msg.sender, _amount);
    }
    
    /**
     * @dev Returns the USDT balance of a user
     * @param _user The address of the user
     * @return The user's USDT balance in the vault
     */
    function getBalance(address _user) external view returns (uint256) {
        return balances[_user];
    }
    
    /**
     * @dev Returns the total USDT balance held by the contract
     * @return The total USDT balance
     */
    function getTotalBalance() external view returns (uint256) {
        return usdt.balanceOf(address(this));
    }

    /**
     * @dev Returns the current allowance for a user
     * @param _user The address of the user
     * @return The amount of USDT tokens the contract is allowed to spend
     */
    function getAllowance(address _user) external view returns (uint256) {
        return usdt.allowance(_user, address(this));
    }
}