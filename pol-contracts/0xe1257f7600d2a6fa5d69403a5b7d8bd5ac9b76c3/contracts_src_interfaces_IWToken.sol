// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.26;

// import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol"; // @todo needed?
import {IERC20} from "./openzeppelin_contracts_token_ERC20_IERC20.sol";

// @todo Update comment
/**
 * @notice Collateral token contract
 * @dev The `CollateralToken` contract inherits from ERC20 contract. It implements a
 * `mint` and a `burn` function which can only be called by the `CollateralToken`
 * contract owner (AaveDIVAWrapper).
 *
 * The `CollateralToken` contract is deployed during the pool creation / liquidity
 * addition process with AaveDIVAWrapper being set as the owner.
 * The `mint` function is used during pool creation (`createContingentPool`)
 * and addition of liquidity (`addLiquidity`). Collateral tokens are burnt
 * during token redemption (`redeemCollateralToken`) and removal of liquidity
 * (`removeLiquidity`).
 *
 * Collateral tokens have the same number of decimals as the yielding token (e.g., aUSDT).
 */
interface IWToken is IERC20 {
    /**
     * @notice Function to mint ERC20 wTokens.
     * @dev Called during `createContingentPool` and `addLiquidity`.
     * Can only be called by the owner of the wToken which
     * is AaveDIVAWrapper.
     * @param _recipient The account receiving the wTokens.
     * @param _amount The number of wTokens to mint.
     */
    function mint(address _recipient, uint256 _amount) external;

    /**
     * @notice Function to burn wTokens.
     * @dev Called within `redeemWToken` and `removeLiquidity`.
     * Can only be called by the owner of the wToken which
     * is AaveDIVAWrapper.
     * @param _redeemer Address redeeming wTokens.
     * @param _amount The number of wTokens to burn.
     */
    function burn(address _redeemer, uint256 _amount) external;

    /**
     * @notice Returns the owner of the wToken (AaveDIVAWrapper).
     * @return The address of the wToken owner.
     */
    function owner() external view returns (address);

    function decimals() external view returns (uint8);
}