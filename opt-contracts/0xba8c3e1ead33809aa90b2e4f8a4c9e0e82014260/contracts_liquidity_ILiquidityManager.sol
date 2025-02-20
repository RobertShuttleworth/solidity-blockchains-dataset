// @author Daosourced
// @date January 30, 2023
pragma solidity ^0.8.0;

import './contracts_liquidity_IHLiquidityPool.sol';

/**
* @notice contract interface that contains the function definitions for the Vault Manager in the HDNS ecosystem
*/
interface ILiquidityManager  {
        
    event AddHRewards(address to, uint256 amount);
    
    /**
    * @notice deposits eth into the hashtag vault
    * @param liquidityProxy address of the liquidityPool to deposit to
    */
    function depositToLiquidityPool(address liquidityProxy) external payable;

    /**
    * @notice deposits eth into the hashtag vault
    * @param liquidityProxy address of the liquidityPool to deposit to
    */
    function depositToLiquidityPool(address liquidityProxy, uint256 amount) external;
    
    /**
    * @notice returns hashtag liquidity pool
    */
    function getHLiquidityPool() external view returns (IHLiquidityPool.HLiquidityPoolData memory pooldata);
    
    
    /**
    * @notice returns hashtag liquidity pool
    * @param feeCollector address of the liquidityPool to deposit to
    */
    function setFeeCollector(address feeCollector) external;
    
    /**
    * @notice mints hashtag token rewards directly into an address of choosing
    * @param to address that will receive the tokens
    * @param amount amount of space to mint
    * @dev note that this function respects the vpr set on the hashtag vault
    */
    function mintHTokenReward(address to, uint256 amount) external;

    /**
    * @notice mints htt token reward directly to a list of destined addresses
    * @dev should only apply to htt token
    * @param tos list of addresses that will receive minted tokens
    * @param amounts list of amounts of space to mint
    */
    function mintHTokenRewards(address[] calldata tos, uint256[] calldata amounts) external;
}