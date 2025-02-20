// SPDX-License-Identifier: FraktalProtocol

pragma solidity ^0.8.24;

import {LibTokenHelper} from "./contracts_FraktalDeFiDAODiamond_facets_TokenHelper_LibTokenHelper.sol";
import {ITokenHelper, TokenInfo} from "./contracts_FraktalDeFiDAODiamond_facets_TokenHelper_ITokenHelper.sol";

contract TokenHelper is ITokenHelper {
    function id() external pure returns (bytes32) {
        return LibTokenHelper.STORAGE_POSITION;
    }

    function getInfo(
        address token
    ) external view returns (TokenInfo memory info) {
        info = LibTokenHelper.getInfo(token);
    }

    function getInfoMulti(
        address[] memory tokens
    ) external view returns (TokenInfo[] memory info) {
        info = LibTokenHelper.getInfoMulti(tokens);
    }
}