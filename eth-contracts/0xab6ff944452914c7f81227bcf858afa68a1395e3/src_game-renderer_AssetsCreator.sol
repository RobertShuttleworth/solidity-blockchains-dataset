// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { Utils } from './src_common_Utils.sol';
import { Random, RandomCtx } from './src_common_Random.sol';
import { Division } from './src_common_Division.sol';
import { Svg } from './src_common_SVG.sol';
import { Gradients } from './src_game-renderer_Gradients.sol';
import { FigureGenerator } from './src_game-renderer_FigureGenerator.sol';
import { DynamicBuffer } from './src_common_DynamicBuffer.sol';
import { TraitsCtx } from './src_common_TraitsCtx.sol';
import { IPathsManager } from './src_interfaces_IPathsManager.sol';

/**
 * @author Eto Vass
 */


library AssetsCreator {
    function getSvgSymbols(RandomCtx memory rndCtx, TraitsCtx memory traitsCtx, IPathsManager pathsManager) internal view returns (string memory) {
        bytes memory buffer = DynamicBuffer.allocate(100000);
        
        FigureGenerator.createFigures(buffer, rndCtx, traitsCtx, pathsManager);

        //string memory s = string(GameGenerated.JS);

        return string(buffer);
    }
}