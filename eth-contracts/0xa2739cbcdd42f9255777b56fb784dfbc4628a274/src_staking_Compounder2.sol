// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { IERC20Upgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_token_ERC20_IERC20Upgradeable.sol";
import { ERC20Upgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_token_ERC20_ERC20Upgradeable.sol";
import { OwnableUpgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_access_OwnableUpgradeable.sol";
import { SafeERC20Upgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_token_ERC20_utils_SafeERC20Upgradeable.sol";

import { IStaking } from "./src_staking_interfaces_IStaking.sol";
import { ITLCStaking } from "./src_staking_interfaces_ITLCStaking.sol";
import { NonblockingLzAppUpgradeable } from "./src_vendors_LayerZeroV1_NonblockingLzAppUpgradeable.sol";
import { Transfer as TransferLib } from "./src_libraries_Transfer.sol";
import { IOFTV2 } from "./lib_layer-zero-example_contracts_token_oft_v2_IOFTV2.sol";
import { LzLib } from "./lib_layer-zero-example_contracts_libraries_LzLib.sol";
import { ICommonOFT } from "./lib_layer-zero-example_contracts_token_oft_v2_ICommonOFT.sol";
import { IOApp } from "./src_interfaces_IOApp.sol";

// @dev Compounder2: remove Uni V3 LP rewards and add cross-chain functionality

contract Compounder2 is NonblockingLzAppUpgradeable {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  error Compounder2_InconsistentLength();

  address public dp;
  address public destinationCompoundPool;
  address[] public tokens;
  mapping(address => bool) public isCompoundableTokens;
  address public tlcStaking;
  address[] public defaultPools;
  address[][] public defaultRewarders;
  uint256 public defaultStartEpochTimestamp;
  mapping(address => uint16) public bridgeTokenLzEid;
  uint16[] public destinationLzEid;
  uint256 public gasForDestinationLzReceive;

  event LogAddToken(address token, bool isCompoundToken);
  event LogRemoveToken(address token);
  event LogSetCompoundToken(address token, bool isCompoundToken);
  event LogSetDestinationCompoundPool(
    address oldDestinationCompoundPool_,
    address newDestinationCompoundPool
  );
  event LogSetBridgeTokenLzEid(address token, uint16 lzEid);
  event LogAddDestinationLzEid(uint16 lzEid);
  event LogSetGasForDestinationLzReceive(uint256 oldGasLimit, uint256 newGasLimit);

  function initialize(
    address dp_,
    address destinationCompoundPool_,
    address[] memory tokens_,
    bool[] memory isCompoundTokens_,
    address tlcStaking_,
    address lzEndpointV1_
  ) external initializer {
    NonblockingLzAppUpgradeable.__NonblockingLzAppUpgradeable_init(lzEndpointV1_);

    dp = dp_;
    destinationCompoundPool = destinationCompoundPool_;
    addToken(tokens_, isCompoundTokens_);
    tlcStaking = tlcStaking_;
  }

  function addToken(
    address[] memory newTokens,
    bool[] memory newIsCompoundTokens
  ) public onlyOwner {
    uint256 length = newTokens.length;
    if (length != newIsCompoundTokens.length) revert Compounder2_InconsistentLength();

    for (uint256 i = 0; i < length; ) {
      tokens.push(newTokens[i]);
      setCompoundToken(newTokens[i], newIsCompoundTokens[i]);

      emit LogAddToken(newTokens[i], newIsCompoundTokens[i]);
      unchecked {
        ++i;
      }
    }
  }

  function removeToken(address token) external onlyOwner {
    uint256 length = tokens.length;

    for (uint256 i = 0; i < length; ) {
      if (tokens[i] == token) {
        tokens[i] = tokens[tokens.length - 1];
        tokens.pop();

        setCompoundToken(token, false);
        emit LogRemoveToken(token);
        break;
      }

      unchecked {
        ++i;
      }
    }
  }

  function setCompoundToken(address token, bool isCompoundToken) public onlyOwner {
    isCompoundableTokens[token] = isCompoundToken;

    if (isCompoundToken)
      IERC20Upgradeable(token).approve(destinationCompoundPool, type(uint256).max);

    emit LogSetCompoundToken(token, isCompoundToken);
  }

  function setDefaultConfigs(
    address[] memory _defaultPools,
    address[][] memory _defaultRewarders,
    uint256 _defaultStartEpochTimestamp
  ) external onlyOwner {
    defaultPools = _defaultPools;
    defaultRewarders = _defaultRewarders;
    defaultStartEpochTimestamp = _defaultStartEpochTimestamp;
  }

  function setDestinationCompoundPool(address _destinationCompoundPool) external onlyOwner {
    emit LogSetDestinationCompoundPool(destinationCompoundPool, _destinationCompoundPool);

    destinationCompoundPool = _destinationCompoundPool;
  }

  function setBridgeTokenLzEids(
    address[] memory _tokens,
    uint16[] memory _lzEids
  ) external onlyOwner {
    if (_tokens.length != _lzEids.length) revert Compounder2_InconsistentLength();
    for (uint256 i = 0; i < _tokens.length; ) {
      emit LogSetBridgeTokenLzEid(_tokens[i], _lzEids[i]);
      bridgeTokenLzEid[_tokens[i]] = _lzEids[i];
      unchecked {
        ++i;
      }
    }
  }

  function addDestinationLzEid(uint16[] memory _lzEids) external onlyOwner {
    for (uint256 i = 0; i < _lzEids.length; ) {
      emit LogAddDestinationLzEid(_lzEids[i]);
      destinationLzEid.push(_lzEids[i]);
      unchecked {
        ++i;
      }
    }
  }

  function setGasForDestinationLzReceive(uint256 gasLimit) external onlyOwner {
    emit LogSetGasForDestinationLzReceive(gasForDestinationLzReceive, gasLimit);
    gasForDestinationLzReceive = gasLimit;
  }

  function compound(
    address[] memory pools,
    address[][] memory rewarders,
    uint256 startEpochTimestamp,
    uint256 noOfEpochs
  ) external payable {
    _claimAll(msg.sender, pools, rewarders, startEpochTimestamp, noOfEpochs);
    _compoundOrTransfer(msg.sender, true);
  }

  function compound(
    address[] memory pools,
    address[][] memory rewarders,
    uint256 startEpochTimestamp,
    uint256 noOfEpochs,
    bool isCrossChain
  ) external payable {
    _claimAll(msg.sender, pools, rewarders, startEpochTimestamp, noOfEpochs);
    uint256 msgValueLeft = _compoundOrTransfer(msg.sender, true);
    if (isCrossChain) _broadcastClaim(msg.sender, msgValueLeft);
  }

  struct LocalVars {
    uint256 length;
    uint256 amount;
    bytes adapterParams;
    uint256 msgValue;
    IOApp tokenOApp;
  }

  function _compoundOrTransfer(address user, bool isCompound) internal returns (uint256 msgValue) {
    LocalVars memory vars;
    vars.length = tokens.length;
    vars.msgValue = msg.value;
    for (uint256 i = 0; i < vars.length; ) {
      vars.amount = IERC20Upgradeable(tokens[i]).balanceOf(address(this));
      vars.adapterParams = "";
      if (vars.amount > 0) {
        // always compound dragon point
        if (tokens[i] == dp || (isCompound && isCompoundableTokens[tokens[i]])) {
          IERC20Upgradeable(tokens[i]).approve(destinationCompoundPool, type(uint256).max);
          IStaking(destinationCompoundPool).deposit(user, tokens[i], vars.amount);
          IERC20Upgradeable(tokens[i]).approve(destinationCompoundPool, 0);
        } else if (bridgeTokenLzEid[tokens[i]] > 0) {
          // Check for OFT dust
          if (
            ERC20Upgradeable(tokens[i]).decimals() == 6 ||
            (ERC20Upgradeable(tokens[i]).decimals() == 18 && vars.amount > 1e12)
          ) {
            vars.tokenOApp = IOApp(tokens[i]);
            if (vars.tokenOApp.useCustomAdapterParams()) {
              vars.adapterParams = abi.encodePacked(
                uint16(1),
                vars.tokenOApp.minDstGasLookup(bridgeTokenLzEid[tokens[i]], 0)
              );
            }
            (uint256 nativeFee, ) = lzEndpoint.estimateFees(
              bridgeTokenLzEid[tokens[i]],
              tokens[i],
              abi.encodePacked(uint8(0), LzLib.addressToBytes32(user), vars.amount),
              false,
              vars.adapterParams
            );
            IOFTV2(tokens[i]).sendFrom{ value: nativeFee }(
              address(this),
              bridgeTokenLzEid[tokens[i]],
              LzLib.addressToBytes32(user),
              vars.amount,
              ICommonOFT.LzCallParams({
                refundAddress: payable(user),
                zroPaymentAddress: address(0),
                adapterParams: vars.adapterParams
              })
            );
            if (vars.msgValue > nativeFee) {
              vars.msgValue -= nativeFee;
            } else {
              vars.msgValue = 0;
            }
          }
        } else {
          IERC20Upgradeable(tokens[i]).safeTransfer(user, vars.amount);
        }
      }

      unchecked {
        ++i;
      }
    }
    return vars.msgValue;
  }

  function _claimAll(
    address user,
    address[] memory pools,
    address[][] memory rewarders,
    uint256 startEpochTimestamp,
    uint256 noOfEpochs
  ) internal {
    uint256 length = pools.length;
    for (uint256 i = 0; i < length; ) {
      if (tlcStaking == pools[i]) {
        ITLCStaking(pools[i]).harvestToCompounder(
          user,
          startEpochTimestamp,
          noOfEpochs,
          rewarders[i]
        );
      } else {
        IStaking(pools[i]).harvestToCompounder(user, rewarders[i]);
      }

      unchecked {
        ++i;
      }
    }
  }

  function claimAndCompound(address user, bool isCrossChain) public payable {
    _claimAll(user, defaultPools, defaultRewarders, defaultStartEpochTimestamp, type(uint256).max);
    uint256 msgValueLeft = _compoundOrTransfer(user, true);
    if (isCrossChain) _broadcastClaim(user, msgValueLeft);
  }

  function _broadcastClaim(address user, uint256 msgValue) internal {
    uint16 version = 1;
    bytes memory adapterParams = abi.encodePacked(version, gasForDestinationLzReceive);

    for (uint256 i = 0; i < destinationLzEid.length; ) {
      // send LayerZero message
      _lzSend(
        destinationLzEid[i],
        abi.encode(user), // payload
        payable(user), // refund address
        address(0x0), // unused
        adapterParams, // v1 adapterParams, specify custom destination gas qty
        msgValue
      );
      unchecked {
        ++i;
      }
    }
  }

  function _nonblockingLzReceive(
    uint16 /*_srcChainId*/,
    bytes memory /*_srcAddress*/,
    uint64 /*_nonce*/,
    bytes memory _payload
  ) internal override {
    address user = abi.decode(_payload, (address));
    claimAndCompound(user, false);
  }

  function recoverToken(address _token, address _to, uint256 _amount) external onlyOwner {
    TransferLib.nativeOrToken(_token, _to, _amount);
  }

  receive() external payable {}

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }
}