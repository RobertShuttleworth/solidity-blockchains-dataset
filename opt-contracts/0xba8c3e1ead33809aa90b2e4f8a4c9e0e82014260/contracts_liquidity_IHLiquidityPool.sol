// @author Daosourced
// @date January 30, 2023
pragma solidity ^0.8.0;
import {ILiquidityPool} from './contracts_liquidity_ILiquidityPool.sol';
import {IExchange} from './contracts_liquidity_IExchange.sol'; 

interface IHLiquidityPool is IExchange {
    struct HLiquidityPoolData {
        string name;
        address proxyAddress;
        address token;
        uint256 balance;
        uint256 tokenBalance;
    }
} 
