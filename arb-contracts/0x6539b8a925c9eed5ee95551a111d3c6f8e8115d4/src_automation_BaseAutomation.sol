// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Ownable} from "./lib_openzeppelin-contracts-upgradeable_lib_openzeppelin-contracts_contracts_access_Ownable.sol";
import {SafeERC20} from "./lib_openzeppelin-contracts-upgradeable_lib_openzeppelin-contracts_contracts_token_ERC20_utils_SafeERC20.sol";
import {IERC20} from "./lib_openzeppelin-contracts-upgradeable_lib_openzeppelin-contracts_contracts_token_ERC20_IERC20.sol";
import {AutomationCompatibleInterface} from "./src_automation_AutomationCompatibleInterface.sol";
import {AutomationBase} from "./src_automation_AutomationBase.sol";

abstract contract BaseAutomation is Ownable, AutomationCompatibleInterface, AutomationBase {
    
    function withdraw(address payable to, uint amount) external onlyOwner {
        (bool success, ) = to.call{value: amount}("");
        require(success, "Withdraw failed");
    }

    function withdraw(address token, address to, uint amount) external onlyOwner {
        SafeERC20.safeTransfer(IERC20(token), to, amount);
    }

}