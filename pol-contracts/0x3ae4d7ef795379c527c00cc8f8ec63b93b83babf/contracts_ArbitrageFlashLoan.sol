// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./aave_core-v3_contracts_flashloan_base_FlashLoanSimpleReceiverBase.sol";
import "./aave_core-v3_contracts_interfaces_IPoolAddressesProvider.sol";
import "./openzeppelin_contracts_token_ERC20_IERC20.sol";

contract ArbitrageFlashLoan is FlashLoanSimpleReceiverBase {
    address public owner;

    event FlashLoanInitiated(address token, uint256 amount);
    event FlashLoanExecuted(address token, uint256 amount, uint256 premium);
    event FlashLoanError(string message);
    event Debug(string message, uint256 value);

    error InsufficientBalance(uint256 available, uint256 required);
    error NotEnoughAllowance(uint256 allowance, uint256 required);

    constructor(address _addressProvider)
        FlashLoanSimpleReceiverBase(IPoolAddressesProvider(_addressProvider))
    {
        owner = msg.sender;
    }

    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address /* initiator */,
        bytes calldata /* params */
    ) external override returns (bool) {
        require(msg.sender == address(POOL), "Caller must be AAVE Pool");

        uint256 amountToRepay = amount + premium;

        // Check token balance
        uint256 balance = IERC20(asset).balanceOf(address(this));
        if (balance < amount) {
            revert InsufficientBalance(balance, amount);
        }

        emit Debug("Balance", balance);
        emit Debug("Amount to repay", amountToRepay);

        // Check allowance
        uint256 allowance = IERC20(asset).allowance(address(this), address(POOL));
        if (allowance < amountToRepay) {
            // Try to approve
            IERC20(asset).approve(address(POOL), 0); // Reset allowance
            IERC20(asset).approve(address(POOL), amountToRepay);

            // Verify approval
            allowance = IERC20(asset).allowance(address(this), address(POOL));
            if (allowance < amountToRepay) {
                revert NotEnoughAllowance(allowance, amountToRepay);
            }
        }

        emit FlashLoanExecuted(asset, amount, premium);
        return true;
    }

    function requestFlashLoan(address token, uint256 amount) external {
        require(msg.sender == owner, "Only owner can request flash loan");
        require(amount > 0, "Amount must be greater than 0");

        // Pre-approve the POOL to spend tokens
        try IERC20(token).approve(address(POOL), type(uint256).max) {
            emit Debug("Approved POOL for max amount", type(uint256).max);
        } catch {
            emit FlashLoanError("Failed to approve token");
            return;
        }

        emit FlashLoanInitiated(token, amount);

        try POOL.flashLoanSimple(
            address(this),
            token,
            amount,
            "0x",
            0
        ) {
            // Flash loan request successful
        } catch Error(string memory reason) {
            emit FlashLoanError(reason);
        } catch {
            emit FlashLoanError("Unknown error in flash loan request");
        }
    }

    function getTokenBalance(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    function getTokenAllowance(address token) external view returns (uint256) {
        return IERC20(token).allowance(address(this), address(POOL));
    }

    function approveToken(address token, uint256 amount) external {
        require(msg.sender == owner, "Only owner can approve tokens");
        IERC20(token).approve(address(POOL), amount);
    }

    // Allow contract to receive MATIC
    receive() external payable {}
}