// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

/// @title ICurveRouter
/// @dev Docs: https://docs.curve.fi/router/CurveRouterNG/
interface ICurveRouter {
    /**
    * @notice Performs up to 5 swaps in a single transaction.
    * @dev Routing and swap params must be determined off-chain. This
    *      functionality is designed for gas efficiency over ease-of-use.
    * @param _route Array of [initial token, pool or zap, token, pool or zap, token, ...]
    *               The array is iterated until a pool address of 0x00, then the last
    *               given token is transferred to `_receiver`
    * @param _swap_params Multidimensional array of [i, j, swap_type, pool_type, n_coins] where
    *                     i is the index of input token
    *                     j is the index of output token
    * 
    *                     The swap_type should be:
    *                     1. for `exchange`,
    *                     2. for `exchange_underlying`,
    *                     3. for underlying exchange via zap: factory stable metapools with lending base pool `exchange_underlying`
    *                        and factory crypto-meta pools underlying exchange (`exchange` method in zap)
    *                     4. for coin -> LP token "exchange" (actually `add_liquidity`),
    *                     5. for lending pool underlying coin -> LP token "exchange" (actually `add_liquidity`),
    *                     6. for LP token -> coin "exchange" (actually `remove_liquidity_one_coin`)
    *                     7. for LP token -> lending or fake pool underlying coin "exchange" (actually `remove_liquidity_one_coin`)
    *                     8. for ETH <-> WETH
    * 
    *                     pool_type: 1 - stable, 2 - twocrypto, 3 - tricrypto, 4 - llamma
    *                                10 - stable-ng, 20 - twocrypto-ng, 30 - tricrypto-ng
    * 
    *                     n_coins is the number of coins in pool
    * 
    * @param _amount The amount of input token (`_route[0]`) to be sent.
    * @param _min_dy The minimum amount received after the final swap.
    * @param _pools Array of pools for swaps via zap contracts. This parameter is needed only for swap_type = 3.
    * @param _receiver Address to transfer the final output token to.
    * @return Received amount of the final output token.
    */
    function exchange(
        address[11] calldata _route,
        uint256[5][5] calldata _swap_params,
        uint256 _amount,
        uint256 _min_dy,
        address[5] calldata _pools,
        address _receiver
    ) external payable returns (uint256);

    /**
    * @notice Get amount of the final output token received in an exchange
    * @dev Routing and swap params must be determined off-chain. This
    *      functionality is designed for gas efficiency over ease-of-use.
    * @param _route Array of [initial token, pool or zap, token, pool or zap, token, ...]
    *               The array is iterated until a pool address of 0x00, then the last
    *               given token is transferred to `_receiver`
    * @param _swap_params Multidimensional array of [i, j, swap_type, pool_type, n_coins] where
    *                     i is the index of input token
    *                     j is the index of output token
    * 
    *                     The swap_type should be:
    *                     1. for `exchange`,
    *                     2. for `exchange_underlying`,
    *                     3. for underlying exchange via zap: factory stable metapools with lending base pool `exchange_underlying`
    *                        and factory crypto-meta pools underlying exchange (`exchange` method in zap)
    *                     4. for coin -> LP token "exchange" (actually `add_liquidity`),
    *                     5. for lending pool underlying coin -> LP token "exchange" (actually `add_liquidity`),
    *                     6. for LP token -> coin "exchange" (actually `remove_liquidity_one_coin`)
    *                     7. for LP token -> lending or fake pool underlying coin "exchange" (actually `remove_liquidity_one_coin`)
    *                     8. for ETH <-> WETH
    * 
    *                     pool_type: 1 - stable, 2 - twocrypto, 3 - tricrypto, 4 - llamma
    *                                10 - stable-ng, 20 - twocrypto-ng, 30 - tricrypto-ng
    * 
    *                     n_coins is the number of coins in pool
    * @param _amount The amount of input token (`_route[0]`) to be sent.
    * @param _pools Array of pools for swaps via zap contracts. This parameter is needed only for swap_type = 3.
    * @return Expected amount of the final output token.
    */
    function get_dy(
        address[11] calldata _route,
        uint256[5][5] calldata _swap_params,
        uint256 _amount,
        address[5] calldata _pools
    ) external pure returns (uint256);
}