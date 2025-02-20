// SPDX-License-Identifier: SHIFT-1.0
pragma solidity ^0.8.9;
import {ConvexCurveArbitrum} from "./contracts_logic_templates_ConvexCurveArbitrum.sol";


contract ConvexCurveArbitrumeUSD is ConvexCurveArbitrum {
    constructor(
        uint256 poolId
    )
    ConvexCurveArbitrum(
        poolId
    ){}

    function exitBuildingBlock(uint256 buildingBlockId) public payable override {
        uint256 liquidity = accountLiquidity(address(this));
        if (buildingBlockId == 0) {
            _exitBuildingBlockConvex();
        }
        else if (buildingBlockId == 1) {
            _exitBuildingBlockCurve();
        }
        else if (buildingBlockId == 2) {
            _exitBuildingBlockeUSD();
        }
        else {
            revert WrongBuildingBlockId(buildingBlockId);
        }
    }

    function _exitBuildingBlockeUSD() internal virtual {
        revert NotImplemented();
    }
}