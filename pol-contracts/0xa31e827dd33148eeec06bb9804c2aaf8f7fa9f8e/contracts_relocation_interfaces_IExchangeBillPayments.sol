// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @notice Interface module which provide a definition of the bill payments.
 * @dev Credits to Uniswap V3
 * 
 * @custom:website https://nft.poczta-polska.pl
 * @author rutilicus.eth (ArchXS)
 * @custom:security-contact contact@archxs.com
 */
interface IExchangeBillPayments {
    /*
     * @notice Transfers the full amount of a token held by this contract to recipient.
     * 
     * @param token The contract address of the token which will be transferred to `recipient`.
     * @param amount The minimum amount of token required for a transfer.
     * @param recipient The destination address of the token.
     */
    function withdraw(address token, uint256 amount, address recipient) external payable;
}