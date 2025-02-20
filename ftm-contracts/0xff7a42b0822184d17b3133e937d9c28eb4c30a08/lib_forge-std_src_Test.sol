// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.9.0;

pragma experimental ABIEncoderV2;

// 💬 ABOUT
// Forge Std's default Test.

// 🧩 MODULES
import {console} from "./lib_forge-std_src_console.sol";
import {console2} from "./lib_forge-std_src_console2.sol";
import {safeconsole} from "./lib_forge-std_src_safeconsole.sol";
import {StdAssertions} from "./lib_forge-std_src_StdAssertions.sol";
import {StdChains} from "./lib_forge-std_src_StdChains.sol";
import {StdCheats} from "./lib_forge-std_src_StdCheats.sol";
import {stdError} from "./lib_forge-std_src_StdError.sol";
import {StdInvariant} from "./lib_forge-std_src_StdInvariant.sol";
import {stdJson} from "./lib_forge-std_src_StdJson.sol";
import {stdMath} from "./lib_forge-std_src_StdMath.sol";
import {StdStorage, stdStorage} from "./lib_forge-std_src_StdStorage.sol";
import {StdStyle} from "./lib_forge-std_src_StdStyle.sol";
import {stdToml} from "./lib_forge-std_src_StdToml.sol";
import {StdUtils} from "./lib_forge-std_src_StdUtils.sol";
import {Vm} from "./lib_forge-std_src_Vm.sol";

// 📦 BOILERPLATE
import {TestBase} from "./lib_forge-std_src_Base.sol";

// ⭐️ TEST
abstract contract Test is TestBase, StdAssertions, StdChains, StdCheats, StdInvariant, StdUtils {
    // Note: IS_TEST() must return true.
    bool public IS_TEST = true;
}