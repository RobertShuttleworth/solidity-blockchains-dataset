// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {FlashLoanSimpleReceiverBase} from "./lib_aave-v3-origin_src_contracts_misc_flashloan_base_FlashLoanSimpleReceiverBase.sol";
import {IPoolAddressesProvider} from "./lib_aave-v3-origin_src_contracts_interfaces_IPoolAddressesProvider.sol";
import {IERC20} from "./lib_aave-v3-origin_lib_solidity-utils_lib_openzeppelin-contracts-upgradeable_lib_openzeppelin-contracts_contracts_interfaces_IERC20.sol";

contract Oblivion is FlashLoanSimpleReceiverBase {
    constructor(address _addressProvider) FlashLoanSimpleReceiverBase(IPoolAddressesProvider(_addressProvider)) {}

    function requestFlashLoan(address _token, uint256 _amount) public {
        address receiverAddress = address(this);
        address asset = _token;
        uint256 amount = _amount;
        bytes memory params = "";
        uint16 referralCode = 0;

        POOL.flashLoanSimple(
            receiverAddress,
            asset,
            amount,
            params,
            referralCode
        );
    }

    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external override returns (bool) {
        uint256 totalAmount = amount + premium;
        IERC20(asset).approve(address(POOL), totalAmount);

        return true;
    }
}