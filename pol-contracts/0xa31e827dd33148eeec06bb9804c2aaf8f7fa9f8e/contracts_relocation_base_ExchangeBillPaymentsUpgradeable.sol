// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from './openzeppelin_contracts_token_ERC20_IERC20.sol';
import {SafeERC20} from "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";
import {Initializable} from "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";
import {Address} from "./openzeppelin_contracts_utils_Address.sol";

import './contracts_relocation_interfaces_IExchangeBillPayments.sol';


/**
 * @title ERC721 with permit
 * @notice Contract module implementing the IBillRepayments interface
 * @dev Credits to Uniswap V3
 * 
 * @custom:website https://nft.poczta-polska.pl
 * @author rutilicus.eth (ArchXS)
 * @custom:security-contact contact@archxs.com
 */
abstract contract ExchangeBillPaymentsUpgradeable is IExchangeBillPayments, Initializable {
    // Add the library methods
    using SafeERC20 for IERC20;

    /**
     * @dev Value sent is to low.
     */
    error InsufficientTokenBalance(address token);

    function __ExchangeBillPayments_init() internal onlyInitializing {
    }

    function __ExchangeBillPayments_init_unchained() internal onlyInitializing {
    }

    function withdraw(address token, uint256 amount, address recipient) public payable override {
        IERC20 currency = IERC20(token);
        uint256 balance = currency.balanceOf(address(this));

        if (balance < amount) {
            revert InsufficientTokenBalance(token);
        }

        if (balance > 0) {
            if (_isNativeToken(currency)) {
                Address.sendValue(payable(recipient), balance);
            } else {
                currency.safeTransfer(recipient, balance);
            }
        }
    }

    function payout(address token, address payer, address payee, uint256 amount) internal {
        IERC20 currency = IERC20(token);
        if (_isNativeToken(currency) && address(this).balance >= amount) {
            Address.sendValue(payable(payee), amount);
        } else if (payer == address(this)) {
            currency.safeTransfer(payable(payee), amount);
        } else {
            currency.safeTransferFrom(payer, payable(payee), amount);
        }
    }

    function _isNativeToken(IERC20 currency) internal view virtual returns (bool) {
        return address(currency) == address(0);
    }
}