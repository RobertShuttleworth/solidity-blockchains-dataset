// SPDX-License-Identifier: SHIFT-1.0
pragma solidity ^0.8.24;

import {Logic} from "./shift-defi_core_contracts_defii_execution_Logic.sol";
import {UniswapV3Callbacks} from "./shitam_defi-product-templates_contracts_UniswapV3Callbacks.sol";

abstract contract SelfManagedLogic is Logic, UniswapV3Callbacks {
    error WrongBuildingBlockId(uint256);

    function enterWithParams(bytes memory params) external payable virtual {
        revert NotImplemented();
    }

    function exitBuildingBlock(
        uint256 buildingBlockId
    ) external payable virtual;

    function allocatedLiquidity(
        address account
    ) public view virtual returns (uint256);

    function exitWithRepay(address lending) external virtual {
        revert NotImplemented();
    }
}