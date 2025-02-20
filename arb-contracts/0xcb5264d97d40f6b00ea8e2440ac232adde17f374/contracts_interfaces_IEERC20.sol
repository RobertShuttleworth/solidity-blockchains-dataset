pragma solidity ^0.8.24;
import './fhevm_lib_TFHE.sol';

interface IEERC20 {
  event Approval(address indexed owner, address indexed spender);
  event Transfer(address indexed from, address indexed to);

  function name() external pure returns (string memory);

  function symbol() external pure returns (string memory);

  function decimals() external pure returns (uint8);

  // function totalSupply() external view returns (uint);
  function balanceOf(address owner) external view returns (euint32);

  function mint(address to, uint32 mintedAmount) external;

  function burn(address from, euint32 burnAmount) external returns (euint32);

  function allowance(
    address owner,
    address spender
  ) external view returns (euint32);

  function approve(address spender, euint32 value) external returns (bool);

  function transfer(address to, euint32 value) external returns (bool);

  function transferFrom(
    address from,
    address to,
    euint32 value
  ) external returns (bool);

  function DOMAIN_SEPARATOR() external view returns (bytes32);

  function PERMIT_TYPEHASH() external pure returns (bytes32);

  function nonces(address owner) external view returns (uint);

  // function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;
}