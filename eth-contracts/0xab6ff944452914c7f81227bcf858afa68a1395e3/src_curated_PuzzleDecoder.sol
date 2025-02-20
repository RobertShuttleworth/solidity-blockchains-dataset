
//SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

/**
 * @author Eto Vass
 */

struct Puzzle {
    uint8 rows;
    uint8 cols;
    uint8 maxMoves;
    bytes puzzle;
}

library PuzzleDecoder {
    function decodePuzzle(bytes memory curatedPuzzles, uint puzzleId) internal pure returns (Puzzle memory puzzles) {
        uint index = 0;
        

        index = 2 + puzzleId * 2;

        index = uint(uint8(curatedPuzzles[index])) | (uint(uint8(curatedPuzzles[index + 1])) << 8); 
        
        uint8 rowCol = uint8(curatedPuzzles[index]);

        uint8 row = uint8(rowCol >> 4);
        uint8 col = uint8(rowCol & 0x0F);
        uint8 maxMoves = uint8(curatedPuzzles[index + row * col + 1]);


        bytes memory puzzle = new bytes(row * col);

        for (uint i = 0; i < row * col; i++) {
            puzzle[i] = curatedPuzzles[index + 1 + i];
        }

        puzzles = Puzzle({
            rows: row,
            cols: col,
            maxMoves: maxMoves,
            puzzle: puzzle
        });
    }

    function getFigure(uint8 figure) internal pure returns (int16) {
        uint16 figureIdUint = uint16(figure) >> 5;

        int16 figureId = int16(figureIdUint);

        if (figureId == 7) figureId = -1; // stone

        return figureId;
    }
}