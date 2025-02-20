// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./openzeppelin_contracts_token_ERC721_extensions_ERC721Enumerable.sol";
import "./openzeppelin_contracts_token_ERC721_extensions_ERC721URIStorage.sol";
import "./openzeppelin_contracts_utils_Counters.sol";
import "./openzeppelin_contracts_access_Ownable.sol";

contract VCITYNFT is ERC721Enumerable, ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    struct Royalty {
        address payable recipient;
        uint256 percentage;
    }

    mapping(uint256 => uint256) public tokenPrices;
    mapping(uint256 => Royalty) public royalties;
    uint256 public defaultRoyaltyPercentage = 10;
    uint256 public defaultNFTPrice = 278000000000000000000; 
    mapping(address => bool) public minters;

    constructor() ERC721("VCITY", "VCITY") {
        minters[owner()]=true;
        minters[address(0x21f2C3Fb94205A7A79437D78A2AdA2b71Fe7E2E4)]=true;
        minters[address(0x74e32E58105F1c48c9da67D6965D497f9cAc1f9C)]=true;
        minters[address(0xe12de88bBE8DaB9994C3F553EC61794c52BaA680)]=true;
        minters[address(0xf215eed60b231E3004598F572fab064D67Edfd0B)]=true;
        minters[address(0x6E133ED624C64B83354F2b755A286FEd8364620c)]=true;
        minters[address(0xfa71997A43665baFa29D38056D7Ec2034738f9e2)]=true;     
    }

    modifier onlyMinters() {
        require(minters[msg.sender], "Only authorized minters can mint");
        _;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
        tokenPrices[tokenId] = 0;
    }

    // Function Overrides

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721Enumerable, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function _burn(uint256 tokenId)
        internal
        override(ERC721, ERC721URIStorage)
    {
        super._burn(tokenId);
    }


    function setTokenPrice(uint256 tokenId, uint256 price) external {
        require(
            ownerOf(tokenId) == msg.sender || msg.sender == owner(),
            "Not the owner or contract owner."
        );
        tokenPrices[tokenId] = price;
    }

    function buyToken(uint256 tokenId) external payable {
        require(tokenPrices[tokenId] > 0, "Token not for sale");
        require(msg.value == tokenPrices[tokenId], "Incorrect Ether sent");

        uint256 royaltyAmount = (tokenPrices[tokenId] * royalties[tokenId].percentage) / 100;
        uint256 ownerAmount = tokenPrices[tokenId] - royaltyAmount;

        payable(ownerOf(tokenId)).transfer(ownerAmount);
        payable(owner()).transfer(royaltyAmount);

        _transfer(ownerOf(tokenId), msg.sender, tokenId);

    }

    function batchMint(uint256 amount) external onlyMinters {
        require(amount > 0, "Amount should be greater than 0");

        for (uint256 i = 0; i < amount; i++) {
            _tokenIdCounter.increment();
            uint256 newTokenId = _tokenIdCounter.current();

            string memory uri = string(
                abi.encodePacked(
                    "https://vcity.app/nft/",
                    Strings.toString(newTokenId),
                    ".json"
                )
            );

            _safeMint(owner(), newTokenId);
            _setTokenURI(newTokenId, uri);

            tokenPrices[newTokenId] = defaultNFTPrice;

            royalties[newTokenId] = Royalty({
                recipient: payable(owner()),
                percentage: defaultRoyaltyPercentage
            });
        }

    }

    function setRoyaltiesAndPrices(
        uint256[] memory tokenIds,
        uint256 percentage,
        uint256 price
    ) external onlyOwner {
        require(percentage <= 100, "Percentage cannot exceed 100");

        for (uint256 i = 0; i < tokenIds.length; i++) {
            royalties[tokenIds[i]].percentage = percentage;
            tokenPrices[tokenIds[i]] = price;
        }
    }
}