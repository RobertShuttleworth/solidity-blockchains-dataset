// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "./thirdweb-dev_contracts_eip_interface_IERC20.sol";
import {Ownable} from "./thirdweb-dev_contracts_extension_Ownable.sol";
import {ReentrancyGuard} from "./thirdweb-dev_contracts_external-deps_openzeppelin_security_ReentrancyGuard.sol";

interface IFeeCollector {
    function collectFee(
        address payer,
        address feeRecipient,
        uint256 amount,
        address token
    ) external payable returns (uint256 feeCollected);

    function getTokenFeeRate(address token) external view returns (uint256);

    function isValidFeeRecipient(address recipient) external view returns (bool);
}


contract ioPlasmaVerseFeeCollector is IFeeCollector, Ownable, ReentrancyGuard {
    uint256 public nativeFeeRate = 1; // Default fee rate for native tokens (1%)
    uint256 public tokenFeeRate = 0.5 * 10**16; // Default fee rate for tokens (0.5%)
    address public immutable WETH;

    // Mapping of specific token addresses to fee rates
    mapping(address => uint256) public tokenFeeRates;
    // Mapping to whitelist valid fee recipients
    mapping(address => bool) public validFeeRecipients;

    event FeeCollected(address indexed payer, address indexed feeRecipient, uint256 amount, address token);
    event FeeRateUpdated(address indexed token, uint256 feeRate);
    event FeeRecipientAdded(address indexed recipient);
    event FeeRecipientRemoved(address indexed recipient);
    
    function _canSetOwner() internal view virtual override returns (bool) {
        return msg.sender == owner();
    }

   constructor(address _WETH, address[] memory initialRecipients) {
    require(_WETH != address(0), "Invalid WETH address");
    WETH = _WETH;

    _setupOwner(msg.sender);

    // Add initial fee recipients
    for (uint256 i = 0; i < initialRecipients.length; i++) {
        address recipient = initialRecipients[i];
        require(recipient != address(0), "Invalid recipient address");
        validFeeRecipients[recipient] = true;
        emit FeeRecipientAdded(recipient);
    }
}


  function collectFee(
    address payer,
    address feeRecipient,
    uint256 amount,
    address token
) external payable override nonReentrant returns (uint256 feeCollected) {
    require(payer != address(0), "Invalid payer address");
    require(validFeeRecipients[feeRecipient], "Invalid fee recipient");
    require(amount > 0, "Amount must be greater than zero");

    if (token == WETH) {
        // Native token (ETH/MATIC)
        require(msg.value == amount, "Incorrect ETH sent");

        // Transfer ETH to fee recipient
        (bool success, ) = feeRecipient.call{value: amount}("");
        require(success, "Native token transfer failed");

        feeCollected = amount; // Use the provided amount directly
    } else {
        // ERC-20 token
        require(
            IERC20(token).transferFrom(payer, feeRecipient, amount),
            "Token transfer failed"
        );

        feeCollected = amount; // Use the provided amount directly
    }

    emit FeeCollected(payer, feeRecipient, feeCollected, token);

    return feeCollected;
}

       /// Add or update the fee rate for a specific token
    function setTokenFeeRate(address token, uint256 feeRate) external onlyOwner {
        require(feeRate > 0, "Invalid fee rate");
        tokenFeeRates[token] = feeRate;
        emit FeeRateUpdated(token, feeRate);
    }

    /// Get the fee rate for a token
    function getTokenFeeRate(address token) public view override returns (uint256) {
        return tokenFeeRates[token] > 0 ? tokenFeeRates[token] : (token == WETH ? nativeFeeRate : tokenFeeRate);
    }

    /// Check if an address is a valid fee recipient
    function isValidFeeRecipient(address recipient) public view override returns (bool) {
        return validFeeRecipients[recipient];
    }

    /// Add a fee recipient to the whitelist
    function addFeeRecipient(address recipient) external onlyOwner {
        require(recipient != address(0), "Invalid recipient address");
        validFeeRecipients[recipient] = true;
        emit FeeRecipientAdded(recipient);
    }

    /// Remove a fee recipient from the whitelist
    function removeFeeRecipient(address recipient) external onlyOwner {
        require(validFeeRecipients[recipient], "Recipient not whitelisted");
        validFeeRecipients[recipient] = false;
        emit FeeRecipientRemoved(recipient);
    }

    /// Refund native tokens (ETH/MATIC) held in the contract
    function refundNative(address recipient, uint256 amount) external onlyOwner nonReentrant {
        require(recipient != address(0), "Invalid recipient address");
        require(address(this).balance >= amount, "Insufficient contract balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Native token refund failed");
    }

    /// Refund ERC-20 tokens held in the contract
    function refundERC20(address token, address recipient, uint256 amount) external onlyOwner nonReentrant {
        require(token != address(0), "Invalid token address");
        require(recipient != address(0), "Invalid recipient address");

        uint256 contractBalance = IERC20(token).balanceOf(address(this));
        require(contractBalance >= amount, "Insufficient contract token balance");

        require(
            IERC20(token).transfer(recipient, amount),
            "ERC-20 token refund failed"
        );
    }

    /// Allow the contract to accept ETH from the WETH contract
    receive() external payable {
        require(msg.sender == WETH, "Only WETH contract can send ETH");
    }
}