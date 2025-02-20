// SPDX-License-Identifier: None
pragma solidity ^0.8.18;

import {LPPosition} from "./contracts_libraries_LPPosition.sol";
interface IBaseAlcorOptionCore {
    error ZeroLiquidity();
    error alreadyMinted();
    error notEntireBurn();
    error notEnoughAmountForMint();
    error notPositionManager();
    error notApprovedComboContract();
    error ownersMismatch();
    error emptyArray();
    
    struct ProtocolSettings {
        uint256 newLiquidityFeeShare;
        uint128 newMinLiquidationAmount;
        uint128 newMinAmountForMint;
        bool isUpdateLiquidationFeeShare; 
        bool isUpdateMinLiquidationAmount; 
        bool isUpdateMinAmountForMint;
    }

    function protocolOwner() external view returns(address);
    function minAmountForMint() external view returns(uint256);
    

    event AlcorMint(
        address indexed owner,
        uint256 amount0Delta,
        uint256 amount1Delta
    );

    event AlcorBurn(
        address indexed owner,
        uint256 amount0ToTransfer,
        uint256 amount1ToTransfer
    );

    event AlcorCollect(
        address indexed owner,
        uint128 amount
    );
    event AlcorWithdraw(uint256 payoutAmount);

    event UpdateMinAmountForMint(uint256 newMinAmountForMint);
    event UpdateMinLiquidationAmount(uint128 newMinLiquidationAmount);
    event UpdateLiquidationFeeShare(uint256 newLiquidationFeeShare);


}