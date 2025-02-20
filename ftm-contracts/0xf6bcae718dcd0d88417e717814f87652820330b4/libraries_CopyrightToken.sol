// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

contract CopyrightToken {
    string private constant _GENERATOR = "https://tokentoolbox.app";
    /**
     * @dev Returns the token generator tool.
     */
    function generator() public pure returns (string memory) {
        return _GENERATOR;
    }
}