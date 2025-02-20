// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "./src_vendors_LayerZeroV1_IOFTCoreUpgradeable.sol";
import "./lib_openzeppelin-contracts-upgradeable_contracts_token_ERC20_IERC20Upgradeable.sol";

/**
 * @dev Interface of the OFT standard
 */
interface IOFTUpgradeable is IOFTCoreUpgradeable, IERC20Upgradeable {

}