// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

interface IToken {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
    event Issue(uint256 _amount, address indexed beneficiary);
    event BurnToken(uint256 _amount, address indexed burner);

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);

    function burn(address burner, uint256 amount) external;

    function issue(address beneficiary, uint256 amount) external;

    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

    function getTotalSupplyCap() external view returns (uint256);
}