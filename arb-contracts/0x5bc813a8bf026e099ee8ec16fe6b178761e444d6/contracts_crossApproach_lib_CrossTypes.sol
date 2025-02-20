// SPDX-License-Identifier: MIT

/*

  Copyright 2023 Wanchain Foundation.

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

//                            _           _           _
//  __      ____ _ _ __   ___| |__   __ _(_)_ __   __| | _____   __
//  \ \ /\ / / _` | '_ \ / __| '_ \ / _` | | '_ \@/ _` |/ _ \ \ / /
//   \ V  V / (_| | | | | (__| | | | (_| | | | | | (_| |  __/\ V /
//    \_/\_/ \__,_|_| |_|\___|_| |_|\__,_|_|_| |_|\__,_|\___| \_/
//
//

pragma solidity ^0.8.18;

import "./contracts_interfaces_IRC20Protocol.sol";
import "./contracts_interfaces_IQuota.sol";
import "./contracts_interfaces_IStoremanGroup.sol";
import "./contracts_interfaces_ITokenManager.sol";
import "./contracts_interfaces_ISignatureVerifier.sol";
import "./contracts_crossApproach_lib_HTLCTxLib.sol";
import "./contracts_crossApproach_lib_RapidityTxLib.sol";

library CrossTypes {
    using SafeMath for uint;

    /**
     *
     * STRUCTURES
     *
     */

    struct Data {

        /// map of the htlc transaction info
        HTLCTxLib.Data htlcTxData;

        /// map of the rapidity transaction info
        RapidityTxLib.Data rapidityTxData;

        /// quota data of storeman group
        IQuota quota;

        /// token manager instance interface
        ITokenManager tokenManager;

        /// storemanGroup admin instance interface
        IStoremanGroup smgAdminProxy;

        /// storemanGroup fee admin instance address
        address smgFeeProxy;

        ISignatureVerifier sigVerifier;

        /// @notice transaction fee, smgID => fee
        mapping(bytes32 => uint) mapStoremanFee;

        /// @notice transaction fee, origChainID => shadowChainID => fee
        mapping(uint => mapping(uint =>uint)) mapContractFee;

        /// @notice transaction fee, origChainID => shadowChainID => fee
        mapping(uint => mapping(uint =>uint)) mapAgentFee;

    }

    /**
     *
     * MANIPULATIONS
     *
     */

    /// @notice       convert bytes to address
    /// @param b      bytes
    function bytesToAddress(bytes memory b) internal pure returns (address addr) {
        assembly {
            addr := mload(add(b,20))
        }
    }

    function transfer(address tokenScAddr, address to, uint value)
        internal
        returns(bool)
    {
        uint beforeBalance;
        uint afterBalance;
        IRC20Protocol token = IRC20Protocol(tokenScAddr);
        beforeBalance = token.balanceOf(to);
        (bool success,) = tokenScAddr.call(abi.encodeWithSelector(token.transfer.selector, to, value));
        require(success, "transfer failed");
        afterBalance = token.balanceOf(to);
        return afterBalance == beforeBalance.add(value);
    }

    function transferFrom(address tokenScAddr, address from, address to, uint value)
        internal
        returns(bool)
    {
        uint beforeBalance;
        uint afterBalance;
        IRC20Protocol token = IRC20Protocol(tokenScAddr);
        beforeBalance = token.balanceOf(to);
        (bool success,) = tokenScAddr.call(abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
        require(success, "transferFrom failed");
        afterBalance = token.balanceOf(to);
        return afterBalance == beforeBalance.add(value);
    }
}