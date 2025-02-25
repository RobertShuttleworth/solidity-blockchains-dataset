// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import {TxDataUtils} from "./contracts_utils_TxDataUtils.sol";
import {IGuard} from "./contracts_interfaces_guards_IGuard.sol";
import {ICompoundV3Comet} from "./contracts_interfaces_compound_ICompoundV3Comet.sol";
import {IPoolManagerLogic} from "./contracts_interfaces_IPoolManagerLogic.sol";
import {ITransactionTypes} from "./contracts_interfaces_ITransactionTypes.sol";
import {IHasSupportedAsset} from "./contracts_interfaces_IHasSupportedAsset.sol";

/// @title Transaction guard for Compound v3 cAsset Comet contract
contract CompoundV3CometContractGuard is TxDataUtils, IGuard, ITransactionTypes {
  /// @notice Transaction guard for Compound v3 cAsset Comet contract
  /// @dev It supports supplying and withdrawing assets from Compound v3
  /// @param poolManagerLogic the pool manager logic
  /// @param to the cAsset Comet address
  /// @param data the transaction data
  /// @return txType the transaction type of a given transaction data
  /// @return isPublic if the transaction is public or private
  function txGuard(
    address poolManagerLogic,
    address to,
    bytes calldata data
  ) external view virtual override returns (uint16 txType, bool) {
    address poolLogic = IPoolManagerLogic(poolManagerLogic).poolLogic();
    require(msg.sender == poolLogic, "not pool logic");

    ICompoundV3Comet compoundV3Asset = ICompoundV3Comet(to);

    bytes4 method = getMethod(data);
    bytes memory params = getParams(data);

    if (method == ICompoundV3Comet.supply.selector) {
      (address asset, ) = abi.decode(params, (address, uint256));

      require(asset == compoundV3Asset.baseToken(), "invalid Compound asset");
      require(IHasSupportedAsset(poolManagerLogic).isSupportedAsset(to), "Compound not enabled");

      txType = uint16(TransactionType.CompoundDeposit);
    } else if (method == ICompoundV3Comet.withdraw.selector) {
      (address asset, ) = abi.decode(params, (address, uint256));

      require(IHasSupportedAsset(poolManagerLogic).isSupportedAsset(asset), "unsupported withdrawal asset");

      txType = uint16(TransactionType.CompoundWithdraw);
    }

    return (txType, false);
  }
}