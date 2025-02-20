// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { Utils } from './src_common_Utils.sol';
import { Division } from './src_common_Division.sol';
import { Color } from './src_common_Color.sol';
import { DynamicBuffer } from './src_common_DynamicBuffer.sol';
import { Svg } from './src_common_SVG.sol';

library Gradients {
    using Utils for int256;
    using Utils for uint256;

    struct ColorStop {
        string color;
        string offset;
        string opacity;
    }

    struct GradientOptions {
        string cx;
        string cy;
        string r;
    }

    function addColorStops(bytes memory buffer, ColorStop[] memory stops) internal pure {
        for (uint256 i=0; i < stops.length; i++) {
            Utils.concat(buffer,'<stop stop-color="', bytes(stops[i].color),
                                    '" offset="', bytes(stops[i].offset),
                                    '" stop-opacity="', bytes(stops[i].opacity),
                                '"/>');
        }
    }

    function createGradient(bytes memory buffer, string memory id, ColorStop[] memory stops, bool linear, string memory grOpt) internal pure {
        if (linear) {
            if (bytes(grOpt).length == 0) {
                Utils.concat(buffer, '<linearGradient ', bytes(Svg.prop("id", id)), 'x1="0" y1="0" x2="0" y2="1">');
            } else {
                Utils.concat(buffer, '<linearGradient ', bytes(Svg.prop("id", id)), bytes(grOpt),'>');
            }
            addColorStops(buffer, stops);
            Utils.concat(buffer, '</linearGradient>');
        } else {            
            Utils.concat(buffer, '<radialGradient ', bytes(Svg.prop("id", id)), bytes(grOpt),'>');
            addColorStops(buffer, stops);
            Utils.concat(buffer, '</radialGradient>');
        }
    }

    function c_d (Color.Hsl memory color) internal pure returns (Color.Hsl memory) {
        color = Color.hueChange(color, 12);
        color = Color.darker(color, 28);
        return color;
    }


    function c_d2 (Color.Hsl memory color) internal pure returns (Color.Hsl memory) {
        color = Color.darker(color, 15);
        return color;
    }

    function c_l3 (Color.Hsl memory color) internal pure returns (Color.Hsl memory) {
        color = Color.lighter(color, 15);
        return color;
    }

    function createFillGradient(bytes memory buffer, string memory id, Color.Hsl memory color) internal pure {
        ColorStop[] memory stops = new ColorStop[](2);
        stops[0] = ColorStop({offset: "0%", color: Color.toString((color)), opacity: "1"});
        stops[1] = ColorStop({offset: "100%", color: Color.toString(c_d(color)) , opacity: "1"});

        createGradient(buffer, string.concat(id, "-fillgr"), stops, false, 'cx="0.5" cy="1.8" r="1.1"');
    }

    function createStrokeGradient(bytes memory buffer, string memory id, Color.Hsl memory color) internal pure {
        ColorStop[] memory stops = new ColorStop[](5);
        stops[0] = ColorStop({offset: "0%", color: Color.toString(Color.update(color, Color.Hsl(0, -4, 7))), opacity: "1"});
        stops[1] = ColorStop({offset: "58%", color: Color.toString(Color.update(color, Color.Hsl(5, -23, -12))), opacity: "1"});
        stops[2] = ColorStop({offset: "74%", color: Color.toString(Color.update(color, Color.Hsl(4, -21, -11))), opacity: "1"});
        stops[3] = ColorStop({offset: "87%", color: Color.toString(Color.update(color, Color.Hsl(3, -15, -7))), opacity: "1"});
        stops[4] = ColorStop({offset: "100%", color: Color.toString(Color.update(color, Color.Hsl(1, 0, -1))), opacity: "1"});
        
        createGradient(buffer, string.concat(id, "-strokegr"), stops, false, 'cx="0.5" cy="0.15" r="1"');
    }

    // function createOverGradient(bytes memory buffer, string memory id, Color.Hsl memory color) internal pure {
    //     ColorStop[] memory stops = new ColorStop[](3);
    //     stops[0] = ColorStop({offset: "0%", color: "white", opacity: "0.1"});
    //     stops[1] = ColorStop({offset: "70%", color: "gray", opacity: "0.1"});
    //     stops[2] = ColorStop({offset: "100%", color: "white", opacity: "0.1"});
        
    //     createGradient(buffer, string.concat(id, "-overgr"), stops, false, 'cx="0.5" cy="-0.5" r="1.3"');
    // }

    function createOverGradient(bytes memory buffer, string memory id, Color.Hsl memory color) internal pure {
        ColorStop[] memory stops = new ColorStop[](3);
        stops[0] = ColorStop({offset: "0%", color: Color.toString(Color.update(color, Color.Hsl(-2, 0, 9))), opacity: "1"});
        stops[1] = ColorStop({offset: "39%", color: Color.toString(Color.update(color, Color.Hsl(2, 0, 4))), opacity: "1"});
        stops[2] = ColorStop({offset: "100%", color: Color.toString(Color.update(color, Color.Hsl(-1, 0, -4))), opacity: "1"});
        
        createGradient(buffer, string.concat(id, "-overgr"), stops, false, 'cx="0.5" cy="-0.5" r="1.3"');
    }

    function createGradient3(bytes memory buffer, string memory id, Color.Hsl memory color) internal pure {
        ColorStop[] memory stops = new ColorStop[](2);
        stops[0] = ColorStop({offset: "0%", color: Color.toString(Color.update(color, Color.Hsl(-4, 0, 3))), opacity: "0.4"});
        stops[1] = ColorStop({offset: "100%", color: Color.toString(Color.update(color, Color.Hsl(-1, 0, 5))), opacity: "0.4"});
        
        createGradient(buffer, string.concat(id, "-gr3"), stops, true, "");
    }

    // function createInnerGradient(bytes memory buffer, string memory id, Color.Hsl memory color) internal pure {
    //     ColorStop[] memory stops = new ColorStop[](2);
    //     stops[0] = ColorStop({offset: "0%", color: Color.toString(Color.update(color, Color.Hsl(0, -20, -30))), opacity: "1"});
    //     stops[1] = ColorStop({offset: "100%", color: Color.toString(Color.update(color, Color.Hsl(0, 0, -43))), opacity: "1"});
        
    //     createGradient(buffer, string.concat(id, "-innergr"), stops, true, '');
    // }

    function createInnerGradient(bytes memory buffer, string memory id, Color.Hsl memory color) internal pure {
        ColorStop[] memory stops = new ColorStop[](2);
        stops[0] = ColorStop({offset: "0%", color: Color.toString(Color.update(color, Color.Hsl(9, 0, -10))), opacity: "1"});
        stops[1] = ColorStop({offset: "100%", color: Color.toString(Color.update(color, Color.Hsl(14, 0, -31))), opacity: "1"});
        
        createGradient(buffer, string.concat(id, "-innergr"), stops, false, 'cx="0.5" cy="2" r="1"');
    }


    function createAllFigureGradients(bytes memory buffer, string memory id, Color.Hsl memory color) internal pure {
        createFillGradient(buffer, id, color);
        createStrokeGradient(buffer, id, color);
        createOverGradient(buffer, id, color);
        createGradient3(buffer, id, color);
        createInnerGradient(buffer, id, color);
    }
}