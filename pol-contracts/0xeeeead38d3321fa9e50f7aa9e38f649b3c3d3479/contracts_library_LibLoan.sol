// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

library LibLoan {

    struct Loan {
        address borrower;
        NFT[] nfts;
        uint256 duration;
        address loanPaymentContract;
        uint256 loanAmount;
        uint256 loanPercentage;
        uint256 loanId;
    }

    struct NFT {
        address collectionAddress;
        uint256 tokenId;
    }

    struct LoanRequest {
        address borrower;
        address lender;
        NFT[] nfts;
        string requestId;
        uint256 startTime;
        uint256 duration;
        address loanPaymentContract;
        uint256 loanAmount;
        uint256 loanPercentage;
        uint256 loanId;
    }

    bytes private constant LOAN_TYPE_STRING = abi.encodePacked("Loan(address borrower,address lender,NFT[] nfts,string requestId,uint256 startTime,uint256 duration,address loanPaymentContract,uint256 loanAmount,uint256 loanPercentage,uint256 loanId)");
    bytes private constant NFT_TYPE_STRING = abi.encodePacked("NFT(address collectionAddress,uint256 tokenId)");

    bytes32 private constant LOAN_TYPEHASH = keccak256(abi.encodePacked(LOAN_TYPE_STRING, NFT_TYPE_STRING));
    bytes32 private constant NFT_TYPEHASH = keccak256(NFT_TYPE_STRING);

    bytes private constant LOAN_OFFER_TYPE_STRING = abi.encodePacked("Loan(address lender,NFT[] nfts,uint256 startTime,uint256 duration,address loanPaymentContract,uint256 loanAmount,uint256 loanPercentage)");
    bytes32 private constant LOAN_OFFER_TYPEHASH = keccak256(abi.encodePacked(LOAN_OFFER_TYPE_STRING, NFT_TYPE_STRING));

    /**
     * @dev Internal function to get loan hash.
     *
     * Requirements:
     * @param loanRequest - loanRequest object.
     * 
     * @return bytes32 - hash value.
     */
    function _genLoanRequestHash(LoanRequest memory loanRequest) internal pure returns(bytes32) {
        bytes32[] memory nftHashes = new bytes32[](loanRequest.nfts.length);
        for (uint256 i = 0; i < loanRequest.nfts.length; ++i) {
            // Hash the nfts and place the result into memory.
            nftHashes[i] = _hashNftItem(loanRequest.nfts[i]);
        }
        return keccak256(
            abi.encode(LOAN_TYPEHASH, loanRequest.borrower, loanRequest.lender, keccak256(abi.encodePacked(nftHashes)), keccak256(bytes(loanRequest.requestId)), loanRequest.startTime, loanRequest.duration, loanRequest.loanPaymentContract, loanRequest.loanAmount, loanRequest.loanPercentage, loanRequest.loanId)
        );
    }

    /**
     * @dev Internal function to get nft hash.
     *
     * Requirements:
     * @param nft - nft object.
     * 
     * @return bytes32 - hash value.
     */
    function _hashNftItem(NFT memory nft) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(NFT_TYPEHASH, nft.collectionAddress, nft.tokenId)
        );
    }

    /**
     * @dev Internal function to get loan hash.
     *
     * Requirements:
     * @param loanRequest - loanRequest object.
     * 
     * @return bytes32 - hash value.
     */
    function _genLoanOfferHash(LoanRequest memory loanRequest) internal pure returns(bytes32) {
        bytes32[] memory nftHashes = new bytes32[](loanRequest.nfts.length);
        for (uint256 i = 0; i < loanRequest.nfts.length; ++i) {
            // Hash the nfts and place the result into memory.
            nftHashes[i] = _hashNftItem(loanRequest.nfts[i]);
        }
        return keccak256(
            abi.encode(LOAN_OFFER_TYPEHASH, loanRequest.lender, keccak256(abi.encodePacked(nftHashes)), loanRequest.startTime, loanRequest.duration, loanRequest.loanPaymentContract, loanRequest.loanAmount, loanRequest.loanPercentage)
        );
    }
}