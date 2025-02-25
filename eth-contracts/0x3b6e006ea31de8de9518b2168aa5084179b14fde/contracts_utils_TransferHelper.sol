// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import "./lib_openzeppelin-contracts_contracts_token_ERC20_IERC20.sol";

import "./contracts_utils_UtilLib.sol";

library TransferHelper {
    using UtilLib for address;

    function safeTransferToken(address token, address to, uint256 value) internal {
        if (token.isNativeToken()) {
            safeTransferETH(to, value);
        } else {
            safeTransfer(IERC20(token), to, value);
        }
    }

    function safeTransferETH(address to, uint256 value) internal {
        (bool success,) = address(to).call{ value: value }("");
        require(success, "TransferHelper: Sending ETH failed");
    }

    function balanceOf(address token, address addr) internal view returns (uint256) {
        if (token.isNativeToken()) {
            return addr.balance;
        } else {
            return IERC20(token).balanceOf(addr);
        }
    }

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)'))) -> 0xa9059cbb
        (bool success, bytes memory data) = address(token).call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(
            success && (data.length == 0 || abi.decode(data, (bool))), "TransferHelper::safeTransfer: transfer failed"
        );
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)'))) -> 0x23b872dd
        (bool success, bytes memory data) = address(token).call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "TransferHelper::safeTransferFrom: transfer failed"
        );
    }
}