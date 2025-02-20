// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "./contracts_helpers_Constants.sol";

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
}

contract ERC20Helper is Constants {
    function getBalance(address buyToken, address recipient) internal view returns (uint256 buyAmount) {
        if (buyToken == NATIVE) {
            buyAmount = recipient.balance;
        } else {
            buyAmount = IERC20(buyToken).balanceOf(recipient);
        }
        return buyAmount;
    }

    function safeTransfer(address token, address to, uint256 value) public {
        _callOptionalReturn(token, abi.encodeCall(IERC20.transfer, (to, value)));
    }

    function safeTransferFrom(address token, address from, address to, uint256 value) public {
        _callOptionalReturn(token, abi.encodeCall(IERC20.transferFrom, (from, to, value)));
    }

    function safeApprove(address token, address spender, uint256 amount) public {
        _callOptionalReturn(token, abi.encodeCall(IERC20.approve, (spender, amount)));
    }

    /**
     * @dev Set the calling contract's allowance toward `spender` to `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful. Meant to be used with tokens that require the approval
     * to be set to zero before setting it to a non-zero value, such as USDT.
     */
    function forceApprove(address token, address spender, uint256 value) internal {
        bytes memory approvalCall = abi.encodeCall(IERC20.approve, (spender, value));

        if (!_callOptionalReturnBool(token, approvalCall)) {
            _callOptionalReturn(token, abi.encodeCall(IERC20.approve, (spender, 0)));
            _callOptionalReturn(token, approvalCall);
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     *
     * This is a variant of {_callOptionalReturn} that silently catches all reverts and returns a bool instead.
     */
    function _callOptionalReturnBool(address token, bytes memory data) private returns (bool) {
        bool success;
        uint256 returnSize;
        uint256 returnValue;
        assembly ("memory-safe") {
            success := call(gas(), token, 0, add(data, 0x20), mload(data), 0, 0x20)
            returnSize := returndatasize()
            returnValue := mload(0)
        }
        return success && (returnSize == 0 ? token.code.length > 0 : returnValue == 1);
    }

    function _callOptionalReturn(address token, bytes memory data) private {
        uint256 returnSize;
        uint256 returnValue;
        assembly ("memory-safe") {
            let success := call(gas(), token, 0, add(data, 0x20), mload(data), 0, 0x20)
            // bubble errors
            if iszero(success) {
                let ptr := mload(0x40)
                returndatacopy(ptr, 0, returndatasize())
                revert(ptr, returndatasize())
            }
            returnSize := returndatasize()
            returnValue := mload(0)
        }

        if (returnSize == 0 ? token.code.length == 0 : returnValue != 1) {
            revert("!erc20");
        }
    }
}