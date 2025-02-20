// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

/**
 * @author Eto Vass
 */

import { Utils } from "./src_common_Utils.sol";
import { Division } from "./src_common_Division.sol";

struct Point {
    int256 x;
    int256 y;
}

struct BoundingBox {
    Point p1;
    Point p2;
}

library Lib2D {


    function createBbFromDimensions(int x, int y, int width, int height) internal pure returns (BoundingBox memory) {
        return BoundingBox(Point(x,y), Point(x + width, y+ height));
    }

    function nullBoundingBox() internal pure returns (BoundingBox memory) {
        Point memory p1 = Point(Utils.BIG_NUM, Utils.BIG_NUM);
        Point memory p2 = Point(-Utils.BIG_NUM, -Utils.BIG_NUM);
        return BoundingBox(p1, p2);
    }

    function toString(Point memory p, int256 denominator) internal pure returns (string memory) {
        return string.concat(Division.divisionStr(1, p.x, denominator), ',', Division.divisionStr(1, p.y, denominator));
    }

    function toString(Point memory p) internal pure returns (string memory) {
        return string.concat(Utils.toString(p.x), ',', Utils.toString(p.y));
    }

    function cloneBoundingBox(BoundingBox memory bb) internal pure returns (BoundingBox memory) {
        return BoundingBox(Point(bb.p1.x, bb.p1.y), Point(bb.p2.x, bb.p2.y));
    }

    function updateBoundingBox(BoundingBox memory bb, Point memory pt) internal pure  returns (BoundingBox memory) {
        if (pt.x < bb.p1.x) {
            bb.p1.x = pt.x;
        }
        if (pt.y < bb.p1.y) {
            bb.p1.y = pt.y;
        }

        if (pt.x > bb.p2.x) {
            bb.p2.x = pt.x;
        }
        if (pt.y > bb.p2.y) {
            bb.p2.y = pt.y;
        }

        return bb;
    }

    /**
     *  percentage - from 0 to 1000
     */
    function scaleBoundingBox(BoundingBox memory bb, int256 percentage) internal pure returns (BoundingBox memory) {
        int height = bb.p2.y - bb.p1.y;
        int width = bb.p2.x - bb.p1.x;

        int offset;

        if (height > width) {
            offset = height * percentage / 1000;
        } else {
            offset = width * percentage / 1000;
        }

        bb.p1.x += offset;
        bb.p1.y += offset;
        bb.p2.x -= offset;
        bb.p2.y -= offset;
        return bb;
    }

    function getWidthHeight(BoundingBox memory bb) internal pure returns (int width, int height) {
        width = bb.p2.x - bb.p1.x;
        height = bb.p2.y - bb.p1.y;
    }

    function centerBBoxInBBox(BoundingBox memory outer, BoundingBox memory inner, int desiredMinPadding) internal pure returns (Point memory p, int newWidth, int newHeight) {
        int outerWidth;
        int outerHeight;
        int innerWidth;
        int innerHeight;

        (outerWidth, outerHeight) = getWidthHeight(outer);
        (innerWidth, innerHeight) = getWidthHeight(inner);

        if (innerWidth >= innerHeight) {
            newWidth = outerWidth - desiredMinPadding;
            newHeight = (outerHeight - desiredMinPadding) * innerHeight / innerWidth;
        } else {
            newHeight = outerHeight - desiredMinPadding;
            newWidth = (outerWidth - desiredMinPadding) * innerWidth / innerHeight;
        }

        p = Point(outer.p1.x + (outerWidth - newWidth) / 2, outer.p1.y + (outerHeight - newHeight) / 2);
    }

    /** 
     *  fraction - from 0 to 1000 (respectively - 0 .. 1)
     */
    function moveTowardsFractional(Point memory movingPoint, Point memory targetPoint, int fraction) internal pure returns (Point memory) {
        return Point(
            movingPoint.x + (targetPoint.x - movingPoint.x) * fraction / 1000,
            movingPoint.y + (targetPoint.y - movingPoint.y) * fraction / 1000
        );
    }

    /** 
     *  fraction - from 0 to 10000 (respectively - 0 .. 1)
     */
    function roundPath(bytes memory buffer, Point[] memory path, int fraction1, int fraction2, bool lineInsteadCurve) internal pure returns (BoundingBox memory bb) {
        uint size = path.length;
        bb = Lib2D.nullBoundingBox();

        for (uint256 i=0; i<size; i++) {
            Point memory prevPoint = path[(i + size - 1) % size];
            Point memory curPoint = path[i];
            Point memory nextPoint = path[(i + 1) % size];

            Point memory curveStart = moveTowardsFractional(curPoint, prevPoint, (i % 2 == 0 ? fraction1 : fraction2));
            Point memory curveEnd = moveTowardsFractional(curPoint, nextPoint, (i % 2 == 0 ? fraction1 : fraction2));

            bytes memory cmd = 'L ';
            if (i == 0) cmd = 'M ';

            Utils.concat(buffer, cmd, bytes(Lib2D.toString(curveStart, 0x7fff)));

            if (lineInsteadCurve) {
                Utils.concat(buffer, ' L ', bytes(Lib2D.toString(curveEnd, 0x7fff)));
            } else {
                bb = appendControllPoints(buffer, curPoint, curveStart, curveEnd, bb);
            }

            bb = updateBBoxForRounding(bb, curveStart, curveEnd);
            // bb = updateBBoxForRounding(bb, prevPoint, curPoint);
            // bb = updateBBoxForRounding(bb, curPoint, nextPoint);
        }

        Utils.concat(buffer, ' Z');
    }

    function lerpMid(Point memory A, Point memory B) internal pure returns (Point memory) {
        return Point((A.x + B.x) / 2, (A.y + B.y) / 2);
    }

    function appendControllPoints(bytes memory buffer, Point memory curPoint, Point memory curveStart, Point memory curveEnd, BoundingBox memory bb) private pure returns (BoundingBox memory) {
        Point memory startControl = moveTowardsFractional(curveStart, curPoint, 500);
        Point memory endControl = moveTowardsFractional(curPoint, curveEnd, 500);

        Utils.concat(buffer, ' C ', bytes(Lib2D.toString(startControl, 0x7fff)),' ', bytes(Lib2D.toString(endControl, 0x7fff)), ' ', bytes(Lib2D.toString(curveEnd, 0x7fff)));

        return updateBBoxForBezierMidPoint(bb, curveStart, startControl, endControl, curveEnd);
    }

    function updateBBoxForRounding(BoundingBox memory bb, Point memory curveStart, Point memory curveEnd) internal pure returns (BoundingBox memory) {
        Point memory ptNormalized = Point(curveStart.x / 0x7fff, curveStart.y / 0x7fff);
        bb = updateBoundingBox(bb, ptNormalized);
        ptNormalized = Point(curveEnd.x / 0x7fff, curveEnd.y / 0x7fff);
        bb = updateBoundingBox(bb, ptNormalized);
        return bb;
    }   

    function updateBBoxForBezierMidPoint(BoundingBox memory bb, Point memory start, Point memory cp1, Point memory cp2, Point memory end) internal pure returns (BoundingBox memory) {
        // nice explanation on how to find mid point of Bezier: https://codepen.io/enxaneta/post/how-to-add-a-point-to-an-svg-path 
        
        Point memory p0 = lerpMid(start, cp1);
        Point memory p1 = lerpMid(cp1, cp2);
        Point memory p2 = lerpMid(cp2, end);
        Point memory p3 = lerpMid(p0, p1);
        Point memory p4 = lerpMid(p1, p2);
        Point memory p5 = lerpMid(p3, p4);

        Point memory ptNormalized = Point(p5.x / 0x7fff, p5.y / 0x7fff);
        bb = updateBoundingBox(bb, ptNormalized);
        
        return bb;
    }
}