// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FlashLoanSimpleReceiverBase} from "./aave_core-v3_contracts_flashloan_base_FlashLoanSimpleReceiverBase.sol";
import {IPoolAddressesProvider} from "./aave_core-v3_contracts_interfaces_IPoolAddressesProvider.sol";
import {IERC20} from "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import {DAIProxy} from "./contracts_DAIProxy.sol";
import {IWETH} from "./contracts_interfaces_IWETH.sol";

contract CDPFlashLoan is FlashLoanSimpleReceiverBase {
    address payable public daiProxy;
    IWETH public constant WETH = IWETH(0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619);
    
    constructor(
        address _addressProvider,
        address _daiProxy
    ) FlashLoanSimpleReceiverBase(IPoolAddressesProvider(_addressProvider)) {
        daiProxy = payable(_daiProxy);
    }

    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address,  // initiator
        bytes calldata  // params
    ) external override returns (bool) {
        // Handle WETH operations
        WETH.approve(daiProxy, amount);
        DAIProxy(daiProxy).createCDP(amount);
        
        uint256 amountToRepay = amount + premium;
        WETH.approve(address(POOL), amountToRepay);
        
        return true;
    }

    function requestFlashLoan(uint256 amount) external {
        POOL.flashLoanSimple(address(this), address(WETH), amount, "0x", 0);
    }

    function withdrawDAI() external {
        uint256 daiBalance = IERC20(daiProxy).balanceOf(address(this));
        IERC20(daiProxy).transfer(msg.sender, daiBalance);
    }

    receive() external payable {}
}