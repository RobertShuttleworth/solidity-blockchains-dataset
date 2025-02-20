// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./contracts_libraries_uniswapV3_TransferHelper.sol";

contract DCAVault {
    address public managementContract;

    receive() external payable {}

    modifier onlyManagement() {
        require(msg.sender == managementContract, "Only management can call this function");
        _;
    }

    constructor(address _managementContract) {
        managementContract = _managementContract;
    }

    function transfer(address token, address to, uint256 value) external onlyManagement {
        TransferHelper.safeTransfer(token, to, value);
    }

    function transferETH(address to, uint256 value) external onlyManagement {
        TransferHelper.safeTransferETH(to, value);
    }
}