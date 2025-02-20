//SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { Color } from './src_common_Color.sol';
import { Random, RandomCtx } from './src_common_Random.sol';

library Palettes {
    function mapWithAvoid(int16 avoidMin, int16 avoidMax, int16 value) internal pure returns (int16) {
        if (value <= avoidMin) {
            return value;
        }

        return (value - avoidMin) + avoidMax;
    }


    function getPalette(RandomCtx memory rndCtx, uint numColors) internal pure returns (Color.Hsl[] memory colors) {
        colors = new Color.Hsl[](numColors);

        int16 startingHue = int16(Random.randRange(rndCtx, 0, 360));
        int16 startingSaturation = int16(Random.randRange(rndCtx, 55, 80));
        int16 startingLightness = int16(Random.randRange(rndCtx, 55, 75));
        int16 hStep = 50;//int16(Random.randRange(rndCtx, 60, int(360/numColors)));

        //bool randomHStep = Random.randBool(rndCtx, 50);
        bool randomSaturation = Random.randBool(rndCtx, 20);
        bool randomLightness = Random.randBool(rndCtx, 20);

        int16 shiftedMax = 300;

        for (uint i = 0; i < numColors; i++) {
            if (randomSaturation) {
                startingSaturation = int16(Random.randRange(rndCtx, 55, 80));    
            }

            if (randomLightness) {
                startingLightness = int16(Random.randRange(rndCtx, 55, 70));
            }

            colors[i] = Color.Hsl(mapWithAvoid(100, 160, startingHue), startingSaturation, startingLightness);

            // if (randomHStep) {
            //     hStep = int16(Random.randRange(rndCtx, 60, int(360/numColors)));
            // }
            startingHue += hStep;
            startingHue %= shiftedMax;
        }

        colors = shufflePalette(colors, rndCtx);
    
        return colors;
    }

    function shufflePalette(Color.Hsl[] memory palette, RandomCtx memory rndCtx ) internal pure returns (Color.Hsl[] memory result) {
        result = new Color.Hsl[](palette.length);

        int8[] memory indices = Random.randomArray(rndCtx, int8(0), int8(int(palette.length) - 1));

        for (uint i=0; i < palette.length; i++) {
            result[i] = palette[uint(int( indices[i]))];
        }

        return result;
    }
}