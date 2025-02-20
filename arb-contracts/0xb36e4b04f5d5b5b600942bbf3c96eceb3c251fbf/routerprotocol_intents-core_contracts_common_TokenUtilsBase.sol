// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {IWETH} from "./routerprotocol_intents-core_contracts_interfaces_IWETH.sol";
import {SafeERC20, IERC20} from "./routerprotocol_intents-core_contracts_utils_SafeERC20.sol";

abstract contract TokenUtilsBase {
    using SafeERC20 for IERC20;

    function wnative() public view virtual returns (address);

    function native() public view virtual returns (address);

    function approveToken(
        address _tokenAddr,
        address _to,
        uint256 _amount
    ) internal {
        if (_tokenAddr == native()) return;

        if (IERC20(_tokenAddr).allowance(address(this), _to) < _amount) {
            IERC20(_tokenAddr).safeApprove(_to, _amount);
        }
    }

    function pullTokensIfNeeded(
        address _token,
        address _from,
        uint256 _amount
    ) internal returns (uint256) {
        // handle max uint amount
        if (_amount == type(uint256).max) {
            _amount = getBalance(_token, _from);
        }

        if (
            _from != address(0) &&
            _from != address(this) &&
            _token != native() &&
            _amount != 0
        ) {
            IERC20(_token).safeTransferFrom(_from, address(this), _amount);
        }

        return _amount;
    }

    function withdrawTokens(
        address _token,
        address _to,
        uint256 _amount
    ) internal returns (uint256) {
        if (_amount == type(uint256).max) {
            _amount = getBalance(_token, address(this));
        }

        if (_to != address(0) && _to != address(this) && _amount != 0) {
            if (_token != native()) {
                IERC20(_token).safeTransfer(_to, _amount);
            } else {
                (bool success, ) = _to.call{value: _amount}("");
                require(success, "native send fail");
            }
        }

        return _amount;
    }

    function depositWnative(uint256 _amount) internal {
        IWETH(wnative()).deposit{value: _amount}();
    }

    function withdrawWnative(uint256 _amount) internal {
        IWETH(wnative()).withdraw(_amount);
    }

    function getBalance(
        address _tokenAddr,
        address _acc
    ) internal view returns (uint256) {
        if (_tokenAddr == native()) {
            return _acc.balance;
        } else {
            return IERC20(_tokenAddr).balanceOf(_acc);
        }
    }

    function getTokenDecimals(address _token) internal view returns (uint256) {
        if (_token == native()) return 18;

        return IERC20(_token).decimals();
    }
}