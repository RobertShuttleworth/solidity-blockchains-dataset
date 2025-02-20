// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

interface ILiquiDevilLp {
    function mint(address to, uint256 amount) external;

    function burn(uint256 amount) external;

    function burnFrom(address account, uint256 amount) external;

    function totalSupply() external returns (uint256);

    function allowance(address, address) external returns (uint256);
}