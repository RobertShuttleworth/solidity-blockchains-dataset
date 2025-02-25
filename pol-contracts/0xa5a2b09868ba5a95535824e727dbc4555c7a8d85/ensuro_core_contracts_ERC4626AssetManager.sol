// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {SafeCast} from "./openzeppelin_contracts_utils_math_SafeCast.sol";
import {IERC20Metadata} from "./openzeppelin_contracts_token_ERC20_extensions_IERC20Metadata.sol";
import {IERC4626} from "./openzeppelin_contracts_interfaces_IERC4626.sol";
import {LiquidityThresholdAssetManager} from "./ensuro_core_contracts_LiquidityThresholdAssetManager.sol";

/**
 * @title Asset Manager that deploys the funds into an ERC4626 vault
 * @dev Using liquidity thresholds defined in {LiquidityThresholdAssetManager}, deploys the funds into an ERC4626 vault.
 * @custom:security-contact security@ensuro.co
 * @author Ensuro
 *
 * @notice This contracts uses Diamond Storage and should not define state variables outside of that. See the diamondStorage method for more details.
 */
contract ERC4626AssetManager is LiquidityThresholdAssetManager {
  using SafeCast for uint256;

  IERC4626 internal immutable _vault;

  constructor(IERC20Metadata asset_, IERC4626 vault_) LiquidityThresholdAssetManager(asset_) {
    require(address(vault_) != address(0), "ERC4626AssetManager: vault cannot be zero address");
    require(address(asset_) == vault_.asset(), "ERC4626AssetManager: vault must have the same asset");
    _vault = vault_;
  }

  function connect() public virtual override {
    super.connect();
    _asset.approve(address(_vault), type(uint256).max); // infinite approval to the vault
  }

  function _invest(uint256 amount) internal virtual override {
    super._invest(amount);
    _vault.deposit(amount, address(this));
  }

  function _deinvest(uint256 amount) internal virtual override {
    super._deinvest(amount);
    _vault.withdraw(amount, address(this), address(this));
  }

  function deinvestAll() external virtual override returns (int256 earnings) {
    DiamondStorage storage ds = diamondStorage();
    uint256 assets = _vault.redeem(_vault.balanceOf(address(this)), address(this), address(this));
    earnings = int256(assets) - int256(uint256(ds.lastInvestmentValue));
    ds.lastInvestmentValue = 0;
    emit MoneyDeinvested(assets);
    emit EarningsRecorded(earnings);
    return earnings;
  }

  function getInvestmentValue() public view virtual override returns (uint256) {
    return _vault.convertToAssets(_vault.balanceOf(address(this)));
  }
}