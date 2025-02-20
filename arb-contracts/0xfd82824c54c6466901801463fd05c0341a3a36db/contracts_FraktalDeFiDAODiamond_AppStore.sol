// SPDX-License-Identifier: FRAKTAL-PROTOCOl
pragma solidity 0.8.24;

import {IWETH} from './contracts_shared_interfaces_IWETH.sol';
import {LibDiamond} from "./contracts_shared_libraries_LibDiamond.sol";


struct AppStore {
  string VERSION;
  IWETH WETH;
}

library LibAppStore {
  function store () internal pure returns(AppStore storage appStore) {
    assembly {
      appStore.slot := 0
    }
  }

  function setWETH (IWETH weth) internal {
    store().WETH = weth;
  }
  function getVERSION () internal view returns(string memory version) {
    version = store().VERSION;
  }
  function storageId () internal pure returns (bytes32 id) {
    return keccak256(abi.encode(LibDiamond.id()));
  }
}