// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./contracts_EgeMoneyV5.sol";
interface IMintableERC20 is IERC20 {
    function isAdmin(address _admin) external view returns (bool);
    function mint(address to, uint256 amount) external;
    function burnFrom(address to, uint256 amount) external;
}
contract Nft5Storage {
    IMintableERC20 public erc20Token;

    address public admin;

    uint256 public internalValue;
    uint256 public externalValue;
    uint256 private _totalBurnedTRY;

    mapping(address => mapping(uint256 => uint256)) public fractionalBalances;
    mapping(uint256 => address[]) public tokenOwners;
    mapping(uint256 => uint256) public housePrices;
    mapping(uint256 => mapping(address => bool)) public isAddressExists;
    mapping(uint256 => uint256) public maxFraction;
    mapping(uint256 => uint256) public burnedFractions;
    mapping(uint256 => bool) public tokenMinted;
    mapping(uint256 => uint256) public fractionPrices;
    

    mapping(uint256 => mapping(address => uint256)) public holderIndices;
    uint256[49] private __gap;
}