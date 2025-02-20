// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

/**
 * @author Eto Vass
 */

struct RandomCtx {
    uint256 seed;
    uint256 counter;
}

library Random {
    function initCtx(uint startingSeed) internal pure returns (RandomCtx memory) {
        return RandomCtx(startingSeed, 1);      
    }

    function randInt(RandomCtx memory ctx) internal pure returns (uint256) {
        ctx.counter++;

        ctx.seed = uint(keccak256(
            abi.encode(
                ctx.seed, ctx.counter
            )
        ));
        
        return ctx.seed;
    }
    
    function randRange(RandomCtx memory ctx, int from, int to) internal pure returns (int256) { unchecked {
        if (from > to) {
            to = from;
        }
        uint rnd = randInt(ctx);

        return from + int(rnd >> 1) % (to - from + 1);
    }}

    /**
     * 
     * @param ctx - context
     * @param trueProbability - 0 to 100 percents
     */
    function randBool(RandomCtx memory ctx, int256 trueProbability) internal pure returns (bool) {
        return (randRange(ctx, 1, 100) <= trueProbability);
    }

    function randomArray(RandomCtx memory ctx, int8 from, int8 to) internal pure returns (int8[] memory result) {
        uint8 len = uint8(to - from + 1);
        result = new int8[](len);

        for (int8 i = from; i <= to; i++) {
            result[uint8(i - from)] = i;
        }

        for (uint8 i = 0; i < len; i++) {
            uint8 n = uint8(int8(randRange(ctx, 0, int(uint(len-1)))));

            int8 tmp = result[n];
            result[n] = result[i];
            result[i] = tmp;
        }
    }

    function randWithProbabilities(RandomCtx memory ctx, uint16[] memory probabilities) internal pure returns (uint8) { unchecked {
        uint probSum = 0;

        for (uint8 i = 0; i < probabilities.length; i++) {
            probSum += uint(probabilities[i]);
        }

        int rnd = Random.randRange(ctx, 1, int(probSum));

        probSum = 0;
        for (uint8 i = 0; i < probabilities.length; i++) {
            probSum += uint(probabilities[i]);

            if (int(probSum) >= rnd) {
                return i;
            }
        }

        return 0;
    }}

    function probabilityArray(uint16 a0, uint16 a1) internal pure returns (uint16[] memory) {
        uint16[] memory result = new uint16[](2);
        result[0] = a0;
        result[1] = a1;
        return result;    
    } 

    function probabilityArray(uint16 a0, uint16 a1, uint16 a2) internal pure returns (uint16[] memory) {
        uint16[] memory result = new uint16[](3);
        result[0] = a0;
        result[1] = a1;
        result[2] = a2;
        return result;    
    } 

    function probabilityArray(uint16 a0, uint16 a1, uint16 a2, uint16 a3) internal pure returns (uint16[] memory) {
        uint16[] memory result = new uint16[](4);
        result[0] = a0;
        result[1] = a1;
        result[2] = a2;
        result[3] = a3;
        return result;    
    } 

    function probabilityArray(uint16 a0, uint16 a1, uint16 a2, uint16 a3, uint16 a4) internal pure returns (uint16[] memory) {
        uint16[] memory result = new uint16[](5);
        result[0] = a0;
        result[1] = a1;
        result[2] = a2;
        result[3] = a3;
        result[4] = a4;
        return result;    
    }

    function probabilityArray(uint16 a0, uint16 a1, uint16 a2, uint16 a3, uint16 a4, uint16 a5) internal pure returns (uint16[] memory) {
        uint16[] memory result = new uint16[](6);
        result[0] = a0;
        result[1] = a1;
        result[2] = a2;
        result[3] = a3;
        result[4] = a4;
        result[5] = a5;
        return result;    
    }

    function probabilityArray(uint16 a0, uint16 a1, uint16 a2, uint16 a3, uint16 a4, uint16 a5, uint16 a6) internal pure returns (uint16[] memory) {
        uint16[] memory result = new uint16[](7);
        result[0] = a0;
        result[1] = a1;
        result[2] = a2;
        result[3] = a3;
        result[4] = a4;
        result[5] = a5;
        result[6] = a6;
        return result;    
    }

    function probabilityArray(uint16 a0, uint16 a1, uint16 a2, uint16 a3, uint16 a4, uint16 a5, uint16 a6, uint16 a7) internal pure returns (uint16[] memory) {
        uint16[] memory result = new uint16[](8);
        result[0] = a0;
        result[1] = a1;
        result[2] = a2;
        result[3] = a3;
        result[4] = a4;
        result[5] = a5;
        result[6] = a6;
        result[7] = a7;
        return result;    
    }

    function probabilityArray(uint16 a0, uint16 a1, uint16 a2, uint16 a3, uint16 a4, uint16 a5, uint16 a6, uint16 a7, uint16 a8) internal pure returns (uint16[] memory) {
        uint16[] memory result = new uint16[](9);
        result[0] = a0;
        result[1] = a1;
        result[2] = a2;
        result[3] = a3;
        result[4] = a4;
        result[5] = a5;
        result[6] = a6;
        result[7] = a7;
        result[8] = a8;
        return result;    
    }

    function probabilityArray(uint16 a0, uint16 a1, uint16 a2, uint16 a3, uint16 a4, uint16 a5, uint16 a6, uint16 a7, uint16 a8, uint16 a9) internal pure returns (uint16[] memory) {
        uint16[] memory result = new uint16[](10);
        result[0] = a0;
        result[1] = a1;
        result[2] = a2;
        result[3] = a3;
        result[4] = a4;
        result[5] = a5;
        result[6] = a6;
        result[7] = a7;
        result[8] = a8;
        result[9] = a9;
        return result;    
    }
}