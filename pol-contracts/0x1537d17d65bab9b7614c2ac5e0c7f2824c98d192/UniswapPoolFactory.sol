// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC1967Proxy.sol";

interface IUniswapPoolManager {
    function initialize(
        address _swapRouter,
        address _nonfungiblePositionManager,
        address _owner,
        address _factory
    ) external;

    //function transferNFT(address to, uint256 tokenId) external;
    //function adjustUsedLimit(uint256 newLimit) external;
    function collectUSD(uint8 tokenIndex, uint256 tokenId) external;
    function addLiquidity(uint8 tokenIndex, uint256 tokenId, uint256 amount) external;
    function decreaseLiquidity(uint8 tokenIndex, uint256 tokenId, uint128 liquidity) external;
    function swapTokensAndMint(uint8 tokenIndex, address token0, address token1, uint256 amount, uint24 fee, int24 tickLower, int24 tickUpper) external;
    function adjustRange(uint8 tokenIndex, address operator, uint256 tokenId, bool moveRight, int24 tickMove) external;
    function moveRangeUp(uint8 tokenIndex, address operator, uint256 tokenId, int24 ticks) external;
    function moveRangeDown(uint8 tokenIndex, address operator, uint256 tokenId, int24 ticks) external;
}

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function getOwner() external view returns (address);
    function allowance(address _owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

contract UniswapPoolFactory {
    address public immutable implementationAddress;

    event PoolCreated(address indexed owner, address poolAddress);

    constructor(address _implementationAddress) {
        implementationAddress = _implementationAddress;
    }

    function createPool(
        address _swapRouter,
        address _nonfungiblePositionManager,
        address _owner,
        address _factory
    ) external returns (address) {
        bytes memory initializeData = abi.encodeWithSelector(
            IUniswapPoolManager.initialize.selector,
            _swapRouter,
            _nonfungiblePositionManager,
            _owner,
            _factory
        );

        ERC1967Proxy proxy = new ERC1967Proxy(
            implementationAddress,
            initializeData
        );

        address poolAddress = address(proxy);
        emit PoolCreated(_owner, poolAddress);
        return poolAddress;
    }
}