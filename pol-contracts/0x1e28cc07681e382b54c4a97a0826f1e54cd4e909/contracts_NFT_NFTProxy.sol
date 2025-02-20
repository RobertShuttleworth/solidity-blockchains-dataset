// UNLICENSED : Solidity follows the npm recommendation.
pragma solidity ^0.8.9;

import "./openzeppelin_contracts_proxy_ERC1967_ERC1967Proxy.sol";
import "./contracts_NFT_EternalStorage.sol";

contract NFTProxy is EternalStorage, ERC1967Proxy {

  constructor(
    address _royaltyReceiver,
    uint96 _royaltyFeesInBips,
    address _logic,
    address _forwarder,
    string memory name,
    string memory symbol,
    bytes memory _data
  ) EternalStorage(name, symbol, _forwarder) ERC1967Proxy(_logic, _data) {
    _setDefaultRoyalty(_royaltyReceiver, _royaltyFeesInBips);
  }

  function upgradeImplementation(address _impl) public onlyOwner {
    _upgradeTo(_impl);
  }
}