// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.27;

import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import {ERC20} from "./openzeppelin_contracts_token_ERC20_ERC20.sol";
import {Ownable} from "./openzeppelin_contracts_access_Ownable.sol";
import {ReentrancyGuard} from "./openzeppelin_contracts_utils_ReentrancyGuard.sol";

contract dHEDGY is ERC20, Ownable, ReentrancyGuard {
    /// Address of the token being locked
    address public tokenAddress;
    /// @dev ERC20 of token being locked this contract
    IERC20 public lockedToken;
    /// @dev Contract paused/unpaused
    bool public lockOpen;
    // Token Name
    string public constant _name = "dead HEDGY";
     // Token Symbol
    string public constant _symbol = "dHEDGY";

    /// Custom Error
    error ContractClosed();
    error InvalidAmount();
    error NotTransferable();

    /// Custom Events
    event Locked(address indexed user, uint256 indexed amount);

    constructor(address _lockedToken, address _owner) 
    ERC20(_name, _symbol)
    Ownable(_owner) {
        tokenAddress = _lockedToken;
        lockedToken = IERC20(tokenAddress);
    }

    /// @dev Lock ERC-20 tokens into this contract
    /// @param amount The amount of tokens to be lockd in contract
    function lock(uint256 amount) external nonReentrant {
        if (!lockOpen) { revert ContractClosed(); }
        if (amount <= 0) { revert InvalidAmount(); }

        lockedToken.transferFrom(_msgSender(), address(this), amount);
        // 
        _mint(_msgSender(), amount);

        emit Locked(_msgSender(), amount);
    }

    /// @dev change the lock status from on/off
    function lockStatus() external onlyOwner {
        lockOpen = !lockOpen;
    }
}