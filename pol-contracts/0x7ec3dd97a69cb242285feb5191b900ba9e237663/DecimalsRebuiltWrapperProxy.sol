// SPDX-License-Identifier: MIT
// File: @openzeppelin/contracts/token/ERC721/IERC721Receiver.sol


// OpenZeppelin Contracts (last updated v5.1.0) (token/ERC721/IERC721Receiver.sol)

pragma solidity ^0.8.20;

/**
 * @title ERC-721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC-721 asset contracts.
 */
interface IERC721Receiver {
    /**
     * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
     * by `operator` from `from`, this function is called.
     *
     * It must return its Solidity selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be
     * reverted.
     *
     * The selector can be obtained in Solidity with `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

// File: DecimalsRebuiltProxyWrapper.sol


pragma solidity ^0.8.9;


interface IDecimalsRebuilt {
    function mint(uint256 bundleId) external payable;
    function bundles(uint256 bundleId) external view returns (
        string memory name,
        uint256 itemCount,
        uint256 priceUSD,
        bool minted
    );
    function getETHPrice(uint256 priceInDollars) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
}

contract DecimalsRebuiltWrapperProxy is IERC721Receiver {
    IDecimalsRebuilt public immutable originalContract;
    address private owner;
    
    event MintAttempted(uint256 bundleId, address recipient, uint256 value, uint256 requiredPrice);
    event OriginalMintSuccess(uint256 bundleId, address recipient);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }
    
    constructor(address _originalContract) {
        require(_originalContract != address(0), "Invalid contract address");
        originalContract = IDecimalsRebuilt(_originalContract);
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "New owner is the zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
    
    function mint(address _to, uint256 _bundleId) external payable {
        require(_to != address(0), "Invalid recipient address");
        
        (,, uint256 priceUSD, bool minted) = originalContract.bundles(_bundleId);
        require(!minted, "Bundle already minted");
        require(priceUSD > 0, "Invalid bundle price");

        uint256 requiredPrice = originalContract.getETHPrice(priceUSD);
        require(msg.value >= requiredPrice, "Insufficient payment");

        emit MintAttempted(_bundleId, _to, msg.value, requiredPrice);
        
        uint256 startTokenId = originalContract.totalSupply();
                
        originalContract.mint{value: requiredPrice}(_bundleId);
                
        uint256 endTokenId = originalContract.totalSupply();
                
        for (uint256 tokenId = startTokenId; tokenId < endTokenId; tokenId++) {
            originalContract.safeTransferFrom(address(this), _to, tokenId);
        }

        emit OriginalMintSuccess(_bundleId, _to);
        
        uint256 excess = msg.value - requiredPrice;
        if (excess > 0) {
            payable(msg.sender).transfer(excess);
        }
    }
    
    receive() external payable {}
    
    function withdrawStuckETH() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }

    
}