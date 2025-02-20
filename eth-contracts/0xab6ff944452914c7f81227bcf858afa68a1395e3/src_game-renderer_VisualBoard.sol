// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

/**
 * @author Eto Vass
 */

import { Utils } from "./src_common_Utils.sol";
import { DynamicBuffer } from './src_common_DynamicBuffer.sol';

library VisualBoard {
    function drawGrid(bytes memory buffer, uint8 rows, uint8 cols, uint16 gridCellSize) internal pure {
        bytes memory fill1 = "#191919";
        bytes memory fill2 = "#222222";
        bytes memory hwStr = bytes(string.concat('width="', Utils.toString(gridCellSize + 1), '" height="', Utils.toString(gridCellSize + 1), '"'));

        for (uint8 i=0; i<rows; i++) 
            for (uint8 j=0; j<cols; j++) {
                int x;
                int y;

                (x,y) = logicalToVisualCell(int(uint(i)), int(uint(j)), int(uint(rows)), int(uint(gridCellSize)));
                
                Utils.concat(buffer, '<rect stroke="none" stroke-width="0" x="', bytes(Utils.toString(x)), '" y="', bytes(Utils.toString(y)), '" ', 
                                                hwStr, ' fill="', (i+j) % 2 == 0 ? fill1 : fill2, 
                                      '"/>');


            }
    }

    function logicalToVisualCell(int row, int col, int gridRows, int gridCellSize) internal pure returns (int x, int y) {
        x = col * gridCellSize;
        y =  (gridRows - row - 1) * gridCellSize;
    }
}