// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// 引入OpenZeppelin库中相关的ERC721合约和工具
// 引入OpenZeppelin库中相关的ERC721合约和工具
// 引入OpenZeppelin库中相关的ERC721合约和工具
// 引入OpenZeppelin库中相关的ERC721合约和工具
// 引入OpenZeppelin库中相关的ERC721合约和工具
// 引入OpenZeppelin库中相关的ERC721合约和工具
// 引入OpenZeppelin库中相关的ERC721合约和工具
// 引入OpenZeppelin库中相关的ERC721合约和工具
// 引入OpenZeppelin库中相关的ERC721合约和工具
// 引入OpenZeppelin库中相关的ERC721合约和工具
// 引入OpenZeppelin库中相关的ERC721合约和工具
// 引入OpenZeppelin库中相关的ERC721合约和工具
// 引入OpenZeppelin库中相关的ERC721合约和工具
// 引入OpenZeppelin库中相关的ERC721合约和工具
// 引入OpenZeppelin库中相关的ERC721合约和工具
// 引入OpenZeppelin库中相关的ERC721合约和工具
// 引入OpenZeppelin库中相关的ERC721合约和工具
// 引入OpenZeppelin库中相关的ERC721合约和工具
// 引入OpenZeppelin库中相关的ERC721合约和工具
// 引入OpenZeppelin库中相关的ERC721合约和工具
// 引入OpenZeppelin库中相关的ERC721合约和工具
// 引入OpenZeppelin库中相关的ERC721合约和工具
// 引入OpenZeppelin库中相关的ERC721合约和工具
// 引入OpenZeppelin库中相关的ERC721合约和工具
// 引入OpenZeppelin库中相关的ERC721合约和工具
// 引入OpenZeppelin库中相关的ERC721合约和工具
import "./openzeppelin_contracts_token_ERC721_extensions_ERC721Enumerable.sol"; // ERC721Enumerable提供了可枚举的NFT功能 import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol"; // ERC721URIStorage提供了存储每个NFT URI的功能 import "@openzeppelin/contracts/utils/Counters.sol"; // 用于安全地计数，例如跟踪tokenId import "@openzeppelin/contracts/access/Ownable.sol"; // Ownable提供了合约所有权管理功能 import "@openzeppelin/contracts/security/ReentrancyGuard.sol"; // 防止重入攻击  // KYC_NFT合约继承自ERC721Enumerable, ERC721URIStorage, Ownable和ReentrancyGuard contract KYC_NFT is ERC721Enumerable, ERC721URIStorage, Ownable, ReentrancyGuard { using Counters for Counters.Counter; // 使用OpenZeppelin的计数器来追踪tokenId Counters.Counter private _tokenIdCounter; // 私有变量，用于存储当前的tokenId计数  mapping(uint256 => uint256) public tokenPrices; // tokenId到其价格的映射  uint256 public constant MAX_SUPPLY = 9999; // 设置NFT的最大供应量  // 构造函数，初始化NFT的名称和符号 constructor() ERC721("KYC NFT", "KYC NFT") {}  // 此处用于在转移前将NFT的价格设置为0 function _beforeTokenTransfer( address from, address to, uint256 tokenId, uint256 batchSize ) internal override(ERC721, ERC721Enumerable) { super._beforeTokenTransfer(from, to, tokenId, batchSize);
        tokenPrices[tokenId] = 0;
    }

    // 重写supportsInterface以支持多重继承的接口
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Enumerable, ERC721URIStorage)
        returns (bool)
    {
        return
            ERC721Enumerable.supportsInterface(interfaceId) ||
            ERC721URIStorage.supportsInterface(interfaceId);
    }

    // 重写tokenURI以返回特定tokenId的URI
    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    // 重写_burn函数，以实现在销毁NFT时执行的逻辑
    function _burn(uint256 tokenId)
        internal
        override(ERC721, ERC721URIStorage)
    {
        super._burn(tokenId);
    }

    // 允许NFT所有者设置其NFT的售价
    function setTokenPrice(uint256 tokenId, uint256 price) external {
        require(ownerOf(tokenId) == msg.sender, "Not the owner");
        tokenPrices[tokenId] = price;
    }

    // 允许合约所有者批量铸造NFT
    // 确保总量不超过最大供应量
    function batchMint(uint256 amount) external onlyOwner {
        require(
            amount > 0 && _tokenIdCounter.current() + amount <= MAX_SUPPLY,
            "Invalid amount"
        );
        for (uint256 i = 0; i < amount; i++) {
            _tokenIdCounter.increment();
            uint256 newTokenId = _tokenIdCounter.current();
            string memory uri = string(
                abi.encodePacked(
                    "https://vcity.app/kyc_nft/",
                    Strings.toString(newTokenId),
                    ".json"
                )
            );
            _safeMint(owner(), newTokenId);
            _setTokenURI(newTokenId, uri);
            tokenPrices[newTokenId] = 0;
        }
    }

    // 允许用户购买NFT，并处理收益分配
    function buyToken(uint256 tokenId) external payable nonReentrant {
        uint256 price = tokenPrices[tokenId];
        require(price > 0, "Token not for sale");
        require(msg.value == price, "Incorrect payment value");

        // 清除NFT的售价并将其转移给买家
        tokenPrices[tokenId] = 0;
        address seller = ownerOf(tokenId);
        _transfer(seller, msg.sender, tokenId);

        // 计算并分配收益
        uint256 platformAmount = (price * 10) / 100; // 平台费用
        uint256 ownerAmount = price - platformAmount; // 卖家收益

        // 将收益转给相应的地址
        payable(owner()).transfer(platformAmount);
        payable(seller).transfer(ownerAmount);
    }


}