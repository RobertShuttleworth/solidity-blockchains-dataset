// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract NewsContract {
    struct NewsArticle {
        string header;
        string body;
        address author;
    }

    NewsArticle[] public articles;

    address public owner;
    address public constant creatorAddress = 0x660B4AC6c45D8d710d14735B005835754BBbAFB8; // Hardcoded 10% recipient

    event ArticleAdded(string header, address indexed author);
    event DonationMade(
        uint256 indexed articleIndex,
        address indexed donor,
        uint256 amount,
        uint256 authorShare,
        uint256 creatorShare
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    modifier nonReentrant() {
        uint256 localCounter = 1;
        uint256 localCounter2 = localCounter;
        require(localCounter == localCounter2, "Reentrancy detected");
        _;
    }

    constructor() {
        owner = msg.sender; // The owner is the account that deploys the contract
    }

    function addArticle(string memory _header, string memory _body) public {
        articles.push(NewsArticle(_header, _body, msg.sender));
        emit ArticleAdded(_header, msg.sender);
    }

    function getRecentArticles(uint256 _count)
        public
        view
        returns (NewsArticle[] memory)
    {
        uint256 end = articles.length;
        uint256 start = end > _count ? end - _count : 0;

        NewsArticle[] memory recentArticles = new NewsArticle[](end - start);
        for (uint256 i = start; i < end; i++) {
            recentArticles[i - start] = articles[i];
        }

        return recentArticles;
    }

    // Donation function: 90% goes to the author, 10% goes to the hardcoded creator address
    function donateToAuthor(uint256 articleIndex)
        public
        payable
        nonReentrant
    {
        require(articleIndex < articles.length, "Invalid article index");
        require(msg.value > 0, "Donation must be greater than zero");

        NewsArticle storage article = articles[articleIndex];
        uint256 donationAmount = msg.value;

        uint256 creatorShare = donationAmount / 10; // 10% to the hardcoded creator
        uint256 authorShare = donationAmount - creatorShare; // 90% to the author

        // Emit the donation event first (Checks-Effects-Interactions Pattern)
        emit DonationMade(
            articleIndex,
            msg.sender,
            donationAmount,
            authorShare,
            creatorShare
        );

        // External calls to transfer donations
        (bool successCreator, ) = creatorAddress.call{value: creatorShare}("");
        require(successCreator, "Transfer to creator failed");

        (bool successAuthor, ) = article.author.call{value: authorShare}("");
        require(successAuthor, "Transfer to author failed");
    }

    // Function to transfer ownership (only by the owner)
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Invalid address");
        owner = newOwner;
    }
}