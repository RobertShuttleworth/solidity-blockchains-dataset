// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FlashLoanSimpleReceiverBase} from "./aave_core-v3_contracts_flashloan_base_FlashLoanSimpleReceiverBase.sol";
import {IPoolAddressesProvider} from "./aave_core-v3_contracts_interfaces_IPoolAddressesProvider.sol";
import {IERC20} from "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import {DAIProxy} from "./contracts_DAIProxy.sol";

contract CDPFlashLoan is FlashLoanSimpleReceiverBase {
    address payable public daiProxy;
    
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
        IERC20(asset).approve(daiProxy, amount);
        DAIProxy(daiProxy).createCDP(amount);
        
        uint256 amountToRepay = amount + premium;
        IERC20(asset).approve(address(POOL), amountToRepay);
        
        return true;
    }

    function requestFlashLoan(address token, uint256 amount) external {
        POOL.flashLoanSimple(address(this), token, amount, "0x", 0);
    }

    function withdrawDAI() external {
        uint256 daiBalance = IERC20(daiProxy).balanceOf(address(this));
        IERC20(daiProxy).transfer(msg.sender, daiBalance);
    }

    receive() external payable {}
}