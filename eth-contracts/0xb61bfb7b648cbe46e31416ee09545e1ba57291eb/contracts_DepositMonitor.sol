// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import {SafeERC20} from "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";

/**
 * @title DepositMonitor
 * @dev A contract that allows users to deposit VTRS tokens which are then transferred to the DAO wallet for
 * further bridge operations
 */
contract DepositMonitor {
    using SafeERC20 for IERC20;

    // wVTRS token contract
    IERC20 public immutable depositToken;

    // Receiver address that will receive all deposits
    address public immutable bridgeReceiver;

    /*
     * @notice Event emitted when a deposit is made
     * @param depositor The address that made the deposit
     * @param targetAddress The address to which the tokens should be bridged
     * @param amount The amount of wVTRS tokens deposited
     */
    event BridgeDeposit(address indexed sender, address indexed targetAddress, uint256 amount);

    /**
     * @param _depositToken The address of the token contract
     * @param _bridgeReceiver The address of the bridge receiver
     */
    constructor(address _depositToken, address _bridgeReceiver) {
        require(_depositToken != address(0), "Invalid token address");
        require(_bridgeReceiver != address(0), "Invalid receiver address");

        depositToken = IERC20(_depositToken);
        bridgeReceiver = _bridgeReceiver;
    }

    /**
     * @notice Allows users to deposit VTRS tokens which are then transferred to the receiver
     * and bridged to the target address
     *
     * @param targetAddress The address to which the tokens should be bridged
     * @param amount The amount of VTRS tokens to deposit
     */
    function deposit(address targetAddress, uint256 amount) external {
        require(amount != 0, "Amount must be greater than 0");
        require(targetAddress != address(0), "Invalid target address");

        // Transfer tokens from sender to the receiver address
        depositToken.safeTransferFrom(msg.sender, bridgeReceiver, amount);

        emit BridgeDeposit(msg.sender, targetAddress, amount);
    }
}