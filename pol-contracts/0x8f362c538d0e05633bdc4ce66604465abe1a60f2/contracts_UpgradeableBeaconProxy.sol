/*
    SPDX-License-Identifier: Apache-2.0

    Copyright 2023 Reddit, Inc

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
*/

pragma solidity ^0.8.9;

import "./openzeppelin_contracts_proxy_beacon_BeaconProxy.sol";

error UpgradeableBeaconProxy__Unauthorized();

/**
 * @title UpgradeableBeaconProxy
 * @notice BeaconProxy where admin slot address can set another Beacon
 */
contract UpgradeableBeaconProxy is BeaconProxy {

  modifier onlyBeaconUpdater {
    if(msg.sender != getBeaconUpdater()) {
      revert UpgradeableBeaconProxy__Unauthorized();
    }
    _;
  }
  
  modifier onlyBeaconUpdaterOrBeacon {
    address sender = msg.sender;
    if(sender != getBeaconUpdater() && sender != _getBeacon()) {
      revert UpgradeableBeaconProxy__Unauthorized();
    }
    _;
  }

  /// @dev set beaconUpdater address to be stored on the admin slot
  /// this slot is defined in ERC1967Upgrade.sol and is unused for beacon proxies.
  /// beaconUpdater is in practise a multisig between reddit and creator that controls which beacon to point to.
  constructor(address beaconUpdater, address beacon, bytes memory data) BeaconProxy(beacon, data) payable {
    _changeAdmin(beaconUpdater);
  }

  /// @notice call from admin slot (aka beaconUpdater) to change to another beacon.
  function upgradeBeaconToAndCall(address newBeacon, bytes memory data, bool forceCall) public onlyBeaconUpdaterOrBeacon {
    _upgradeBeaconToAndCall(newBeacon, data, forceCall);
  }

  function getBeacon() external view returns (address) {
    return _getBeacon();
  }

  function implementation() external view returns (address) {
    return _implementation();
  }

  function getBeaconUpdater() public view returns (address) {
    return _getAdmin();
  }

  function changeBeaconUpdater(address newBeaconUpdater) public onlyBeaconUpdater {
    _changeAdmin(newBeaconUpdater);
  }
}