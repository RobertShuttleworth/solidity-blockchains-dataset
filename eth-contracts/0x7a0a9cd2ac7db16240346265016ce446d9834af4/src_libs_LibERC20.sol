// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/******************************************************************************\
* Author: Nick Mudge
*
/******************************************************************************/

import { IERC20 } from "./src_interfaces_IERC20.sol";

library LibERC20 {
    function decimals(address _token) internal view returns (uint8) {
        _assertNotEmptyContract(_token);
        IERC20 tokenContract = IERC20(_token);
        try tokenContract.decimals() returns (uint8 decimals_) {
            return decimals_;
        } catch {
            revert("LibERC20: call to decimals() failed");
        }
    }

    function symbol(address _token) internal view returns (string memory) {
        _assertNotEmptyContract(_token);
        IERC20 tokenContract = IERC20(_token);
        try tokenContract.symbol() returns (string memory symbol_) {
            return symbol_;
        } catch {
            revert("LibERC20: call to symbol() failed");
        }
    }

    function balanceOf(address _token, address _who) internal view returns (uint256) {
        _assertNotEmptyContract(_token);
        IERC20 tokenContract = IERC20(_token);
        try tokenContract.balanceOf(_who) returns (uint256 balance) {
            return balance;
        } catch {
            // Handle the error (e.g., return a default value or rethrow a custom error)
            revert("LibERC20: call to balanceOf() failed");
        }
    }

    function transferFrom(address _token, address _from, address _to, uint256 _value) internal {
        _assertNotEmptyContract(_token);
        (bool success, bytes memory result) = _token.call(abi.encodeWithSelector(IERC20.transferFrom.selector, _from, _to, _value));
        handleReturn(success, result);
    }

    function transfer(address _token, address _to, uint256 _value) internal {
        _assertNotEmptyContract(_token);
        (bool success, bytes memory result) = _token.call(abi.encodeWithSelector(IERC20.transfer.selector, _to, _value));
        handleReturn(success, result);
    }

    function handleReturn(bool _success, bytes memory _result) internal pure {
        if (_success) {
            if (_result.length > 0) {
                require(abi.decode(_result, (bool)), "LibERC20: transfer or transferFrom returned false");
            }
        } else {
            if (_result.length > 0) {
                // bubble up any reason for revert
                // see https://github.com/OpenZeppelin/openzeppelin-contracts/blob/c239e1af8d1a1296577108dd6989a17b57434f8e/contracts/utils/Address.sol#L201
                assembly {
                    revert(add(32, _result), mload(_result))
                }
            } else {
                revert("LibERC20: transfer or transferFrom reverted");
            }
        }
    }

    function _assertNotEmptyContract(address _token) internal view {
        uint256 size;
        assembly {
            size := extcodesize(_token)
        }
        require(size > 0, "LibERC20: ERC20 token address has no code");
    }
}