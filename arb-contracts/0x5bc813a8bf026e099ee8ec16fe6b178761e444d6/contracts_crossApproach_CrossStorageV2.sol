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

import "./contracts_components_Proxy.sol";
import "./contracts_components_Halt.sol";
import "./contracts_components_ReentrancyGuard.sol";
import "./contracts_crossApproach_CrossStorage.sol";

contract CrossStorageV2 is CrossStorage, ReentrancyGuard, Halt, Proxy {

    /************************************************************
     **
     ** VARIABLES
     **
     ************************************************************/

    /** STATE VARIABLES **/
    uint256 public currentChainID;
    address public admin;

    /** STRUCTURES **/
    struct SetFeesParam {
        uint256 srcChainID;
        uint256 destChainID;
        uint256 contractFee;
        uint256 agentFee;
    }

    struct GetFeesParam {
        uint256 srcChainID;
        uint256 destChainID;
    }

    struct GetFeesReturn {
        uint256 contractFee;
        uint256 agentFee;
    }
}