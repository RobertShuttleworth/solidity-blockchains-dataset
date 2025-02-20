// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./contracts_IBEP20.sol";
import "./contracts_IDao.sol";
import "./openzeppelin_contracts_token_ERC20_IERC20.sol";

contract RevenueCalculator {
    // uint8 public constant numberOfCurrencies = 2;
    // uint256 public log = 0;
    function calculateRateOnWeiBasedOn1stTokenWei(
        address[] memory currencyAddresses,
        uint256[] memory rateOfCurrenciesOnFirstToken
    ) public view returns (uint256[] memory) {
        uint256[] memory rateOfCurrenciesOnFirstTokenWei = new uint256[](
            currencyAddresses.length
        );
        // log = currencyAddresses.length;

        for (uint8 i = 0; i < currencyAddresses.length; i++) {
            uint8 decimal = 18;
            if (currencyAddresses[i] != address(0)) {
                decimal = IBEP20(currencyAddresses[i]).decimals();
            }
            rateOfCurrenciesOnFirstTokenWei[i] =
                rateOfCurrenciesOnFirstToken[i] *
                (10 ** decimal);
        }

        return rateOfCurrenciesOnFirstTokenWei;
    }

    function calculateTotalTokensRevTo1stTokensWei(
        uint256[] memory tokenAmounts,
        uint256[] memory rateOn1TokenWei
    ) public pure returns (uint256) {
        uint256 resultTotalRevenueOn1stTokenWei = 0;
        for (uint8 i = 0; i < tokenAmounts.length; i++) {
            uint256 revenueOn1stTokenWei = (tokenAmounts[i] *
                rateOn1TokenWei[0]) / rateOn1TokenWei[i];
            resultTotalRevenueOn1stTokenWei += revenueOn1stTokenWei;
        }
        return resultTotalRevenueOn1stTokenWei;
    }

    function calculateWidrawableOnTokens(
        address xDaoAddress,
        uint256 totalAmount,
        address[] memory tokenAddresses,
        uint256[] memory rateOfCurrenciesOnFirstTokenWei
    ) public view returns (uint256[] memory) {
        //Code ở đây
        uint256 totalBalanceOn1stToken = 0;
        uint256[] memory balancesOn1stToken = new uint256[](
            tokenAddresses.length
        );
        uint256[] memory withdrawables = new uint256[](tokenAddresses.length);
        for (uint8 i = 0; i < tokenAddresses.length; i++) {
            if (tokenAddresses[i] == address(0)) {
                // Lấy balance của xDaoAddress với đồng native của chain ở đây
                balancesOn1stToken[i] =
                    (xDaoAddress.balance * rateOfCurrenciesOnFirstTokenWei[0]) /
                    rateOfCurrenciesOnFirstTokenWei[i];
            } else {
                balancesOn1stToken[i] =
                    (IBEP20(tokenAddresses[i]).balanceOf(xDaoAddress) *
                        rateOfCurrenciesOnFirstTokenWei[0]) /
                    rateOfCurrenciesOnFirstTokenWei[i];
            }
            totalBalanceOn1stToken += balancesOn1stToken[i];
        }
        if (totalBalanceOn1stToken == 0) {
            return withdrawables;
        }
        for (uint8 i = 0; i < tokenAddresses.length; i++) {
            withdrawables[i] =
                (totalAmount *
                    balancesOn1stToken[i] *
                    rateOfCurrenciesOnFirstTokenWei[i]) /
                (totalBalanceOn1stToken * rateOfCurrenciesOnFirstTokenWei[0]);
        }

        return withdrawables;
    }
    function calculateBalances(
        uint256[] memory _currencyAmounts,
        address[] memory currencyAddresses,
        address xdaoAddress
    ) public view returns (uint256[] memory retBalances) {
        // log = xdaoAddress.balance;
        uint8 baseCurrencyDecimals = 18;
        if (currencyAddresses[0] != address(0)) {
            baseCurrencyDecimals = IBEP20(currencyAddresses[0]).decimals();
        }
        uint256[] memory returnedBalances = new uint256[](
            currencyAddresses.length
        );
        for (uint256 i = 0; i < currencyAddresses.length; i++) {
            uint8 currentCurrencyDecimals = 18;
            if (currencyAddresses[i] != address(0)) {
                currentCurrencyDecimals = IBEP20(currencyAddresses[i])
                    .decimals();
            }
            uint256 currencyBalanceOnUSDTWei = 0;
            if (currencyAddresses[i] == address(0)) {
                currencyBalanceOnUSDTWei = (((xdaoAddress.balance *
                    _currencyAmounts[0]) * (10 ** (baseCurrencyDecimals))) /
                    ((10 ** (currentCurrencyDecimals)) * _currencyAmounts[i]));
            } else {
                currencyBalanceOnUSDTWei = (((IBEP20(currencyAddresses[i])
                    .balanceOf(address(xdaoAddress)) * _currencyAmounts[0]) *
                    (10 ** (baseCurrencyDecimals))) /
                    ((10 ** (currentCurrencyDecimals)) * _currencyAmounts[i]));
            }

            returnedBalances[i] = currencyBalanceOnUSDTWei;
        }

        return returnedBalances;
    }
    function calculateLPHolderSharesOn1stTokenWei(
        address xDaoAddress,
        address lpHolderAddress,
        uint256 totalRevenueOn1stToken
    ) public view returns (uint256) {
        uint256 totalLpSupply = IERC20(IDao(xDaoAddress).lp()).totalSupply();
        uint256 lpHolderSharesOn1stTokenWei = totalRevenueOn1stToken;

        if (lpHolderAddress == address(0)) {
            lpHolderSharesOn1stTokenWei = totalRevenueOn1stToken;
        } else {
            lpHolderSharesOn1stTokenWei =
                (totalRevenueOn1stToken *
                    IERC20(IDao(xDaoAddress).lp()).balanceOf(lpHolderAddress)) /
                totalLpSupply;
        }

        //Code ở đây
        return lpHolderSharesOn1stTokenWei;
    }
}