// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { SSTORE2 } from "./src_sstore2_SSTORE2.sol";
import { LibZip } from "./src_sstore2_LibZip.sol";
import { IAssetsSSTORE2 } from "./src_interfaces_IAssetsSSTORE2.sol";

import "./node_modules_openzeppelin_contracts_access_Ownable.sol";

struct FS {
    mapping (string name => address) assets;
}

contract AssetsSSTORE2 is Ownable, IAssetsSSTORE2 {
    FS private fs;

    constructor() Ownable(msg.sender) {}

    function addAsset(string memory key, bytes memory asset) external onlyOwner {
        fs.assets[key] = SSTORE2.write(asset);
    }
    /*
        Loads the asset and decompress it.
    */
    function loadAsset(string memory key) external view returns (bytes memory) {
        return loadAssetInternal(key, true);
    }

    /*
        Loads the asset and optionally decompress it.
    */
    function loadAsset(string memory key, bool decompress) external view returns (bytes memory) {
        return loadAssetInternal(key, decompress);
    }

    function loadAssetInternal(string memory key, bool decompress) internal view returns (bytes memory) {
        bytes memory asset = SSTORE2.read(fs.assets[key]);
        
        if (decompress) {
            return LibZip.flzDecompress(asset);
        }
        return asset;
    }
}