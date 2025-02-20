// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC1155} from "./node_modules_openzeppelin_contracts_token_ERC1155_ERC1155.sol";
import {Ownable} from "./node_modules_openzeppelin_contracts_access_Ownable.sol";
import {ReentrancyGuard} from "./node_modules_openzeppelin_contracts_utils_ReentrancyGuard.sol";
import {UniswapV3Swap, ISwapRouter, IERC20} from "./src_UniswapV3Swap.sol";

/**
 * @title MultiTokenManager
 * @dev Implementation of a multi-token management system using ERC1155
 * 
 * Architecture Overview:
 * - Base Contracts:
 *   - ERC1155: Handles multi-token functionality
 *   - Ownable: Manages contract ownership
 *   - ReentrancyGuard: Prevents reentrancy attacks
 *
 * - State Variables:
 *   - tokenIdToERC20: Maps ERC1155 tokenIds to ERC20 token addresses
 *   - _uris: Stores metadata URIs for each token
 *   - _tokenIdCounter: Tracks total number of registered tokens
 *   - uniswapV3Swap: Instance of UniswapV3Swap contract for token swaps
 *
 * - Key Features:
 *   - Token Registration: Links ERC20 tokens to ERC1155 tokenIds
 *   - Minting/Burning: Controls token supply
 *   - URI Management: Handles token metadata
 *   - Swap Integration: Enables token swaps via Uniswap V3
 */
contract MultiTokenManager is ERC1155, Ownable, ReentrancyGuard {
    error InvalidERC20Address();
    error TokenNotRegistered();
    error CallerNotApproved();

    /// @notice Mapping from tokenId to its corresponding ERC20 token address
    /// @dev Each ERC1155 token represents a wrapper for an ERC20 token
    mapping(uint256 tokenId => address erc20Address) public tokenIdToERC20;
    
    /// @notice Mapping from tokenId to its metadata URI
    /// @dev Stores the IPFS or HTTP URI containing token metadata
    mapping(uint256 tokenId => string uri) private _uris;
    
    /// @notice Counter for generating unique tokenIds
    /// @dev Increments with each new token registration
    uint256 private _tokenIdCounter;

    /// @notice Instance of UniswapV3Swap contract for token swaps
    /// @dev Deployed during contract construction
    UniswapV3Swap public uniswapV3Swap;
    
    /// @notice Events for tracking token lifecycle: registration, minting, and burning
    event TokenRegistered(uint256 indexed tokenId, address indexed erc20Address);
    event TokenMinted(uint256 indexed tokenId, address indexed to, uint256 amount);
    event TokenBurned(uint256 indexed tokenId, address indexed from, uint256 amount);

    /// @notice Initializes the contract with empty URI and deploys UniswapV3Swap
    constructor() ERC1155("") Ownable(msg.sender) {
        uniswapV3Swap = new UniswapV3Swap();
    }

    function uri(uint256 tokenId) public view override returns (string memory) {
        return _uris[tokenId];
    }
    
    // set URI
    function setURI(uint256 tokenId, string memory newuri) public onlyOwner {
        _uris[tokenId] = newuri;
        emit URI(newuri, tokenId);
    }

    // struct of ERC20 token
    struct TokenInfo {
        address erc20Address;
        string name;
        string symbol;
        uint8 decimals;
    }

    // register ERC20 token, return tokenId
    // ERC20 token is registered after minting and burning, and is managed by ERC1155 token
    function registerToken(TokenInfo calldata info) external onlyOwner returns (uint256) {
        if (info.erc20Address == address(0)) revert InvalidERC20Address();
        
        uint256 newTokenId = _tokenIdCounter++;
        tokenIdToERC20[newTokenId] = info.erc20Address;
        
        emit TokenRegistered(newTokenId, info.erc20Address);
        return newTokenId;
    }

    // mint ERC1155 token
    function mint(
        address to,
        uint256 tokenId,
        uint256 amount,
        bytes memory data
    ) external onlyOwner {
        if (tokenIdToERC20[tokenId] == address(0)) revert TokenNotRegistered();
        _mint(to, tokenId, amount, data);
        emit TokenMinted(tokenId, to, amount);
    }

    ISwapRouter public constant UNISWAP_ROUTER = 
        ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    // swap ERC1155 token to ERC20 token
    // todo: add a function to get current pool fee
    // todo: add a function to get current pool address
    // todo: add a function to swap ERC1155 token to ERC20 token
    function swapExactInputSingle(
        uint256 tokenId,
        address tokenOut,
        uint24 poolFee,
        uint256 amountIn
    ) external nonReentrant returns (uint256 amountOut) {
        if (tokenIdToERC20[tokenId] == address(0)) revert TokenNotRegistered();
        address tokenIn = tokenIdToERC20[tokenId];
        
        // burn user's ERC1155 token
        _burn(msg.sender, tokenId, amountIn);
        
        // transfer corresponding amount of ERC20 token to user
        IERC20(tokenIn).transfer(msg.sender, amountIn);
        
        // call UniswapV3Swap's swap method
        amountOut = uniswapV3Swap.swapExactInputSingleHop(
            tokenIn,
            tokenOut,
            poolFee,
            amountIn
        );
    }

    // burn self ERC1155 token
    function burn(
        uint256 tokenId,
        uint256 amount
    ) external nonReentrant {
        if (tokenIdToERC20[tokenId] == address(0)) revert TokenNotRegistered();
        
        _burn(msg.sender, tokenId, amount);
        emit TokenBurned(tokenId, msg.sender, amount);
    }

    // burn other's ERC1155 token (need approval)
    function burnFrom(
        address from,
        uint256 tokenId,
        uint256 amount
    ) external nonReentrant {
        // check if token is registered
        if (tokenIdToERC20[tokenId] == address(0)) revert TokenNotRegistered();
        
        // check if caller is approved
        if (!isApprovedForAll(from, msg.sender)) revert CallerNotApproved();
        
        _burn(from, tokenId, amount);
        emit TokenBurned(tokenId, from, amount);
    }
}