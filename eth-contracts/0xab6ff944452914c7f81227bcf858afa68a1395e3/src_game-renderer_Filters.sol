// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { Utils } from './src_common_Utils.sol';

/**
 * @author Eto Vass
 */

library Filters {
    function createDropShadowFilter() public pure returns (string memory){
        return "<filter id='drop-shadow' x='-10%' y='-10%' width='120%' height='120%' primitiveUnits='objectBoundingBox' color-interpolation-filters='sRGB'>"
                    "<feDropShadow dx='0.0' dy='0.02' stdDeviation='0.03' flood-color='white' flood-opacity='0.5' in='SourceGraphic' result='shadow1'/>"   
                "</filter>";
    }
}