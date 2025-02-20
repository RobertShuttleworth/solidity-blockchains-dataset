// SPDX-License-Identifier: SHIFT-1.0
pragma solidity ^0.8.9;

import {ConvexCurveArbitrumeUSD} from "./contracts_logic_templates_ConvexCurveArbitrumeUSD.sol";
import {IERC20} from "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import {USDC, eUSD} from "./contracts_constants_arbitrumOne.sol";

contract ConvexCurveArbitrumeUSDUSDC is ConvexCurveArbitrumeUSD {
    constructor()
    ConvexCurveArbitrumeUSD(
        36
    )
    {}

    function _exitBuildingBlockeUSD() internal override {
        _exitBuildingBlockCurve();
        if (IERC20(eUSD).balanceOf(address(this)) > 0) {
            CURVE_POOL.exchange(0, 1, IERC20(eUSD).balanceOf(address(this)), 0);
        }
    }

    function exitWithRepay(address lending) external virtual override {
        _exitWithRepay(lending, USDC);
    }
}