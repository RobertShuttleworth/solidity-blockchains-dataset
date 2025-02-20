// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

// Import OpenZeppelin Contracts
import "./lib_openzeppelin-contracts-upgradeable_contracts_token_ERC20_IERC20Upgradeable.sol";
import "./lib_openzeppelin-contracts-upgradeable_contracts_access_OwnableUpgradeable.sol";
import "./lib_openzeppelin-contracts-upgradeable_contracts_security_ReentrancyGuardUpgradeable.sol";
import "./lib_openzeppelin-contracts-upgradeable_contracts_proxy_utils_Initializable.sol";


/**
 * @title TGEDistributor
 * @dev Contract to swap inToken tokens for outToken tokens with secure functionality.
 */
contract FlexPoolDistributor is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    IERC20Upgradeable public inToken;
    IERC20Upgradeable public outToken;
    uint256 public totalOutToken;



    uint256 public totalSwapped; 

    event Swapped(address indexed user, uint256 InTokenAmount, uint256 OutTokenAmount);
    event RemainingOutTokenWithdrawn(address indexed to, uint256 amount);
    event InTokenWithdrawn(address indexed to, uint256 amount);

      /**
 * @dev Initializes the contract with inToken and outToken token addresses and sets the total OutToken available.
 * @param _inToken Address of the inToken token contract
 * @param _outToken Address of the outToken token contract
 * @param _totalOutToken Total amount of outToken tokens available for swapping
 */
    function initialize(address _inToken, address _outToken, uint256 _totalOutToken) external initializer {
        __Ownable_init();
        require(_inToken != address(0), "Invalid InToken token address");
        require(_outToken != address(0), "Invalid OutToken token address");

        inToken = IERC20Upgradeable(_inToken);
        outToken = IERC20Upgradeable(_outToken);
        totalOutToken = _totalOutToken;
    }

    /**
     * @dev Allows the owner to update the total outToken tokens available for swapping
     * @param newTotalOutToken New total outToken tokens available for swapping
     */
    function setTotalOutToken(uint256 newTotalOutToken) external onlyOwner {
        totalOutToken = newTotalOutToken;
    }

    /**
     * @dev Swaps user's inToken tokens for outToken tokens based on their balance.
     * The calculation rounds down to the nearest integer.
     * @param inTokenAmount Amount of inToken tokens the user wants to swap
     */
    function swap(uint256 inTokenAmount) external nonReentrant {
        require(inTokenAmount > 0, "Amount must be greater than zero");

        uint256 inTokenTotalSupply = inToken.totalSupply();
        require(inTokenTotalSupply > 0, "InToken total supply is zero");

        // Calculate user's share: floor(totalOutToken * (inTokenAmount / inTokenTotalSupply))
        uint256 outTokenAmount = (totalOutToken * inTokenAmount) / inTokenTotalSupply;
        require(outTokenAmount > 0, "Calculated OutToken amount is zero");
        
        // Check contract outToken balance to ensure availability
        require(totalSwapped + outTokenAmount <= totalOutToken, "Not enough OutToken available");

        // Transfer inToken tokens from user to this contract
        require(
            inToken.transferFrom(msg.sender, address(this), inTokenAmount),
            "InToken transfer failed"
        );

        // Transfer 0utToken tokens to the user
        require(
            outToken.transfer(msg.sender, outTokenAmount),
            "OutToken transfer failed"
        );

        // Update total swapped to track outToken distributed
        totalSwapped += outTokenAmount;

        emit Swapped(msg.sender, inTokenAmount, outTokenAmount);
    }

    /**
     * @dev Allows the owner to withdraw any remaining outToken tokens
     * @param to Address to send the remaining outToken tokens
     */
    function withdrawRemainingOutToken(address to) external onlyOwner {
        require(to != address(0), "Invalid address for withdrawal");
        uint256 remaining = outToken.balanceOf(address(this));
        require(remaining > 0, "No OutToken to withdraw");
        require(outToken.transfer(to, remaining), "Withdrawal failed");
        emit RemainingOutTokenWithdrawn(to, remaining);
    }

    /**
     * @dev Allows the owner to withdraw collected inToken tokens
     * @param to Address to send the collected inToken tokens
     */
    function withdrawInToken(address to) external onlyOwner {
        require(to != address(0), "Invalid address for withdrawal");
        uint256 collected = inToken.balanceOf(address(this));
        require(collected > 0, "No InToken to withdraw");
        require(inToken.transfer(to, collected), "Withdrawal failed");
        emit InTokenWithdrawn(to, collected);
    }

    function setInToken(address inToken_) external onlyOwner {
        inToken = IERC20Upgradeable(inToken_);
    }

    function setOutToken(address outToken_) external onlyOwner {
        outToken = IERC20Upgradeable(outToken_);
    }


}