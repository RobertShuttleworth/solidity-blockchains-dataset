pragma solidity ^0.8.24;
import './fhevm_lib_TFHE.sol';

interface IEERC20Wrapper {
  function depositAndWrap(address _to, uint256 _amount) external;

  function depositToken(
    uint256 _amount,
    einput _encryptedAddress,
    bytes calldata _inputProof
  ) external;

  function claimWrappedToken() external;

  function withdrawToken(
    address _to,
    euint32 _amount,
    bytes4 _selector
  ) external;
}