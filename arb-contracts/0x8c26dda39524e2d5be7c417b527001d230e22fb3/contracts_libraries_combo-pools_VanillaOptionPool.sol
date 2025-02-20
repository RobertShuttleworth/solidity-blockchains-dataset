// SPDX-License-Identifier: None
pragma solidity ^0.8.18;

import {FullMath} from "./contracts_libraries_FullMath.sol";

library VanillaOptionPool {
    using FullMath for uint256;

    struct Key {
        uint256 expiry;
        uint256 strike;
        bool isCall;
    }

    function hashOptionPool(
        Key memory optionPoolKey
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    optionPoolKey.expiry,
                    optionPoolKey.strike,
                    optionPoolKey.isCall
                )
            );
    }
}