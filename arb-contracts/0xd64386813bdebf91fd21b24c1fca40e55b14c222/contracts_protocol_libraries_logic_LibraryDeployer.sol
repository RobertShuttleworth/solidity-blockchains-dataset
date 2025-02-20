// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

import {ReserveLogic} from './contracts_protocol_libraries_logic_ReserveLogic.sol';
import {GenericLogic} from './contracts_protocol_libraries_logic_GenericLogic.sol';
import {ValidationLogic} from './contracts_protocol_libraries_logic_ValidationLogic.sol';

contract LibraryDeployer {
  constructor() public {
    _deploy(type(ReserveLogic).creationCode);
    _deploy(type(GenericLogic).creationCode);
    _deploy(type(ValidationLogic).creationCode);
  }

  function _deploy(bytes memory bytecode) internal returns (address) {
    address computedAddress = computeAddress(bytes32(0), bytecode);
    address deployed;
    bytes32 salt = bytes32(0);
    if (!isDeployed(computedAddress)) {
      assembly {
        deployed := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
      }
      require(deployed != address(0), 'Deployment failed');
      require(deployed == computedAddress, 'Computed address does not match deployed address');
    }
    return computedAddress;
  }

  function isDeployed(address target) public view returns (bool) {
    uint256 size;
    assembly {
      size := extcodesize(target)
    }
    return size > 0;
  }

  function computeAddress(bytes32 salt, bytes memory bytecode) public view returns (address) {
    bytes32 value = keccak256(
      abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(bytecode))
    );
    return address(uint160(uint256(value)));
  }
}