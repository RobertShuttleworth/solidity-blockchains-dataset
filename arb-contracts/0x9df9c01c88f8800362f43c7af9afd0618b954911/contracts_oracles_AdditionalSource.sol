// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.24;

import {ERC20} from "./lib_solmate_src_tokens_ERC20.sol";
import {UniversalOracle} from "./contracts_oracles_UniversalOracle.sol";
import {Math} from "./contracts_utils_Math.sol";

abstract contract AdditionalSource {
    error AdditionalSource__UniversalOracle();

    modifier onlyUniversalOracle() {
        if (msg.sender != address(universalOracle))
            revert AdditionalSource__UniversalOracle();
        _;
    }

    UniversalOracle public immutable universalOracle;

    constructor(UniversalOracle _universalOracle) {
        universalOracle = _universalOracle;
    }

    function setupSource(ERC20 asset, bytes memory sourceData) external virtual;

    function getPriceInUSD(ERC20 asset) external view virtual returns (uint256);
}