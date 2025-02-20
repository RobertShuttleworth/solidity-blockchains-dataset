// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.7.6;
pragma abicoder v2;

import "./uniswap_v3-periphery_contracts_libraries_TransferHelper.sol";

library LibERC20Adapter {

    /// @dev ETH pseudo-token address.
    address constant internal ETH_TOKEN_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /// @dev Return value indicating success
    bytes4 constant internal TRANSFORMER_SUCCESS = 0x13c9929e;

    /// @notice Transfer ERC20 tokens and ETH.
    /// @param token An ERC20 or the ETH pseudo-token address (`ETH_TOKEN_ADDRESS`).
    /// @param to The recipient.
    /// @param amount The transfer amount.
    function adapterTransfer(
        IERC20 token,
        address payable to,
        uint256 amount
    )
    internal
    {
        if (isTokenETH(token)) {
            TransferHelper.safeTransferETH(to, amount);
        } else {
            TransferHelper.safeTransfer(address(token), to, amount);
        }
    }

    /// @notice Check if a token is the ETH pseudo-token.
    /// @param token The token to check.
    /// @return isETH `true` if the token is the ETH pseudo-token.
    function isTokenETH(IERC20 token)
    internal
    pure
    returns (bool isETH)
    {
        return address(token) == ETH_TOKEN_ADDRESS;
    }

    /// @notice Check the balance of an ERC20 token or ETH.
    /// @param token An ERC20 or the ETH pseudo-token address (`ETH_TOKEN_ADDRESS`).
    /// @param owner Holder of the tokens.
    /// @return tokenBalance The balance of `owner`.
    function getTokenBalanceOf(IERC20 token, address owner)
    internal
    view
    returns (uint256 tokenBalance)
    {
        if (isTokenETH(token)) {
            return owner.balance;
        }
        return token.balanceOf(owner);
    }
}