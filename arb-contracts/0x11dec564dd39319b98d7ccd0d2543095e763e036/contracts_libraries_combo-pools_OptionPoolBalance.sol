// SPDX-License-Identifier: None
pragma solidity ^0.8.18;

import {FullMath} from "./contracts_libraries_FullMath.sol";

library OptionPoolBalance {
    using FullMath for uint256;

    struct PoolBalance {
        uint256 token0Balance;
        uint256 token1Balance;
    }

    function updatePoolBalances(
        mapping(bytes32 vaillaOptionPoolHash => PoolBalance) storage self,
        bytes32 optionPoolKeyHash,
        int256 amount0Delta,
        int256 amount1Delta
    ) internal {
        PoolBalance storage poolBalances = self[optionPoolKeyHash];

        // token0
        if (amount0Delta > 0) poolBalances.token0Balance += uint256(amount0Delta);
        else if (poolBalances.token0Balance > uint256(-amount0Delta)) {
            poolBalances.token0Balance -= uint256(-amount0Delta);
        } else {
            poolBalances.token0Balance = 0;
        }
        // token1
        if (amount1Delta > 0) poolBalances.token1Balance += uint256(amount1Delta);
        else if (poolBalances.token1Balance > uint256(-amount1Delta)) {
            poolBalances.token1Balance -= uint256(-amount1Delta);
        } else {
            poolBalances.token1Balance = 0;
        }
    }
}