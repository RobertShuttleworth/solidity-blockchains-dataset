// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import './openzeppelin_contracts_token_ERC721_IERC721.sol';

/// @title ERC721 with permit
/// @notice Extension to ERC721 that includes a permit function for signature based approvals
/**
 * @notice Interface module which provide a permit function to ERC721 for signature based approvals.
 * @dev Credits to Uniswap V3
 *
 * @custom:website https://nft.poczta-polska.pl
 * @author rutilicus.eth (ArchXS)
 * @custom:security-contact contact@archxs.com
 */
interface IERC721Permit is IERC721 {
    /**
     * @dev The permit typehash used in the permit signature.
     * @return The typehash for the permit.
     */ 
    function PERMIT_TYPEHASH() external pure returns (bytes32);

    /**
     * @notice Approve of a specific token ID for spending by spender via signature
     * @param spender The account that is being approved.
     * @param tokenId The ID of the token that is being approved for spending.
     * @param deadline The deadline timestamp by which the call must be mined for the approve to work.
     * @param v Must produce valid secp256k1 signature from the holder along with `r` and `s`.
     * @param r Must produce valid secp256k1 signature from the holder along with `v` and `s`.
     * @param s Must produce valid secp256k1 signature from the holder along with `r` and `v`.
     */
    function permit(address spender, uint256 tokenId, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external payable;
}