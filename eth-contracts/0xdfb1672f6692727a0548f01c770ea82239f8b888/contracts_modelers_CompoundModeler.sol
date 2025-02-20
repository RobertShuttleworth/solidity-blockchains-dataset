// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "./contracts_helpers_ERC20Helper.sol";

interface cMarket {
    function mint(uint256 sellAmount) external;
    function redeem(uint256 sellAmount) external;
}

contract CompoundModeler is ERC20Helper {
    function mintCompoundToken(cMarket market, uint256 sellAmount, address cToken)
        external
        returns (uint256 buyAmount)
    {
        uint256 startBalance = getBalance(cToken, address(this));
        market.mint(sellAmount);
        uint256 endBalance = getBalance(cToken, address(this));
        buyAmount = endBalance - startBalance;
    }

    function redeemCompoundToken(cMarket market, uint256 sellAmount, address underlyingToken)
        external
        returns (uint256 buyAmount)
    {
        uint256 startBalance = getBalance(underlyingToken, address(this));
        market.redeem(sellAmount);
        uint256 endBalance = getBalance(underlyingToken, address(this));
        buyAmount = endBalance - startBalance;
    }
}