// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {AppStorage} from "./src_AppStorage.sol";

// Allows libraries to access protocol's state, via `AppStorage`, found at slot of 0.
// `AppStorage` is precisely at slot 0 and nowhere else ever, because this is
// the only state that should ever be declared in facets through this pattern.
library LibAppStorage {
    function appStorage() internal pure returns (AppStorage storage s) {
        assembly {
            s.slot := 0
        }
    }
}