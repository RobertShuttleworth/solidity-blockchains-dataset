// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./openzeppelin_contracts_token_ERC1155_IERC1155.sol";

interface IHenkaku1155Mint is IERC1155 {
    function mint(address _to) external;
}