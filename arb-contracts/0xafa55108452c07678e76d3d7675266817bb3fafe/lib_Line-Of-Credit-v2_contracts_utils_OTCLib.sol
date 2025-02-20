// SPDX-License-Identifier: GPL-3.0
// Copyright: https://github.com/credit-cooperative/Line-Of-Credit-v2/blob/master/COPYRIGHT.md

pragma solidity 0.8.25;

import {IOTC} from "./lib_Line-Of-Credit-v2_contracts_interfaces_IOTC.sol";
import {IOracle} from "./lib_Line-Of-Credit-v2_contracts_interfaces_IOracle.sol";
import {LineLib} from "./lib_Line-Of-Credit-v2_contracts_utils_LineLib.sol";
import {CreditLib} from "./lib_Line-Of-Credit-v2_contracts_utils_CreditLib.sol";
import {IERC20Metadata} from "./lib_openzeppelin-contracts_contracts_interfaces_IERC20Metadata.sol";
import {ILineOfCredit} from "./lib_Line-Of-Credit-v2_contracts_interfaces_ILineOfCredit.sol";
import {FeesLib} from "./lib_Line-Of-Credit-v2_contracts_utils_FeesLib.sol";

struct OTCState {
    mapping(address => bool) stableCoinWhitelist;
    uint128 nonStableCoinPriceImpact; // In BPS
}

/**
 * @title   - OTCLib
 * @author  - Credit Cooperative
 * @notice  - Core logic used by Escrow and Spigot for OTC swaps.
 */
library OTCLib {
    uint256 constant BASE_DENOMINATOR = 10000; // 10000 bps = 100%

    error PriceImpactThresoldExceeded();
    error ExpiredOrder();
    error NotOnetoOne();



    // see Escrow.updateStableCoinWhitelist
    function updateStableCoinWhitelist(OTCState storage self, address stableCoin, bool isAllowed) external {
        self.stableCoinWhitelist[stableCoin] = isAllowed;
    }

    function _getDecimals(address token) internal view returns (uint8) {
        return IERC20Metadata(token).decimals();
    }

    // see Escrow.otcSwap
    function otcSwap(
        OTCState storage self,
        IOTC.OTC memory otc,
        ILineOfCredit.Fees memory fees,
        address oracle,
        address protocolTreasury
    ) external returns (uint256) {
        if (otc.expiration < block.timestamp) {
            revert ExpiredOrder();
        }

        // calculate swapFee for protocolTreasury
        uint256 swapFeeAmount = FeesLib._calculateSwapFee(fees, otc.tokenComingInAmount);
        if (self.stableCoinWhitelist[otc.tokenGoingOut] && self.stableCoinWhitelist[otc.tokenComingIn]) {
            if (otc.tokenGoingOutAmount != otc.tokenComingInAmount) {
                revert NotOnetoOne();
            }

            LineLib.sendOutTokenOrETH(otc.tokenGoingOut, otc.counterparty, otc.tokenGoingOutAmount); // send stablecoin
            LineLib.receiveTokenOrETH(otc.tokenComingIn, otc.counterparty, otc.tokenComingInAmount); // receive stablecoin
            LineLib.sendOutTokenOrETH(otc.tokenComingIn, protocolTreasury, swapFeeAmount); // send swapFee to protocolTreasury
            return (otc.tokenComingInAmount - swapFeeAmount);
        }

        int256 tokenGoingOutUsdPrice = IOracle(oracle).getLatestAnswer(otc.tokenGoingOut);

        if (tokenGoingOutUsdPrice == 0) {
            revert IOracle.NullPrice(otc.tokenGoingOut);
        }

        uint256 tokenGoingOutAmountUsdValue =
            CreditLib.calculateValue(tokenGoingOutUsdPrice, otc.tokenGoingOutAmount, _getDecimals(otc.tokenGoingOut));

        int256 tokenComingInUsdValue = IOracle(oracle).getLatestAnswer(otc.tokenComingIn);

        if (tokenComingInUsdValue == 0) {
            revert IOracle.NullPrice(otc.tokenComingIn);
        }

        uint256 tokenComingInAmountUsdValue = CreditLib.calculateValue(
            tokenComingInUsdValue, otc.tokenComingInAmount + swapFeeAmount, _getDecimals(otc.tokenComingIn)
        );

        // handle negative price impact
        if (tokenGoingOutAmountUsdValue > tokenComingInAmountUsdValue) {
            uint256 allowedPriceImpact =
                (self.nonStableCoinPriceImpact * tokenGoingOutAmountUsdValue) / BASE_DENOMINATOR;
            if ((tokenGoingOutAmountUsdValue - tokenComingInAmountUsdValue) > allowedPriceImpact) {
                revert PriceImpactThresoldExceeded();
            }
        }

        // send and receive tokens
        LineLib.sendOutTokenOrETH(otc.tokenGoingOut, otc.counterparty, otc.tokenGoingOutAmount); // send token
        LineLib.receiveTokenOrETH(otc.tokenComingIn, otc.counterparty, otc.tokenComingInAmount); // receive token
        LineLib.sendOutTokenOrETH(otc.tokenComingIn, protocolTreasury, swapFeeAmount); // send swapFee to protocolTreasury
        return (otc.tokenComingInAmount - swapFeeAmount);
    }
}