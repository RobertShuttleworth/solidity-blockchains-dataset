// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Authorized.sol";
import "./ISwapRouter.sol";
import "./INonfungiblePositionManager.sol";
import "./IERC721.sol";
import "./UniswapPoolFactory.sol";

contract CryptoPoolUniswapV3 is Authorized {

    UniswapPoolFactory public poolFactory;
    ISwapRouter public immutable swapRouter;
    INonfungiblePositionManager public immutable nonfungiblePositionManager;

    address[] public allowedTokens = [
        0xc2132D05D31c914a87C6611C10748AEb04B58e8F, // USDT
        0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174, // USDCe
        0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359  // USDC
    ];

    //address public constant USDT = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;

    enum EventType { Decrease, Collect }
    mapping(address => bool) public isValidPool;
    mapping(address => address) public poolByOwner;
    mapping(address => address) public ownerByPool;
    

    event PoolCreated(address indexed owner, address indexed poolAddress);
    event decreaseCall(address indexed owner, address indexed poolAddress, uint256 balance);
    event collectCall(address indexed owner, address indexed poolAddress, uint256 balance);


    constructor(
        ISwapRouter _swapRouter, 
        INonfungiblePositionManager _nonfungiblePositionManager, 
        address _poolManagerImplementation
    ) {
        swapRouter = _swapRouter;
        nonfungiblePositionManager = _nonfungiblePositionManager;
        poolFactory = new UniswapPoolFactory(_poolManagerImplementation);
    }

    function emitPoolEvent(EventType eventType, uint256 balance, address owner) external {
        require(isValidPool[msg.sender], "Not a valid pool");

        if (eventType == EventType.Decrease) {
            emit decreaseCall(owner, msg.sender, balance);
        } else if (eventType == EventType.Collect) {
            emit collectCall(owner, msg.sender, balance);
        }
    }

    function StartNewPool(address operator) internal {

        if (poolByOwner[operator] == address(0)) {
            address newPool = poolFactory.createPool(
                address(swapRouter),
                address(nonfungiblePositionManager),
                operator,
                address(this) 
            );

            poolByOwner[operator] = newPool;
            ownerByPool[newPool] = operator;
            isValidPool[newPool] = true;

            emit PoolCreated(operator, newPool);
        }
    }  

    function swapTokensAndMint(uint8 tokenIndex, address token0, address token1, uint256 amount, uint24 fee, int24 tickLower, int24 tickUpper) external{
       //New ? 
       StartNewPool(msg.sender);
       address poolAddress = poolByOwner[msg.sender];
       require(poolAddress != address(0), "Pool does not exist for this owner");
       //StableCOIN 
       IERC20(allowedTokens[tokenIndex]).transferFrom(msg.sender, address(this), amount);       
       IERC20(allowedTokens[tokenIndex]).transfer(poolAddress, amount);       
       //Swap and Mint in Pool
       IUniswapPoolManager(poolAddress).swapTokensAndMint(tokenIndex, token0, token1, amount, fee, tickLower, tickUpper);
    }

    function collectUSDT(uint8 tokenIndex, uint256 tokenId) external {
       address poolAddress = poolByOwner[msg.sender];
       IUniswapPoolManager(poolAddress).collectUSD(tokenIndex, tokenId);
    }

    function addLiquidity(uint8 tokenIndex, uint256 tokenId, uint256 amount) external {
       address poolAddress = poolByOwner[msg.sender];
       IUniswapPoolManager(poolAddress).addLiquidity(tokenIndex, tokenId, amount);
    }

    function decreaseLiquidity(uint8 tokenIndex, uint256 tokenId, uint128 liquidity) external {
       address poolAddress = poolByOwner[msg.sender];
       IUniswapPoolManager(poolAddress).decreaseLiquidity(tokenIndex, tokenId, liquidity);
    }

    function collectSubscription(address token, uint256 amount) public isAuthorized(0) {
        IERC20(token).transfer(msg.sender, amount);
    }    

    function getPoolByOwner(address _owner) external view returns (address) {
        return poolByOwner[_owner];
    }
    function getOwnerByPool(address _pool) external view returns (address) {
        return ownerByPool[_pool];
    }
}