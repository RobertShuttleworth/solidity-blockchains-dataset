// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "./contracts_relocation_interfaces_IExchangeBillManager.sol";

/**
 * @notice Interface module which describes bill of exchange NFT tokens via URI.
 * @dev Credits to Uniswap V3
 *
 * @custom:website https://nft.poczta-polska.pl
 * @author rutilicus.eth (ArchXS)
 * @custom:security-contact contact@archxs.com
 */
interface IExchangeBillTokenDescriptor {
    /**
     * @notice Produces the token URI describing a particular token ID for a bill.
     * 
     * @param manager The biil of exchangefor which to describe the token.
     * @param tokenId The ID of the token for which to produce a description.
     */
    function tokenURI(IExchangeBillManager manager, uint256 tokenId) external view returns (string memory);
}

