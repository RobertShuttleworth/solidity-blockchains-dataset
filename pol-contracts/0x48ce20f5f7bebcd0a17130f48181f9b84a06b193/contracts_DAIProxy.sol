// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

contract DAIProxy {
    // ERC20 Storage
    mapping(address => uint256) internal _balances;
    mapping(address => mapping(address => uint256)) internal _allowances;
    uint256 internal _totalSupply;
    string internal _name;
    string internal _symbol;
    uint8 internal _decimals;

    // DAI Specific Storage
    mapping(address => uint256) internal _nonces;
    bytes32 internal DOMAIN_SEPARATOR;
    bytes32 internal constant PERMIT_TYPEHASH = keccak256("Permit(address holder,address spender,uint256 nonce,uint256 expiry,bool allowed)");
}