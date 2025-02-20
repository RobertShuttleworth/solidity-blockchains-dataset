// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface AaveV3Pool {
    /**
     * @notice Withdraws an `amount` of underlying asset from the reserve, burning the equivalent aTokens owned
     * E.g. User has 100 aUSDC, calls withdraw() and receives 100 USDC, burning the 100 aUSDC
     * @param asset The address of the underlying asset to withdraw
     * @param amount The underlying amount to be withdrawn
     *   - Send the value type(uint256).max in order to withdraw the whole aToken balance
     * @param to The address that will receive the underlying, same as msg.sender if the user
     *   wants to receive it on his own wallet, or a different address if the beneficiary is a
     *   different wallet
     * @return The final amount withdrawn
     */
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);

    /**
     * @notice Supplies an `amount` of underlying asset into the reserve, receiving in return overlying aTokens.
     * - E.g. User supplies 100 USDC and gets in return 100 aUSDC
     * @param asset The address of the underlying asset to supply
     * @param amount The amount to be supplied
     * @param onBehalfOf The address that will receive the aTokens, same as msg.sender if the user
     *   wants to receive them on his own wallet, or a different address if the beneficiary of aTokens
     *   is a different wallet
     * @param referralCode Code used to register the integrator originating the operation, for potential rewards.
     *   0 if the action is executed directly by the user, without any middle-man
     */
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
}

contract AaveV3Modeler {
    function aaveV3Supply(AaveV3Pool pool, address sellToken, uint256 sellAmount, address recipient)
        external
        returns (uint256)
    {
        pool.supply(sellToken, sellAmount, recipient, uint16(0));
        /*
        Note that supply does not return an amount. We cannot do a buy token balance diff because it 
        would be zero due to the way aave computes the balances (depend on time accrued since deposit, so 0).
        We do know that there's a 1:1 relationship so we return the sell amount == buy amount
        */
        return sellAmount;
    }

    function aaveV3Withdraw(AaveV3Pool pool, address buyToken, uint256 sellAmount, address recipient)
        external
        returns (uint256)
    {
        // assets pegged 1:1
        return pool.withdraw(buyToken, sellAmount, recipient);
    }
}