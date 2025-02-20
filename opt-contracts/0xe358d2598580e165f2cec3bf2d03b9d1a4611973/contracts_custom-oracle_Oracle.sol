// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./chainlink_contracts_src_v0.8_interfaces_AggregatorV3Interface.sol";
import "./openzeppelin_contracts-upgradeable_access_OwnableUpgradeable.sol";
import "./pythnetwork_pyth-sdk-solidity_IPyth.sol";
import "./pythnetwork_pyth-sdk-solidity_PythStructs.sol";
import {IOracle} from "./contracts_custom-oracle_IOracle.sol";

contract Oracle is OwnableUpgradeable, IOracle {

  IPyth public pythOracle;

  mapping(bytes32 => AggregatorV3Interface) public chainLinkOracles ;
  mapping(bytes32 => Price) public ownersData;

  function initialize(IPyth _pythOracle) external initializer {
    pythOracle = _pythOracle;

    __Ownable_init(_msgSender());
  }

  function getPrice(bytes32 id) external view returns (Price memory) {
    PythStructs.Price memory pythPrice = pythOracle.getPriceUnsafe(id);

    int256 chainLinkPrice;
    uint256 updatedAt;

    AggregatorV3Interface chainLinkOracle = chainLinkOracles[id];
    if (address(chainLinkOracle) != address(0)) {
      (, chainLinkPrice, , updatedAt,) = chainLinkOracle.latestRoundData();
    }

    Price memory ownerData = ownersData[id];

    if (pythPrice.publishTime > updatedAt && pythPrice.publishTime > ownerData.timestamp) {
      return Price({
        price: uint256(uint64(pythPrice.price)),
        decimals: uint8(uint32(- 1 * pythPrice.expo)),
        timestamp: pythPrice.publishTime
      });

    } else if (updatedAt > ownerData.timestamp) {
      return Price({
        price: uint256(chainLinkPrice),
        decimals: chainLinkOracle.decimals(),
        timestamp: updatedAt
      });
    }

    return ownerData;
  }

  function setChainLinkOracles(bytes32[] calldata id, AggregatorV3Interface[] calldata oracle) external onlyOwner {
    require(id.length == oracle.length, InvalidArrayLengthERR());

    for (uint256 i = 0; i < id.length; i++) {
      chainLinkOracles[id[i]] = oracle[i];
    }
  }

  function setOwnersData(bytes32[] calldata id, uint256[] calldata price, uint8[] calldata decimals) external onlyOwner {
    require(id.length == price.length, InvalidArrayLengthERR());

    for (uint256 i = 0; i < id.length; i++) {
      ownersData[id[i]] = Price({
        price: price[i],
        timestamp: block.timestamp,
        decimals: decimals[0]
      });
    }
  }

  uint256[47] private __gap;
}
