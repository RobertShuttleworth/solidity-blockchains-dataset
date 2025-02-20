// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "./openzeppelin_contracts_interfaces_IERC721.sol";

interface IERC721Mintable is IERC721 {
    function boxMint(address to) external;
}