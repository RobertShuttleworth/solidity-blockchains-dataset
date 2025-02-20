// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

/**
 * @author Eto Vass
 */

import { Lib2D, Point, BoundingBox } from './src_common_Lib2D.sol';
import { FigureCollection } from './src_common_VisualTraits.sol';
import { Color } from './src_common_Color.sol';
import { DynamicBuffer } from './src_common_DynamicBuffer.sol';
import { Utils } from './src_common_Utils.sol';
import { Trigonometry } from './src_figures_Trigonometry.sol';
import { Random, RandomCtx } from './src_common_Random.sol';
import { Figures_GENERATED } from './src_figures_Figures_GENERATED.sol';
import { IAssetsSSTORE2 } from './src_interfaces_IAssetsSSTORE2.sol';
import { IPathsManager, Figure } from './src_interfaces_IPathsManager.sol';

struct OutlineCtx {
    int cx;
    int cy;
    uint numSides;
    uint size;
    uint roundRadius;
    uint startAngle;
    bool isStar;
}


library FiguresPathLib {
    int constant CENTER_X = 1000;
    int constant CENTER_Y = 1000;
    uint constant SIZE = 1000;
    uint constant ROUND_RADIUS = 100;

    // function getFailureFigure() internal pure returns (string memory path, Lib2D.BoundingBox memory bbox) {
    //     path = '<path d="M528 576 656 704 720 640 592 512 720 384 656 320 528 448 400 320 336 384 464 512 336 640 400 704 528 576Z"/>';
    //     bbox = Lib2D.createBbFromDimensions(336,320,384,384);
    // }

    // function getBitcoinFigure() internal pure returns (string memory path, Lib2D.BoundingBox memory bbox) {
    //     path = '<path d="M217.021 167.042c18.631-9.483 30.288-26.184 27.565-54.007-3.667-38.023-36.526-50.773-78.006-54.404l-.008-52.741h-32.139l-.009 51.354c-8.456 0-17.076.166-25.657.338L108.76 5.897l-32.11-.003-.006 52.728c-6.959.142-13.793.277-20.466.277v-.156l-44.33-.018.006 34.282c0 0 23.734-.446 23.343-.013 13.013.009 17.262 7.559 18.484 14.076l.01 60.083v84.397c-.573 4.09-2.984 10.625-12.083 10.637.414.364-23.379-.004-23.379-.004l-6.375 38.335h41.817c7.792.009 15.448.13 22.959.19l.028 53.338 32.102.009-.009-52.779c8.832.18 17.357.258 25.684.247l-.009 52.532h32.138l.018-53.249c54.022-3.1 91.842-16.697 96.544-67.385C266.916 192.612 247.692 174.396 217.021 167.042zM109.535 95.321c18.126 0 75.132-5.767 75.14 32.064-.008 36.269-56.996 32.032-75.14 32.032V95.321zM109.521 262.447l.014-70.672c21.778-.006 90.085-6.261 90.094 35.32C199.638 266.971 131.313 262.431 109.521 262.447z">';
    //     bbox = Lib2D.createBbFromDimensions(12, 6, 250, 348);
    // }

    // function getEthFigure() internal pure returns (string memory path, Lib2D.BoundingBox memory bbox) {
    //     path = '<path d="M311.9 260.8L160 353.6 8 260.8 160 0l151.9 260.8zM160 383.4L8 290.6 160 512l152-221.4-152 92.8z"/>';
    //     bbox = Lib2D.createBbFromDimensions(0, 0, 320, 512);
    // }

    function outlineArray(int cx, int cy, uint numSides, uint size, uint startAngle) private pure returns (Point[] memory result, BoundingBox memory bb) {
        result = new Point[](numSides);
        bb = Lib2D.nullBoundingBox();

        uint angleStep = 0x4000 / numSides;
        uint currentAngle = startAngle * 0x4000 / 360;

        for (uint i=0; i < numSides; i++) {
            int sx = cx * 0x7fff + Trigonometry.sin(currentAngle) * int(size);
            int sy = cy * 0x7fff - Trigonometry.cos(currentAngle) * int(size);

            currentAngle += angleStep;
            if (currentAngle > 0x4000) {
                currentAngle = currentAngle % 0x4000;
            }

            result[i] = Point(sx, sy);

            Point memory ptNormalized = Point(sx / 0x7fff, sy / 0x7fff);

            bb = Lib2D.updateBoundingBox(bb, ptNormalized);
        }
    }

    function outlineStarArray(int cx, int cy, uint numSides, uint sizeInner, uint sizeOuter, uint startAngle) private pure returns (Point[] memory result, BoundingBox memory bb) {
        numSides = numSides * 2;

        result = new Point[](numSides);
        bb = Lib2D.nullBoundingBox();

        uint angleStep = 0x4000 / numSides;
        uint currentAngle = startAngle * 0x4000 / 360;

        for (uint i=0; i < numSides; i++) {
            uint size = (i % 2 == 0 ? sizeOuter : sizeInner);

            int sx = cx * 0x7fff + Trigonometry.sin(currentAngle) * int(size);
            int sy = cy * 0x7fff - Trigonometry.cos(currentAngle) * int(size);

            currentAngle += angleStep;
            if (currentAngle > 0x4000) {
                currentAngle = currentAngle % 0x4000;
            }

            result[i] = Point(sx, sy);

            Point memory ptNormalized = Point(sx / 0x7fff, sy / 0x7fff);

            bb = Lib2D.updateBoundingBox(bb, ptNormalized);
        }
    }


    function outline(bytes memory outlineBuffer, OutlineCtx memory octx, bytes memory id) internal pure returns (string memory pathStr, BoundingBox memory bb) {
        DynamicBuffer.resetBuffer(outlineBuffer);

        Point[] memory path;       

        if (octx.numSides >= 3) { 
            if (octx.isStar) {
                (path, bb) = outlineStarArray(octx.cx, octx.cy, octx.numSides, octx.size/3, octx.size, octx.startAngle);
            } else {
                (path, bb) = outlineArray(octx.cx, octx.cy, octx.numSides, octx.size, octx.startAngle);
            }
            
            Utils.concat(outlineBuffer, '<path id="', id, '" d="');
            bb = Lib2D.roundPath(outlineBuffer, path, int(octx.roundRadius), int(octx.roundRadius), false);
            Utils.concat(outlineBuffer, '" />');
        } else {
            // default is circle
            bb = BoundingBox(Point(octx.cx - int(octx.size), octx.cy - int(octx.size)), Point(octx.cx + int(octx.size), octx.cy + int(octx.size)));
            Utils.concat(outlineBuffer, '<circle id="', id, '" cx="', bytes(Utils.toString(octx.cx)), '" cy="', bytes(Utils.toString(octx.cy)),
                '" r="', bytes(Utils.toString(octx.size)),'" />');
        }

        pathStr = string(outlineBuffer);
    }

    function ngoneFigures(RandomCtx memory rndCtx, uint numFigures, uint numSides, uint rotation) internal pure returns (Figure[] memory figures) {
        figures = new Figure[](numFigures);        
        Figure memory figure = ngoneSingleFigure(rndCtx, numSides, rotation, "path-1");

        for (uint i=0; i < numFigures; i++) {
            figures[i] = figure;
        }

        return figures;
    }

    function ngoneSingleFigure(RandomCtx memory rndCtx, uint numSides, uint rotation, bytes memory id) internal pure returns (Figure memory figure) {
        bytes memory outlineBuffer = DynamicBuffer.allocate(5000);
        OutlineCtx memory octx = OutlineCtx(CENTER_X, CENTER_Y, numSides, SIZE, ROUND_RADIUS, rotation, false);   
        (figure.svgPath, figure.bbox) = outline(outlineBuffer, octx, id);
        figure.id = id;

        // if (numSides % 2 == 0) {
        //     figure.bbox = Lib2D.scaleBoundingBox(figure.bbox, -55);
        // } else if (numSides == 5) {
        //     figure.bbox = Lib2D.scaleBoundingBox(figure.bbox, -35);
        // }

        figure.bbox = Lib2D.scaleBoundingBox(figure.bbox, -25);

        if (numSides == 3) { 
            if (rotation == 0) {
                figure.offsetY = -100;
            } else {
                figure.offsetY = 100;
            }
            figure.padding = 100;
        }

        if (numSides == 2) {
            figure.padding = 100;
        }

        if (numSides == 4) {
            if (rotation != 0) {
                figure.padding = 200;
            }
        }
    }

    function starSingleFigure(RandomCtx memory rndCtx, uint numSides, uint rotation, bytes memory id) internal pure returns (Figure memory figure) {
        bytes memory outlineBuffer = DynamicBuffer.allocate(5000);
        OutlineCtx memory octx = OutlineCtx(CENTER_X, CENTER_Y, numSides, SIZE, ROUND_RADIUS, rotation, true);   
        (figure.svgPath, figure.bbox) = outline(outlineBuffer, octx, id);
        figure.id = id;
        // if (numSides % 2 == 0) {
        //     figure.bbox = Lib2D.scaleBoundingBox(figure.bbox, -55);
        // } else if (numSides == 5) {
        //     figure.bbox = Lib2D.scaleBoundingBox(figure.bbox, -35);
        // }

        figure.bbox = Lib2D.scaleBoundingBox(figure.bbox, -25);

        if (numSides == 3) { 
            if (rotation == 0) {
                figure.offsetY = -100;
            } else {
                figure.offsetY = 100;
            }
            figure.padding = 100;
        }

        if (numSides == 2) {
            figure.padding = 100;
        }

        if (numSides == 4) {
            if (rotation != 0) {
                figure.padding = 200;
            }
        }
    }

    function randomSelectN(RandomCtx memory rndCtx, Figure[] memory figs, uint numFigures) internal pure returns (Figure[] memory result) {
        result = new Figure[](numFigures);

        int8[] memory indices = Random.randomArray(rndCtx, int8(0), int8(int(figs.length) - 1));

        for (uint i=0; i < numFigures; i++) {
            result[i] = figs[uint(int( indices[i]))];
        }
    }

    function pathFigures(uint numFigures, string memory path, BoundingBox memory bbox, int percentIncrease) internal pure returns (Figure[] memory figures) {
        Figure memory fig = singlePathFigure(path, bbox, "path-1");
        
        figures = new Figure[](numFigures);
        for (uint i=0; i < numFigures; i++) {
            figures[i] = fig;
            figures[i].percentIncrease = percentIncrease;
        }
        return figures;
    }

    function singlePathFigure(string memory path, BoundingBox memory bbox, bytes memory id) internal pure returns (Figure memory figure) {
        figure = Figure(string.concat('<path id="', string(id), '" d="', path, '" />'), bbox, 0, 0, id, 0);

        figure.bbox = Lib2D.scaleBoundingBox(figure.bbox, -50);
    }

    function getStoneFigure(IAssetsSSTORE2 as2) internal view returns (Figure memory figure) {
        (bytes memory bytesPath, BoundingBox memory bbox) = Figures_GENERATED.load_path_failure(as2);
        return singlePathFigure(string(bytesPath), bbox, "path--1");
    }

    function getFigureCollection(RandomCtx memory rndCtx, FigureCollection collection, uint numFigures, IAssetsSSTORE2 as2) internal view returns (Figure[] memory figures, bool areDifferent) {
        bytes memory bytesPath;
        BoundingBox memory bbox;
        

        if (collection == FigureCollection.CIRCLE) {
            return (ngoneFigures(rndCtx, numFigures, 2, 0), false);
        } else if (collection == FigureCollection.TRIANGLE) {
            return (ngoneFigures(rndCtx, numFigures, 3, [0, 60][uint(Random.randRange(rndCtx, 0, 1))]), false);
        } else if (collection == FigureCollection.SQUARE) {
            return (ngoneFigures(rndCtx, numFigures, 4, [0, 45][uint(Random.randRange(rndCtx, 0, 1))]), false);
        } else if (collection == FigureCollection.PENTAGON) {
            return (ngoneFigures(rndCtx, numFigures, 5, [0, 180][uint(Random.randRange(rndCtx, 0, 1))]), false);
        } else if (collection == FigureCollection.HEXAGON) {
            return (ngoneFigures(rndCtx, numFigures, 6, [0, 30][uint(Random.randRange(rndCtx, 0, 1))]), false);
        } else if (collection == FigureCollection.BULL) {
            (bytesPath, bbox) = Figures_GENERATED.load_path_bull(as2);
            return (pathFigures(numFigures, string(bytesPath), bbox, 10), false);
        } else if (collection == FigureCollection.SKULL) {
            (bytesPath, bbox) = Figures_GENERATED.load_path_skull(as2);
            return (pathFigures(numFigures, string(bytesPath), bbox, 0), false);
        } else if (collection == FigureCollection.CAT) {
            (bytesPath, bbox) = Figures_GENERATED.load_path_cat(as2);
            return (pathFigures(numFigures, string(bytesPath), bbox, 7), false);
        } else if (collection == FigureCollection.CHAIN) {
            (bytesPath, bbox) = Figures_GENERATED.load_path_chain(as2);
            return (pathFigures(numFigures, string(bytesPath), bbox, 0), false);
        } else if (collection == FigureCollection.ETH) {
            (bytesPath, bbox) = Figures_GENERATED.load_path_eth(as2);
            return (pathFigures(numFigures, string(bytesPath), bbox, 0), false);
        } else if (collection == FigureCollection.BTC) {
            (bytesPath, bbox) = Figures_GENERATED.load_path_bitcoin(as2);
            return (pathFigures(numFigures, string(bytesPath), bbox, 0), false);
        } else if (collection == FigureCollection.SNOWFLAKE) {
            (bytesPath, bbox) = Figures_GENERATED.load_path_snowflake(as2);
            return (pathFigures(numFigures, string(bytesPath), bbox, 0), false);       
        } else if (collection == FigureCollection.GEOMETRY) {            
            Figure[] memory figs = new Figure[](7);
            figs[0] = ngoneSingleFigure(rndCtx, 2, 0, "path-1");
            figs[1] = ngoneSingleFigure(rndCtx, 3, 0, "path-2");
            figs[2] = ngoneSingleFigure(rndCtx, 3, 60, "path-3");
            figs[3] = ngoneSingleFigure(rndCtx, 4, 0, "path-4");
            figs[4] = ngoneSingleFigure(rndCtx, 4, 45, "path-5");
            figs[5] = ngoneSingleFigure(rndCtx, 5, [0, 180][uint(Random.randRange(rndCtx, 0, 1))], "path-6");
            figs[6] = ngoneSingleFigure(rndCtx, 6, [0, 30][uint(Random.randRange(rndCtx, 0, 1))], "path-7");

            return (randomSelectN(rndCtx, figs, numFigures), true);
        } else if (collection == FigureCollection.STARS) {
            Figure[] memory figs = new Figure[](7);
            figs[0] = starSingleFigure(rndCtx, 3, 0, "path-1");
            figs[1] = starSingleFigure(rndCtx, 3, 180, "path-2");
            figs[2] = starSingleFigure(rndCtx, 4, 0, "path-3");
            figs[3] = starSingleFigure(rndCtx, 4, 45, "path-4");
            figs[4] = starSingleFigure(rndCtx, 5, 0, "path-5");
            figs[5] = starSingleFigure(rndCtx, 6, 0, "path-6");
            figs[6] = starSingleFigure(rndCtx, 8, 0, "path-7");

            return (randomSelectN(rndCtx, figs, numFigures), true);
        } else if (collection == FigureCollection.CRYPTO) {
            Figure[] memory figs = new Figure[](9);

            (bytesPath, bbox) = Figures_GENERATED.load_path_bitcoin(as2);  
            figs[0] = singlePathFigure(string(bytesPath), bbox, "path-1");

            (bytesPath, bbox) = Figures_GENERATED.load_path_eth(as2);    
            figs[1] = singlePathFigure(string(bytesPath), bbox, "path-2");

            (bytesPath, bbox) = Figures_GENERATED.load_path_solana(as2);
            figs[2] = singlePathFigure(string(bytesPath), bbox, "path-3");

            (bytesPath, bbox) = Figures_GENERATED.load_path_chainlink(as2);
            figs[3] = singlePathFigure(string(bytesPath), bbox, "path-4");

            (bytesPath, bbox) = Figures_GENERATED.load_path_tezos(as2);
            figs[4] = singlePathFigure(string(bytesPath), bbox, "path-5");

            (bytesPath, bbox) = Figures_GENERATED.load_path_polygon(as2);
            figs[5] = singlePathFigure(string(bytesPath), bbox, "path-6");

            (bytesPath, bbox) = Figures_GENERATED.load_path_base(as2);
            figs[6] = singlePathFigure(string(bytesPath), bbox, "path-7");

            (bytesPath, bbox) = Figures_GENERATED.load_path_apechain(as2);
            figs[7] = singlePathFigure(string(bytesPath), bbox, "path-8");

            (bytesPath, bbox) = Figures_GENERATED.load_path_optimism(as2);
            figs[8] = singlePathFigure(string(bytesPath), bbox, "path-9");

            return (randomSelectN(rndCtx, figs, numFigures), true);
        }
    }
}
