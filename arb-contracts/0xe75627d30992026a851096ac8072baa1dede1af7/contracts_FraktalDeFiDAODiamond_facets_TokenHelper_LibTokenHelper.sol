// SPDX-License-Identifier: Fraktal-Protocol
//
pragma solidity ^0.8.24;

import {IERC20Meta} from "./contracts_interaces_IERC20.sol";
import {TokenInfo} from "./contracts_FraktalDeFiDAODiamond_facets_TokenHelper_ITokenHelper.sol";

struct TokenHelperStorage {
    string VERSION;
}

library LibTokenHelper {
    bytes32 constant STORAGE_POSITION =
        keccak256("fraktal.protocol.token.helper.storage");

    function diamondStorage()
        internal
        pure
        returns (TokenHelperStorage storage ds)
    {
        bytes32 position = STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    function getInfo(
        address token
    ) internal view returns (TokenInfo memory info) {
        IERC20Meta erc20 = IERC20Meta(token);
        info.name = erc20.name();
        info.token = token;
        info.symbol = erc20.symbol();
        info.decimals = erc20.decimals();
        info.totalSupply = erc20.totalSupply();
    }

    function getInfoMulti(
        address[] memory tokens
    ) internal view returns (TokenInfo[] memory info) {
        uint len = tokens.length;
        uint i = 0;
        info = new TokenInfo[](len);
        for (i; i < len; i++) {
            info[i] = getInfo(tokens[i]);
        }
    }
}