pragma solidity >=0.8.0 <0.9.0;

// SPDX-License-Identifier: MIT
import "./openzeppelin_contracts-upgradeable_token_ERC721_IERC721Upgradeable.sol";

abstract contract ILenderManager is IERC721Upgradeable {
    /**
     * @notice Registers a new active lender for a loan, minting the nft.
     * @param _bidId The id for the loan to set.
     * @param _newLender The address of the new active lender.
     */
    function registerLoan(uint256 _bidId, address _newLender) external virtual;
}