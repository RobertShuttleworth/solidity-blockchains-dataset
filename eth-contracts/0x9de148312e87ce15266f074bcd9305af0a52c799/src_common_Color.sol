// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { Utils } from "./src_common_Utils.sol";

/**
 * @author Eto Vass
 */

library Color {
    struct Hsl {
        int16 hue;
        int16 saturation;
        int16 lightness;
    }
    
    struct Rgb {
        int16 r;
        int16 g;
        int16 b;
    }

    function toString(Hsl memory hsl) internal pure returns (string memory) {
        return string.concat('hsl(', Utils.toString(hsl.hue), ',', Utils.toString(hsl.saturation),'%,',Utils.toString(hsl.lightness),'%)');
    }

    function toStringBuffer(bytes memory buffer, Hsl memory hsl) internal pure {
        Utils.concat(buffer, 'hsl(', bytes(Utils.toString(hsl.hue)), ',', bytes(Utils.toString(hsl.saturation)),'%,',bytes(Utils.toString(hsl.lightness)),'%)');
    }

    function createFromAnother(Hsl memory hsl) internal pure returns (Hsl memory) {
        return Hsl(hsl.hue, hsl.saturation, hsl.lightness);
    }

    function saturate(Hsl memory hsl, int16 n) internal pure returns (Hsl memory result) {
        result = createFromAnother(hsl);
        result.saturation += n;
        normalize(result);
    }

    function desaturate(Hsl memory hsl, int16 n) internal pure returns (Hsl memory result) {
        result = createFromAnother(hsl);
        result.saturation -= n;
        normalize(result);
    }

    function lighter(Hsl memory hsl, int16 n) internal pure returns (Hsl memory result) {
        result = createFromAnother(hsl);
        result.lightness += n;
        normalize(result);
    }

    function darker(Hsl memory hsl, int16 n) internal pure returns (Hsl memory result) {
        result = createFromAnother(hsl);
        result.lightness -= n;
        normalize(result);
    }

    function hueChange(Hsl memory hsl, int16 n) internal pure returns (Hsl memory result) {
        result = createFromAnother(hsl);
        result.hue += n;
        normalize(result);
    }

    function update(Hsl memory hsl, Hsl memory updateValues) internal pure returns (Hsl memory result) { 
        result = createFromAnother(hsl);
        result.hue += updateValues.hue;
        result.saturation += updateValues.saturation;
        result.lightness += updateValues.lightness;
        normalize(result);
    }

    function normalize(Hsl memory hsl) internal pure {
        if (hsl.hue < 0) {
            hsl.hue += 360;
        }

        if (hsl.hue > 360) {
            hsl.hue = hsl.hue % 360;
        }

        if (hsl.saturation > 100) hsl.saturation = 100;
        if (hsl.saturation < 0) hsl.saturation = 0;

        if (hsl.lightness < 0) hsl.lightness = 0;
        if (hsl.lightness > 100) hsl.lightness = 100;
    }

    function lerp(int256 targetFrom, int256 targetTo, int256 currentFrom, int256 currentTo, int current) internal pure returns (int256) { unchecked {
        int256 t = 0;
        int256 divisor = currentTo - currentFrom - 1;
        
        if (divisor > 0) {
            t = (current - currentFrom) * int256(Utils.MULTIPLIER) / (divisor);
        }

        return (targetFrom * int256(Utils.MULTIPLIER) + t * (targetTo - targetFrom)) / Utils.MULTIPLIER;
    }}

    function abs(int i) internal pure returns (int) {
        if (i < 0) return -i;
        return i;
    }

    function rgbToHsl(Rgb memory rgb) internal pure returns (Hsl memory) {
        int r = lerp(0, 100, 0, 255, rgb.r);
        int g = lerp(0, 100, 0, 255, rgb.g);
        int b = lerp(0, 100, 0, 255, rgb.b);

        int max = (r > g && r > b) ? r : (g > b) ? g : b;
        int min = (r < g && r < b) ? r : (g < b) ? g : b;

        int16 h;
        int16 s;
        int16 l;

        l = int16((max + min) / 2);

        int d = max - min;

        if (d == 0) {
            h = 0;
            s = 0;
        } else {
            s = int16(d * 100 / (100 - abs(2 * l - 100)));

            if (max == r) {
                h = int16((60 * ((g - b) / d % 600)));
            } else if (max == g) {
                h = int16(60 * (b - r) / d + 2 * 60);
            } else {
                h = int16(60 * (r - g) / d + 4 * 60);
            }

            if (h < 0) h+= 360;
        }

        return Hsl(h, s, l);
    }
}