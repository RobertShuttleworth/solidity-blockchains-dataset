// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "./contracts_weiroll_VM.sol";
import "./contracts_modelers_AaveV3Modeler.sol";
import "./contracts_modelers_WrapperModeler.sol";
import "./contracts_modelers_CurveModeler.sol";
import "./contracts_modelers_BalancerModeler.sol";
import "./contracts_modelers_UniswapV3Modeler.sol";
import "./contracts_modelers_UniswapV2Modeler.sol";
import "./contracts_modelers_LockerModeler.sol";
import "./contracts_modelers_CompoundModeler.sol";
import "./contracts_helpers_HopHelper.sol";
import "./contracts_helpers_HoldersHelper.sol";
import "./contracts_helpers_MathHelper.sol";

contract RouterHelper is
    VM,
    HopHelper,
    HoldersHelper,
    CurveModeler,
    BalancerModeler,
    UniswapV3Modeler,
    UniswapV2Modeler,
    AaveV3Modeler,
    LockerModeler,
    WrapperModeler,
    CompoundModeler,
    MathHelper
{
    function execute(bytes32[] calldata commands, bytes[] memory state) external returns (Hop[] memory) {
        _execute(commands, state);
        return getHops();
    }

    // `fallback` is called when msg.data is not empty
    fallback() external payable {}

    // `receive` is called when msg.data is empty
    receive() external payable {}
}