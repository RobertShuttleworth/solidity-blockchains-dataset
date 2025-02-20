// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { Utils } from './src_common_Utils.sol';
import { Random, RandomCtx } from './src_common_Random.sol';
import { Division } from './src_common_Division.sol';
import { Svg } from './src_common_SVG.sol';
import { VisualBoard } from './src_game-renderer_VisualBoard.sol';
import { DynamicBuffer } from './src_common_DynamicBuffer.sol';
import { TraitsCtx } from './src_common_TraitsCtx.sol';
import { PuzzleDecoder, Puzzle } from './src_curated_PuzzleDecoder.sol';
import { Filters } from './src_game-renderer_Filters.sol';

/**
 * @author Eto Vass
 */

struct AssetRendererContext {
    uint8 numFigures;
    uint16 gridCellSize;
    uint16 gridInnerCellSize;
    uint16 gridCenterOffset;
    uint8 rows;
    uint8 cols;
}

struct Rect {
    uint8 r1;
    uint8 c1;
    uint8 r2;
    uint8 c2;
}

struct Board {
    uint8 rows;
    uint8 cols;
    int16[][] board;
}

struct BoundingBox {
    int left;
    int right;
    int top;
    int bottom;
}

 
library AssetsRenderer {
    
    function adjustBoundingBox(BoundingBox memory bb, int paddingPercentage) internal pure {        
        int padding = Utils.max(
            (bb.right - bb.left) * paddingPercentage / 100,
            (bb.bottom - bb.top) * paddingPercentage / 100
        );

        bb.left -= padding;
        bb.right += padding;
        bb.top -= padding;
        bb.bottom += padding;

        int width = bb.right - bb.left;
        int height = bb.bottom - bb.top;

        if (height > width) {
            int diff = height - width;
            bb.left -= diff / 2;
            bb.right += diff / 2;
        } else {
            int diff = width - height;
            bb.top -= diff / 2;
            bb.bottom += diff / 2;
        }

    }

    function getViewBox(int x1, int y1, int x2, int y2, int paddingPercentage) internal view returns (string memory) {
        BoundingBox memory bb = BoundingBox({left:x1, top:y1, right:x2, bottom:y2});
        adjustBoundingBox(bb, paddingPercentage);

        string memory xStr = Utils.toString(bb.left);
        string memory yStr = Utils.toString(bb.top);
        string memory widthStr = Utils.toString(bb.right - bb.left); 
        string memory heightStr = Utils.toString(bb.bottom - bb.top);

        return string.concat(xStr, ' ', yStr, ' ', widthStr, ' ', heightStr);
    }

    function tokenImage(bytes memory buffer, TraitsCtx memory traitsCtx, string memory assets, Puzzle memory puzzle) internal view {

        uint8 numFigures = 7;
        uint16 gridCellSize = 100;
        uint16 gridInnerCellSize = gridCellSize * 100 / 110; // div by 1.1, rounded 
        uint16 gridCenterOffset = (gridCellSize - gridInnerCellSize) / 2;

        AssetRendererContext memory actx = AssetRendererContext({
            numFigures: numFigures,
            gridCellSize: gridCellSize,
            gridInnerCellSize: gridInnerCellSize,
            gridCenterOffset: gridCenterOffset,
            rows: puzzle.rows,
            cols: puzzle.cols
        });

        uint rcSize = actx.rows > actx.cols ? actx.rows : actx.cols;
        string memory viewBox = getViewBox(0, 0, int(rcSize * actx.gridCellSize), int(rcSize * actx.gridCellSize), 0);

        Utils.concat(buffer, '<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMidYMid meet" viewBox="', bytes(viewBox),
                                '" style="background-color: #000000;"',
                             '>');

        viewBox = getViewBox(0, 0, int(int8(actx.cols)) * int16(actx.gridCellSize), int(int8(actx.rows)) * int16(actx.gridCellSize), 3);

        Utils.concat(buffer, '<svg viewBox="', bytes(viewBox),'">');

        Utils.concat(buffer, bytes(assets));

        VisualBoard.drawGrid(buffer, actx.rows, actx.cols, gridCellSize);
        placeTiles(buffer, actx, puzzle.puzzle);

        Utils.concat(buffer, '</svg>');
        Utils.concat(buffer, '</svg>');
    }

    function placeTiles(bytes memory buffer, AssetRendererContext memory actx, bytes memory puzzle) internal pure {
        string memory innerCellSizeStr = Utils.toString(actx.gridInnerCellSize);
        bytes memory hwStr = bytes(string.concat('width="', innerCellSizeStr, '" height="', innerCellSizeStr, '"'));

        Board memory board = createBoard(actx.rows, actx.cols);
        fillBoard(actx, board, puzzle);
       
        for (uint8 i=0; i<actx.rows; i++)
            for (uint8 j=0; j<actx.cols; j++) {
                int figure = board.board[i][j];

                // figure = int(uint(i + j)) % 6 + 1;   - initially used for testing

                if (figure != 0) {
                    drawFigure(buffer, int(uint(i)), int(uint(j)), bytes(string.concat('fig-', Utils.toString( figure ))), actx, hwStr);
                }
            }
    }

    function createBoard(uint8 rows, uint8 cols) internal pure returns (Board memory) {
        int16[][] memory board = new int16[][](rows);

        for (uint i = 0; i < rows; i++) {
            board[i] = new int16[](cols);
        }

        return Board(rows, cols, board);
    }
 

    function fillBoard(AssetRendererContext memory actx, Board memory board, bytes memory puzzle) internal pure {
        for (uint8 i=0; i<actx.rows; i++) {
            for (uint8 j=0; j<actx.cols; j++) {
                int16 figure = PuzzleDecoder.getFigure(uint8(puzzle[i * actx.cols + j]));
                board.board[i][j] = figure;
            }
        }
    }

    function drawFigure(bytes memory buffer, int row, int col, bytes memory figId, AssetRendererContext memory actx, bytes memory hwStr) internal pure {
        int x;
        int y;

        (x,y) = VisualBoard.logicalToVisualCell(row, col, int(uint(actx.rows)), int(uint(actx.gridCellSize)));       
        x += int(uint(actx.gridCenterOffset));
        y += int(uint(actx.gridCenterOffset)); 
        
        Utils.concat(buffer, '<use href="#', figId, 
                                '" x="', bytes(Utils.toString(x)), 
                                '" y="', bytes(Utils.toString(y)), '" ',
                                hwStr,
                             '/>');
    }
}