// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC20} from "./lib_openzeppelin-contracts-upgradeable_lib_openzeppelin-contracts_contracts_token_ERC20_IERC20.sol";
import {ReentrancyGuardUpgradeable} from "./lib_openzeppelin-contracts-upgradeable_contracts_utils_ReentrancyGuardUpgradeable.sol";


contract TokenTransfer is ReentrancyGuardUpgradeable {
    event Withdraw(address sender_, address token_, uint256 amount_);

     /**
     * @dev Performs a transfer in, reverting upon failure. Returns the amount actually transferred to the protocol, in case of a fee.
     * @param token_ address.
     * @param from_ address.
     * @param amount_ uint.
     * @return transfer_num.
     */
    function doTransferIn(address token_, address from_, uint amount_) internal returns (uint) {
        uint balanceBefore = IERC20(token_).balanceOf(address(this));
        IERC20(token_).transferFrom(from_, address(this), amount_);

        bool success;
        assembly {
            switch returndatasize()
                case 0 {                       // This is a non-standard ERC-20
                    success := not(0)          // set success to true
                }
                case 32 {                      // This is a compliant ERC-20
                    returndatacopy(0, 0, 32)
                    success := mload(0)        // Set `success = returndata` of external call
                }
                default {                      // This is an excessively non-compliant ERC-20, revert.
                    revert(0, 0)
                }
        }
        require(success, "TOKEN_TRANSFER_IN_FAILED");
        uint balanceAfter = IERC20(token_).balanceOf(address(this));
        require(balanceAfter >= balanceBefore, "TOKEN_TRANSFER_IN_OVERFLOW");
        return balanceAfter - balanceBefore;  // underflow already checked above, just subtract
    }

    /**
     * @dev Performs a transfer out, ideally returning an explanatory error code upon failure tather than reverting.
     *  If caller has not called checked protocol's balance, may revert due to insufficient cash held in the contract.
     *  If caller has checked protocol's balance, and verified it is >= amount, this should not revert in normal conditions.
     * @param token_ address.
     * @param to_ address.
     * @param amount_ uint.
     * @return transfer_num.
     */
    function doTransferOut(address token_, address to_, uint256 amount_) internal returns (uint) {
        uint balanceBefore = IERC20(token_).balanceOf(address(this));
        IERC20(token_).transfer(to_, amount_);

        bool success;
        assembly {
            switch returndatasize()
                case 0 {                      // This is a non-standard ERC-20
                    success := not(0)          // set success to true
                }
                case 32 {                     // This is a compliant ERC-20
                    returndatacopy(0, 0, 32)
                    success := mload(0)        // Set `success = returndata` of external call
                }
                default {                     // This is an excessively non-compliant ERC-20, revert.
                    revert(0, 0)
                }
        }
        require(success, "TOKEN_TRANSFER_IN_FAILED");
        uint balanceAfter = IERC20(token_).balanceOf(address(this));
        require(balanceAfter <= balanceBefore, "TOKEN_TRANSFER_IN_OVERFLOW");
        return balanceBefore - balanceAfter;  // underflow already checked above, just subtract
    }

    function safeTransferETH(address to, uint256 amount_) internal {
        require(address(this).balance >= amount_, "Insufficient ETH balance");
        (bool success, ) = to.call{value: amount_}(new bytes(0));
        require(success, 'TransferHelper::safeTransferETH: ETH transfer failed');
    }
}