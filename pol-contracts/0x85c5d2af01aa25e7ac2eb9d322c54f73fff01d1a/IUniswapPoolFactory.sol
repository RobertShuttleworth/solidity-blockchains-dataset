// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IUniswapPoolFactory {
    
    struct PoolsUniswap {
        address owner;
        address poolAddress;
    }
   
    enum EventType { Decrease, Collect }

    function emitPoolEvent(EventType eventType, uint256 balance, address owner) external;
    //function NFTContract() external view returns (address);
    function getPoolByOwner(address _owner) external view returns (address);
    function getOwnerByPool(address _pool) external view returns (address);
    //function getPoolLoginId(address poolAddress) external view returns (uint32);
    //function isSubscriptionActive(address _owner) external view returns (bool);

    function getAllowedTokens() external view returns (address[] memory);
}

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function getOwner() external view returns (address);
    function allowance(address _owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}
