// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IERC4626} from "./lib_openzeppelin-contracts_contracts_interfaces_IERC4626.sol";
import {IERC20} from "./lib_openzeppelin-contracts_contracts_token_ERC20_IERC20.sol";
import {IERC20Metadata} from "./lib_openzeppelin-contracts_contracts_token_ERC20_extensions_IERC20Metadata.sol";
import {Ownable} from "./lib_openzeppelin-contracts_contracts_access_Ownable.sol";
import {SafeERC20} from "./lib_openzeppelin-contracts_contracts_token_ERC20_utils_SafeERC20.sol";
import {ReentrancyGuard} from "./lib_openzeppelin-contracts_contracts_utils_ReentrancyGuard.sol";
import {Math} from "./lib_openzeppelin-contracts_contracts_utils_math_Math.sol";

import {IERC7540} from "./contracts_interfaces_IERC7540.sol";
import {ILiquidStrategy} from "./contracts_interfaces_ILiquidStrategy.sol";
import {ILendingVault} from "./contracts_interfaces_ILendingVault.sol";

/**
 * @title  - StrategyBase
 * @author - Credit Cooperative
 * @notice - Base contract for all liquid strategies. Contains common functions and state variables.
 * @dev    - State changing functions are only callable by owner or CreditStrategy contract.
 */
abstract contract StrategyBase is Ownable, ILiquidStrategy, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Math for uint256;

    address[] public vaults;
    mapping(address => bool) public isVaultApproved;

    IERC20 public immutable asset;

    address public lendingVault;
    address public oracle;

    uint16 public constant DENOM = 10000;

    /**
     * @notice - Checks the `msg.sender` is `lendingVault`.
     */
    function _onlyLendingVault() internal view {
        if (msg.sender != lendingVault) {
            revert OnlyLendingVault();
        }
    }

    /**
     * @notice - Checks each of the array inputs has the same length.
     */
    function _arrayLengthsMustMatch(address[] memory targets, uint256[] memory amounts, bool[] memory isDeposit)
        internal
        pure
    {
        if (targets.length != amounts.length || targets.length != isDeposit.length) {
            revert ArrayLengthsMustMatch();
        }
    }

    /**
     *
     * @notice - Checks that the vault is approved for use with the strategy.
     */
    function _vaultMustBeApproved(address _vault) internal view {
        if (!isVaultApproved[_vault]) {
            revert VaultNotApproved();
        }
    }

    /**
     * @notice - Checks `_vault` is a 4626 vault with the same native asset as the Strategy contract.
     */
    function _onlyNativeAsset(address _vault) internal view {
        if (address(asset) != address(IERC4626(_vault).asset())) {
            revert VaultNotSupported();
        }
    }

    /**
     * @notice  - Sets the oracle for the strategy
     * @param _oracle - Address of the LendingVault to set
     */
    function setOracle(address _oracle) external onlyOwner {
        oracle = _oracle;
        emit OracleSet(msg.sender, _oracle);
    }

    /**
     * @notice  - Sets the LendingVault for the strategy
     * @dev     - Can only be called once by the owner of the liquidStrategy. The LendingVault must have the same native asset as the liquidStrategy.
     * @param _lendingVault - Address of the LendingVault to set
     */
    function setLendingVault(address _lendingVault) external onlyOwner {
        if (lendingVault != address(0)) revert LendingVaultAlreadySet();
        _onlyNativeAsset(_lendingVault);

        lendingVault = _lendingVault;
        emit LendingVaultSet(msg.sender, _lendingVault);
    }

    /**
     * @notice  - Approves a vault for use with the strategy
     * @dev     - Can only approve vaults with the same native asset as the Strategy contract.
     * @param _vault    - Address of the vault to approve
     */
    function approveVault(address _vault) external virtual onlyOwner {
        _approveVault(_vault);
    }

    /**
     * @notice  - Removes a vault from the strategy
     * @param _vault - Address of the vault to remove
     */
    function removeVault(address _vault) external onlyOwner {
        _removeVault(_vault);
    }

    // See approveVault
    function _approveVault(address _vault) internal virtual {
        _onlyNativeAsset(_vault);
        uint256 len = vaults.length;
        for (uint256 x = 0; x < len; x++) {
            if (vaults[x] == _vault) return;
        }

        vaults.push(_vault);
        isVaultApproved[_vault] = true;
        address underlying = IERC4626(_vault).asset();
        emit VaultAdded(_vault, underlying);
    }

    // See removeVault
    function _removeVault(address _vault) internal {
        /* Remove vault from array by swapping with last element and then popping off the last position
        If the vault is not in the array, this will do nothing, and if is last in the array,
        it will be swapped with itself and then popped off the array */
        uint256 len = vaults.length;
        for (uint256 i = 0; i < len; i++) {
            if (vaults[i] == _vault) {
                vaults[i] = vaults[len - 1];
                vaults.pop();
                isVaultApproved[_vault] = false;
                address underlying = IERC4626(_vault).asset();
                emit VaultRemoved(_vault, underlying);
                break;
            }
        }
        asset.forceApprove(_vault, 0); // revoke any residual approvals for safety
    }

    /**
     * @notice  - Deposits assets into the Strategy contract.
     * @dev     - Only callable by `lendingVault` or `owner`.
     * @param _amount - Amount to deposit (denominated in asset of the Strategy).
     */
    function deposit(uint256 _amount) external {
        _onlyLendingVault();
        asset.safeTransferFrom(msg.sender, address(this), _amount);
        emit StrategyDeposit(msg.sender, address(asset), _amount);
    }

    /**
     * @notice  - Withdraws assets from Strategy contract and transfers them to the LendingVault.
     * @dev     - Only callable by `lendingVault` or `owner`.
     * @param _amount - Amount to withdraw (denominated in asset of the Strategy).
     */
    function withdraw(uint256 _amount) external {
        _onlyLendingVault();
        asset.safeTransfer(msg.sender, _amount);
        emit StrategyWithdraw(msg.sender, address(asset), _amount);
    }

    /**
     * @notice  - Transfers ERC20 tokens from the contract to arbitrary `to` destination. Can be used to recover tokens not in the underlying asset or in emergency situations.
     * @dev     - Only callable by the owner of the liquidStrategy.
     * @param token     - Address of the ERC20 token to recover.
     * @param to        - Address to send the recovered tokens to.
     * @param amount    - Amount of tokens to recover.
     */
    function recoverTokens(address token, address to, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(to, amount);
        emit TokensRecovered(msg.sender, to, token, amount);
    }
}