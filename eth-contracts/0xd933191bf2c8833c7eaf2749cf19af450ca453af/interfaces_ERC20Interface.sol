// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

interface ERC20Interface {

    function totalSupply()  external view returns (uint256);

    //view
    function symbol()  external view returns (string memory);
    function decimals()  external view returns (uint256 decimals_);
    function balanceOf(address _owner)  external view returns (uint256 balance);
    function allowance(address _owner, address _spender)  external view returns (uint256 remaining);

    //write
    function transfer(address _to, uint256 _value) external returns (bool success);
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool success);
    function approve(address _spender, uint256 _value)  external returns (bool success);


    event Transfer(address indexed _from, address indexed _to, uint256 _value); 
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}