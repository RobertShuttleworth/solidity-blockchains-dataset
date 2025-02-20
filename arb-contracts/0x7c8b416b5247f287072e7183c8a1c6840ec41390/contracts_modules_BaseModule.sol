// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.24;

import {Math} from "./contracts_utils_Math.sol";
import {SafeTransferLib} from "./lib_solmate_src_utils_SafeTransferLib.sol";
import {ERC20} from "./lib_solmate_src_tokens_ERC20.sol";
import {VaultV5} from "./contracts_VaultV5.sol";
import {IVault} from "./contracts_interfaces_IVault.sol";
import {CryptonergyManager} from "./contracts_CryptonergyManager.sol";
import {UniversalOracle} from "./contracts_oracles_UniversalOracle.sol";

/**
 * @title Base Module
 * @notice Base contract all adaptors must inherit from.
 * @dev Allows Vaults to interact with arbritrary DeFi assets and protocols.
 * @author crispymangoes
 */
abstract contract BaseModule {
    using SafeTransferLib for ERC20;
    using Math for uint256;

    error ForbiddenReceiver();
    error UserDepositsForbidden();
    error UserWithdrawalsForbidden();
    error Slippage();
    error UnsupportedAsset(address asset);

    // error BaseModule__ConstructorHealthFactorTooLow();

    //============================================ Global Functions ===========================================
    /**
     * @dev Identifier unique to this adaptor for a shared registry.
     * Normally the identifier would just be the address of this contract, but this
     * Identifier is needed during Cellar Delegate Call Operations, so getting the address
     * of the adaptor is more difficult.
     */
    function moduleId() public pure virtual returns (bytes32) {
        return keccak256(abi.encode("Module V 0.0"));
    }

    function SWAP_ROUTER_SLOT() internal pure returns (uint256) {
        return 0;
    }

    function UIVERSAL_ORACLE_SLOT() internal pure returns (uint256) {
        return 1;
    }

    /**
     * @notice Max possible slippage when making a swap router swap.
     */
    function slippage() public pure returns (uint32) {
        return 0.9e4;
    }

    // function MINIMUM_CONSTRUCTOR_HEALTH_FACTOR()
    //     internal
    //     pure
    //     virtual
    //     returns (uint256)
    // {
    //     return 1.05e18;
    // }

    function getBalance(
        bytes memory moduleData
    ) public view virtual returns (uint256);

    function baseAsset(
        bytes memory moduleData
    ) public view virtual returns (ERC20);

    function assetsUsed(
        bytes memory moduleData
    ) public view virtual returns (ERC20[] memory assets) {
        assets = new ERC20[](1);
        assets[0] = baseAsset(moduleData);
    }

    function _maxAvailable(
        ERC20 token,
        uint256 amount
    ) internal view virtual returns (uint256) {
        if (amount == type(uint256).max) return token.balanceOf(address(this));
        else return amount;
    }

    function _revokeApproval(ERC20 asset, address spender) internal {
        if (asset.allowance(address(this), spender) > 0)
            asset.safeApprove(spender, 0);
    }

    function _checkReceiver(address receiver) internal view {
        if (
            receiver != address(this) ||
            IVault(address(this)).blockExternalReceiver()
        ) revert ForbiddenReceiver();
    }

    // /**
    //  * @notice Helper function that validates external receivers are allowed.
    //  */
    // function _verifyConstructorMinimumHealthFactor(
    //     uint256 minimumHealthFactor
    // ) internal pure {
    //     if (minimumHealthFactor < MINIMUM_CONSTRUCTOR_HEALTH_FACTOR())
    //         revert BaseModule__ConstructorHealthFactorTooLow();
    // }

    /**
     * @notice Allows strategists to zero out an approval for a given `asset`.
     * @param asset the ERC20 asset to revoke `spender`s approval for
     * @param spender the address to revoke approval for
     */
    function revokeApproval(ERC20 asset, address spender) public {
        asset.safeApprove(spender, 0);
    }
}