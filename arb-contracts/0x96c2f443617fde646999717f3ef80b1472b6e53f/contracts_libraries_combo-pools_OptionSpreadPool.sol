// SPDX-License-Identifier: None
pragma solidity ^0.8.18;

import {SimpleMath} from "./contracts_libraries_combo-pools_SimpleMath.sol";
import {FullMath} from "./contracts_libraries_FullMath.sol";

library OptionSpreadPool {
    struct Key {
        uint256 expiry;
        uint256 strikeLow;
        uint256 strikeHigh;
        bool isCall;
    }

    function hashOptionSpreadKey(
        Key memory optionSpreadPoolKey
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    optionSpreadPoolKey.expiry,
                    optionSpreadPoolKey.strikeLow,
                    optionSpreadPoolKey.strikeHigh,
                    optionSpreadPoolKey.isCall
                )
            );
    }

    function calculateCallSpreadPayoffInAsset(
        bool isLong,
        uint256 strikeLow,
        uint256 strikeHigh,
        uint256 priceAtExpiry,
        uint8 token1Decimals
    ) internal pure returns (uint256 totalPayoff) {
        require(strikeLow < strikeHigh, "strikeLow must be < strikeHigh");
        uint256 payoff;

        if (priceAtExpiry > strikeLow) {
            payoff = SimpleMath.min(
                priceAtExpiry - strikeLow,
                strikeHigh - strikeLow
            );
        }

        totalPayoff = FullMath.mulDiv(
            payoff,
            10 ** token1Decimals,
            priceAtExpiry
        );

        if (!isLong) {
            totalPayoff = (FullMath.mulDiv(
                strikeHigh - strikeLow,
                10 ** token1Decimals,
                strikeHigh
            ) - totalPayoff);
        }
    }
}