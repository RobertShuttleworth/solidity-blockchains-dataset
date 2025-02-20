// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { Utils } from './src_common_Utils.sol';
import { DynamicBuffer } from './src_common_DynamicBuffer.sol';
import { AssetsCreator } from './src_game-renderer_AssetsCreator.sol';
import { AssetsRenderer } from './src_game-renderer_AssetsRenderer.sol';
import { ITokenMetadataManager, TokenMetadata } from './src_interfaces_ITokenMetadataManager.sol';
import { IAssetsSSTORE2 } from './src_interfaces_IAssetsSSTORE2.sol';
import { RandomCtx, Random } from './src_common_Random.sol';
import { TraitsCtx } from './src_common_TraitsCtx.sol';
import { Traits } from './src_common_Traits.sol';
import { Puzzle, PuzzleDecoder } from './src_curated_PuzzleDecoder.sol';
import { IPathsManager } from './src_interfaces_IPathsManager.sol';
import { IGameRenderer } from './src_interfaces_IGameRenderer.sol';

/**
 * @author Eto Vass
 */


contract GameRenderer is IGameRenderer {
    ITokenMetadataManager private tokenMetadataManager;
    IAssetsSSTORE2 private assetsSSTORE2;
    IPathsManager private pathsManager;

    constructor(ITokenMetadataManager _tokenMetadataManager, IAssetsSSTORE2 _assetsSSTORE2, IPathsManager _pathsManager) {
        tokenMetadataManager = _tokenMetadataManager;
        assetsSSTORE2 = _assetsSSTORE2;
        pathsManager = _pathsManager;
    }

    function tokenURI(uint tokenId) public view returns (string memory) {
        (string memory svg, string memory assets, Puzzle memory curatedPuzzle, TraitsCtx memory traitsCtx) = tokenImageInternal(tokenId);
        string memory attributes = getTraitsAsJson(traitsCtx);
        string memory html = tokenHTMLInternal(assets, curatedPuzzle, tokenId);

        string memory json = string.concat(
            '{"name":"FOCM3 #',
            string(Utils.toString(tokenId)),
            '","description":"FOCM3 - a fully on-chain puzzle game by @EtoVass",',
            attributes,',',
            '"image":"data:image/svg+xml;base64,',
            Utils.encode(bytes(svg)),
            '","animation_url":"data:text/html;base64,',
            Utils.encode(bytes(html)),
            '"}'
        );

        return
            string.concat(
                "data:application/json;base64,",
                Utils.encode(bytes(json))
            );    
    }

    function tokenHTML(uint tokenId) public view returns (string memory) {
        (, string memory assets, Puzzle memory curatedPuzzle,) = tokenImageInternal(tokenId);
        return tokenHTMLInternal(assets, curatedPuzzle, tokenId);
    }

    function tokenImage(uint tokenId) public view returns (string memory) {
        (string memory svg,,,) = tokenImageInternal(tokenId);
        return svg;
    }


    function tokenTraits(uint tokenId) public view returns (string memory) {
        (,,,TraitsCtx memory traitsCtx) = tokenImageInternal(tokenId);
        return getTraitsAsJson(traitsCtx);
    }

    function getTraitsAsJson(TraitsCtx memory traitsCtx) private pure returns (string memory) {
        return string.concat(
            '"attributes":[', 
                Traits.getTraitsAsJson(traitsCtx), 
            ']'
        );
    }

    function tokenImageInternal(uint256 tokenId) private view returns (string memory, string memory, Puzzle memory, TraitsCtx memory) {
        TokenMetadata memory metadata = tokenMetadataManager.getTokenMetadata(tokenId);

        RandomCtx memory rndCtx = Random.initCtx(metadata.seed);

        TraitsCtx memory traitsCtx = Traits.generateTraitsCtx(rndCtx);

        bytes memory curatedPuzzles = assetsSSTORE2.loadAsset("curated-puzzles");
        
        Puzzle memory curatedPuzzle = PuzzleDecoder.decodePuzzle(curatedPuzzles, metadata.curatedId);

        traitsCtx.puzzleData.rows = curatedPuzzle.rows;
        traitsCtx.puzzleData.cols = curatedPuzzle.cols;

        string memory assets = AssetsCreator.getSvgSymbols(rndCtx, traitsCtx, pathsManager);
        
        bytes memory buffer1 = DynamicBuffer.allocate(100000);
        AssetsRenderer.tokenImage(buffer1, traitsCtx, assets, curatedPuzzle);

        return (string(buffer1), assets, curatedPuzzle, traitsCtx);
    }



    function tokenHTMLInternal(string memory assets, Puzzle memory curatedPuzzle, uint256 tokenId) public view returns (string memory) {
        bytes memory buffer = DynamicBuffer.allocate(100000);

        uint partsCount = abi.decode(assetsSSTORE2.loadAsset("parts", false), (uint));

        for (uint i = 0; i < partsCount; i++) {
            bytes memory part = assetsSSTORE2.loadAsset(string.concat("part-", Utils.toString(i)), true);
            Utils.concat(buffer, part);

            // add injected elements after first block
            if (i == 0) {
                Utils.concat(buffer, "var focm3_injected = {");
                Utils.concat(buffer, '"assets":"', bytes(Utils.encode(bytes(assets))), '",');
                Utils.concat(buffer, '"rows":', bytes(Utils.toString(curatedPuzzle.rows)), ',');
                Utils.concat(buffer, '"cols":', bytes(Utils.toString(curatedPuzzle.cols)), ',');
                Utils.concat(buffer, '"maxMoves":', bytes(Utils.toString(curatedPuzzle.maxMoves)), ',');
                Utils.concat(buffer, '"tokenId":', bytes(Utils.toString(tokenId)), ',');
                Utils.concat(buffer, '"puzzle":"', bytes(Utils.encode(bytes(curatedPuzzle.puzzle))), '"');
                Utils.concat(buffer, "};");

            }
        }

        return string(buffer);
    }

}