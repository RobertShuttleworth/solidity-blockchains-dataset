// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC721} from "./openzeppelin_contracts_token_ERC721_IERC721.sol";
import {IERC721Metadata} from "./openzeppelin_contracts_token_ERC721_extensions_IERC721Metadata.sol";
import {IERC721Enumerable} from "./openzeppelin_contracts_token_ERC721_extensions_IERC721Enumerable.sol";

import "./contracts_relocation_interfaces_IExchangeBillPayments.sol";
import "./contracts_relocation_interfaces_external_IERC721Permit.sol";


/**
 * @notice Interface module which provide a definition of the bill manager.
 * @dev Wraps ZicoDAO's realocations into a NFT token interface.
 * @dev Credits to Uniswap V3
 *
 * @custom:website https://nft.poczta-polska.pl
 * @author rutilicus.eth (ArchXS)
 * @custom:security-contact contact@archxs.com
 */
interface IExchangeBillManager is IExchangeBillPayments, IERC721Metadata, IERC721Enumerable, IERC721Permit {
    /**
     * @dev Structure used to mint/lock tokens.
     */
    struct BillNote {
        // A currency token
        address currency;
        // An interest rate
        uint24 interests;
        // A liability amount
        uint256 amount;
        // A liability owner
        address remitent;
        // A vesting period
        uint24 lockingPeriod;
        // A liability period
        uint24 payoutPeriod;
    } 

    /// @dev Current promissory details
    struct Promissory {
        // The transge for bill 
        uint16 tranche;
        // The nonce for permits
        uint96 nonce;
        // The allowed wallet address
        address operator;
        // A issuance timestamp of the bill
        uint256 issuance;
        // A exchange timestamp of the bill
        uint256 exchange;
        // The series for bill 
        string series;
    }

    /**
     * 
     * @param tokenId The ID of the token that represents the promissory.
     */
    function present(uint256 tokenId) external view returns (BillNote memory, Promissory memory);

    /**
     * @notice Creates a new `biil of exchange` wrapped in a NFT token.
     * 
     */
    function claim(uint16 tranche) external payable returns (uint256 tokenId);

    /**
     * @notice Burns a token of the given ID, which deletes it from the NFT contract.
     * @dev Burns `tokenId` in exchange for locked amount.
     */
    function exchange(uint256 tokenId) external payable;

    /**
     * @dev Burns `tokenId`. See {ERC721-_burn}.
     * @param tokenId The ID of the token to be burnded
     */
    function burn(uint256 tokenId) external payable;

}
