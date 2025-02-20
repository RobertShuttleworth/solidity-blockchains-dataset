// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.8.0;

/*@@@@@@@       @@@@@@@@@
 @@@@@@@@@       @@@@@@@@@
  @@@@@@@@@       @@@@@@@@@
   @@@@@@@@@       @@@@@@@@@
    @@@@@@@@@@@@@@@@@@@@@@@@@
     @@@@@  HYPERLANE  @@@@@@@
    @@@@@@@@@@@@@@@@@@@@@@@@@
   @@@@@@@@@       @@@@@@@@@
  @@@@@@@@@       @@@@@@@@@
 @@@@@@@@@       @@@@@@@@@
@@@@@@@@@       @@@@@@@@*/

// ============ Internal Imports ============

import {IInterchainSecurityModule} from "./contracts_interfaces_IInterchainSecurityModule.sol";
import {Message} from "./contracts_libs_Message.sol";
import {TypeCasts} from "./contracts_libs_TypeCasts.sol";
import {AbstractMessageIdAuthorizedIsm} from "./contracts_isms_hook_AbstractMessageIdAuthorizedIsm.sol";

// ============ External Imports ============
import {CrossChainEnabledPolygonChild} from "./openzeppelin_contracts_crosschain_polygon_CrossChainEnabledPolygonChild.sol";
import {Address} from "./openzeppelin_contracts_utils_Address.sol";

/**
 * @title PolygonPosIsm
 * @notice Uses the native Polygon Pos Fx Portal Bridge to verify interchain messages.
 */
contract PolygonPosIsm is
    CrossChainEnabledPolygonChild,
    AbstractMessageIdAuthorizedIsm
{
    // ============ Constants ============

    uint8 public constant moduleType =
        uint8(IInterchainSecurityModule.Types.NULL);

    // ============ Constructor ============

    constructor(address _fxChild) CrossChainEnabledPolygonChild(_fxChild) {
        require(
            Address.isContract(_fxChild),
            "PolygonPosIsm: invalid FxChild contract"
        );
    }

    // ============ Internal function ============

    /**
     * @notice Check if sender is authorized to message `verifyMessageId`.
     */
    function _isAuthorized() internal view override returns (bool) {
        return
            _crossChainSender() == TypeCasts.bytes32ToAddress(authorizedHook);
    }
}