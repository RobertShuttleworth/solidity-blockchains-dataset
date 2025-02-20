// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.24;

import {BaseModule, ERC20, SafeTransferLib, UniversalOracle, Math} from "./contracts_modules_BaseModule.sol";
import {ICryptonergyVault} from "./contracts_interfaces_ICryptonergyVault.sol";
import {ICryptonergyManager} from "./contracts_interfaces_ICryptonergyManager.sol";
import {Address} from "./openzeppelin_contracts_utils_Address.sol";
import {IGainsVault} from "./contracts_interfaces_external_Gains_IGainsVault.sol";

contract GainsModule is BaseModule {
    //==================== Module Data Specification ====================
    // adaptorData = abi.encode(address vault, address asset)
    // Where:
    // `vault` is the Gains this adaptor is working with
    // `asset` is the asset the vault is using. For example Dai
    //===================================================================

    using SafeTransferLib for ERC20;
    using Math for uint256;
    using Address for address;

    error GainsModule__UntrackedLiquidity(IGainsVault vault, ERC20 asset);
    error GainsModule__DepositExists(IGainsVault vault, ERC20 asset);
    error GainsModule__DepositNotFound(IGainsVault vault, ERC20 asset);
    error GainsModule__ClaimForbidden(IGainsVault vault, ERC20 asset);
    error GainsModule__UnsupportedAsset(IGainsVault vault, ERC20 asset);

    constructor() {}

    function moduleId() public pure override returns (bytes32) {
        return keccak256(abi.encode("Gains V 0.5"));
    }

    function getBalance(
        bytes memory moduleData
    ) public view override returns (uint256) {
        address vault = abi.decode(moduleData, (address));
        uint256 accountSharesBalance = IGainsVault(vault).balanceOf(msg.sender);
        uint256 accountAssetBalance = IGainsVault(vault).convertToAssets(
            accountSharesBalance
        );

        return accountAssetBalance;
    }

    function baseAsset(
        bytes memory moduleData
    ) public pure override returns (ERC20) {
        (, address asset) = abi.decode(moduleData, (address, address));
        return ERC20(asset);
    }

    function assetsUsed(
        bytes memory moduleData
    ) public pure override returns (ERC20[] memory assets) {
        assets = new ERC20[](1);
        assets[0] = baseAsset(moduleData);
    }

    function deposit(IGainsVault vault, ERC20 asset, uint256 amount) external {
        // _checkStrategyIsUsed(vault, asset);
        // if (address(asset) != vault.asset()) {
        //     revert GainsModule__UnsupportedAsset(vault, asset);
        // }
        // if (vault.balanceOf(address(this)) > 0) {
        //     revert GainsModule__DepositExists(vault, asset);
        // }
        // if (amount == type(uint256).max) {
        //     amount = asset.balanceOf(address(this));
        // }
        // asset.safeApprove(address(vault), amount);
        // vault.deposit(amount, address(this));
    }

    function redeposit(
        IGainsVault vault,
        ERC20 asset,
        uint256 amount
    ) external {
        revert GainsModule__DepositNotFound(vault, asset);
        // _checkStrategyIsUsed(vault, asset);
        // if (vault.balanceOf(address(this)) == 0) {
        //     revert GainsModule__DepositNotFound(vault, asset);
        // }
        // if (amount == type(uint256).max) {
        //     amount = asset.balanceOf(address(this));
        // }
        // asset.safeApprove(address(vault), amount);
        // vault.deposit(amount, address(this));
    }

    function withdraw(IGainsVault vault, uint256 amount) external {
        vault.makeWithdrawRequest(amount, address(this));
        // ERC20 asset = ERC20(vault.asset());
        // _checkStrategyIsUsed(vault, asset);
        // if (vault.balanceOf(address(this)) == 0) {
        //     revert GainsModule__DepositNotFound(vault, asset);
        // }
        // ERC20(address(vault)).safeApprove(address(vault), amount);
        // vault.redeem(amount, address(this), address(this));
    }

    function exit(IGainsVault vault) external {
        ERC20 asset = ERC20(vault.asset());
        _checkStrategyIsUsed(vault, asset);
        if (vault.balanceOf(address(this)) == 0) {
            revert GainsModule__DepositNotFound(vault, asset);
        }
        uint256 accountSharesBalance = vault.balanceOf(address(this));
        ERC20(address(vault)).safeApprove(address(vault), accountSharesBalance);
        vault.redeem(accountSharesBalance, address(this), address(this));
    }

    function _checkStrategyIsUsed(
        IGainsVault vault,
        ERC20 asset
    ) internal view {
        bytes32 positionHash = keccak256(
            abi.encode(moduleId(), abi.encode(vault, asset))
        );
        address manager = ICryptonergyVault(address(this)).cryptonergyManager();
        uint32 managerPositionId = ICryptonergyManager(manager)
            .getStrategyHashToStrategyId(positionHash);

        if (!ICryptonergyVault(address(this)).isStrategyUsed(managerPositionId))
            revert GainsModule__UntrackedLiquidity(vault, asset);
    }
}