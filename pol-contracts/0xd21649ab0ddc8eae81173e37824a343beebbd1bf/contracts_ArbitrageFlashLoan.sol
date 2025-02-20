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

    constructor()
        FlashLoanSimpleReceiverBase(
            // Polygon AAVE V3 Pool Provider
            IPoolAddressesProvider(0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb)
        )
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
        require(
            IERC20(asset).balanceOf(address(this)) >= amount,
            "Insufficient borrowed amount"
        );

        emit FlashLoanExecuted(asset, amount, premium);

        // Approve repayment - approve exact amount needed
        IERC20(asset).approve(address(POOL), amountToRepay);

        return true;
    }

    function requestFlashLoan(address token, uint256 amount) external {
        require(msg.sender == owner, "Only owner can request flash loan");
        require(amount > 0, "Amount must be greater than 0");

        // Pre-approve the POOL to spend tokens
        IERC20(token).approve(address(POOL), amount * 2); // Approve double the amount to cover premium

        emit FlashLoanInitiated(token, amount);

        // Request the flash loan
        POOL.flashLoanSimple(
            address(this),
            token,
            amount,
            "0x",
            0
        );
    }

    // Allow contract to receive MATIC
    receive() external payable {}

    // Function to approve tokens if needed
    function approveToken(address token, uint256 amount) external {
        require(msg.sender == owner, "Only owner can approve tokens");
        IERC20(token).approve(address(POOL), amount);
    }
}