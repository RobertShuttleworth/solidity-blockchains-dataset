// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import {TxDataUtils} from "./contracts_utils_TxDataUtils.sol";
import {IGuard} from "./contracts_interfaces_guards_IGuard.sol";
import {IPoolLogic} from "./contracts_interfaces_IPoolLogic.sol";
import {ICompoundV3CometRewards} from "./contracts_interfaces_compound_ICompoundV3CometRewards.sol";
import {IPoolManagerLogic} from "./contracts_interfaces_IPoolManagerLogic.sol";
import {ITransactionTypes} from "./contracts_interfaces_ITransactionTypes.sol";
import {IHasSupportedAsset} from "./contracts_interfaces_IHasSupportedAsset.sol";
import {IHasAssetInfo} from "./contracts_interfaces_IHasAssetInfo.sol";

/// @title Transaction guard for Compound v3 Comet Rewards contract
contract CompoundV3CometRewardsContractGuard is TxDataUtils, IGuard, ITransactionTypes {
  /// @notice Transaction guard for Compound v3 cAsset Comet Rewards contract
  /// @dev It supports claiming rewards from the Compound Comet Rewards contract
  /// @param poolManagerLogic the pool manager logic
  /// @param to the Comet rewards address
  /// @param data the transaction data
  /// @return txType the transaction type of a given transaction data
  /// @return isPublic if the transaction is public or private
  function txGuard(
    address poolManagerLogic,
    address to,
    bytes calldata data
  ) external virtual override returns (uint16 txType, bool) {
    address poolLogic = IPoolManagerLogic(poolManagerLogic).poolLogic();
    require(msg.sender == poolLogic, "not pool logic");

    ICompoundV3CometRewards compoundV3Rewards = ICompoundV3CometRewards(to);

    bytes4 method = getMethod(data);
    bytes memory params = getParams(data);

    if (method == ICompoundV3CometRewards.claim.selector) {
      (address comet, address receiver, ) = abi.decode(params, (address, address, bool));

      address rewardAsset = compoundV3Rewards.rewardConfig(comet).token;
      bool isValidAsset = IHasAssetInfo(IPoolLogic(poolLogic).factory()).isValidAsset(rewardAsset);

      if (isValidAsset) {
        require(IHasSupportedAsset(poolManagerLogic).isSupportedAsset(rewardAsset), "reward asset not enabled");
      }
      require(receiver == poolLogic, "invalid receiver");
      require(IHasSupportedAsset(poolManagerLogic).isSupportedAsset(comet), "Compound asset not enabled");

      txType = uint16(TransactionType.CompoundClaimRewards);
    }

    return (txType, false);
  }
}