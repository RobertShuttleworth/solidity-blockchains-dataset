// SPDX-License-Identifier: None
pragma solidity ^0.8.18;

interface IOptionLiquidityRouter {
    error LOK();
    error notOwner();
    error notEnoughAmountForMint();
    error IncorrectPercentValue();
    
    struct BatchMintInfo{
        address owner;
        uint256 expiry; 
        int256 tickLowerPercent;
        int256 tickUpperPercent;
    }
    function getOutOfMoneyPools(uint256 expiry, bool isCall) external view returns (bytes32[] memory, uint256[] memory);
    
}