pragma solidity 0.8.18;

interface IOApp {
  function setTrustedRemote(uint16 _remoteChainId, bytes calldata _path) external;

  function useCustomAdapterParams() external returns (bool);

  function minDstGasLookup(uint16 _dstChainId, uint16 _type) external returns (uint256);
}