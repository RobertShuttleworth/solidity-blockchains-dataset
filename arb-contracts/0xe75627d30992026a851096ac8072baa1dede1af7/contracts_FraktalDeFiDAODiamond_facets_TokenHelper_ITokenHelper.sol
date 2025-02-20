// SPDX-License-Identifier: FRAKTAL-PROTOCOL

pragma solidity >=0.8.24;

struct TokenInfo {
    string name;
    string symbol;
    address token;
    uint8 decimals;
    uint totalSupply;
}

interface ITokenHelper {
    function getInfo(
        address token
    ) external view returns (TokenInfo memory info);

    function getInfoMulti(
        address[] memory tokens
    ) external view returns (TokenInfo[] memory info);
}