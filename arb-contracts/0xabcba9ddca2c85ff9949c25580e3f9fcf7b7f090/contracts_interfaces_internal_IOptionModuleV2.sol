// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
import {IOptionFacetV2} from "./contracts_interfaces_internal_IOptionFacetV2.sol";
import {IOptionFacet} from "./contracts_interfaces_internal_IOptionFacet.sol";
import {IOptionService} from "./contracts_interfaces_internal_IOptionService.sol";
interface IOptionModuleV2 {
     struct SubmitJvaultOrder{
        IOptionFacet.OrderType orderType;  
        address writer;
        IOptionFacet.UnderlyingAssetType lockAssetType;
        address holder;  
        address lockAsset;
        address underlyingAsset;
        uint256 underlyingNftID;
        uint256 lockAmount;
        address strikeAsset;
        uint256 strikeAmount;
        address recipient;
        IOptionFacet.LiquidateMode liquidateMode;
        uint256 expirationDate;
        uint256 lockDate;
        address premiumAsset;
        uint256 premiumFee;
        uint256 quantity;
    }
      struct Signature {
        IOptionFacet.OrderType orderType;
        address writer;
        address lockAsset;
        address underlyingAsset;
        IOptionFacet.UnderlyingAssetType lockAssetType;
        uint256 underlyingNftID;
        uint256 total;
        uint256[] lockAmounts;
        uint256[] expirationDate;
        uint256[] lockDate;
        IOptionFacet.LiquidateMode[] liquidateModes;
        address[] strikeAssets;
        uint256[] strikeAmounts;
        address[] premiumAssets;
        uint256[] premiumRates;
        uint256[] premiumFloors;
    }

    struct LimitOrderInfo{
        address writer;
        uint256 settingsIndex;
        uint256 productTypeIndex;

    }
    struct PremiumOracleSign {
        uint256 id;
        uint256 chainId;
        uint64 productType;
        address optionAsset;
        uint256 strikePrice;
        address strikeAsset;
        uint256 strikeAmount;
        address lockAsset;
        uint256 lockAmount;
        uint256 expireDate;
        uint256 lockDate;
        uint8   optionType;
        address premiumAsset;
        uint256 premiumFee;
        uint256 timestamp;
        bytes[] oracleSign;
    }
    struct ManagedOrder{
        address holder;
        address writer;
        address recipient;
        uint256 quantity;
        uint256 settingsIndex;
        uint256 productTypeIndex;
        uint256 oracleIndex;
        address nftFreeOption;
        PremiumOracleSign premiumSign;
        uint8 optionSourceType;
        bool liquidationToEOA;
        uint256 offerID;
    }
    struct OptionPrice {    
        uint256 id;
        uint256 chainId;
        uint64 productType;
        address optionAsset;
        uint256 strikePrice;
        address strikeAsset;
        uint256 strikeAmount;
        address lockAsset;
        uint256 lockAmount;
        uint256 expireDate;
        uint256 lockDate;
        uint8   optionType;
        address premiumAsset;
        uint256 premiumFee;
        uint256 timestamp;
    }
    event OptionPremiun(uint64 _orderID,ManagedOrder _info,uint256 _premiumAmount,uint256 _freePremiumAmount);
    event SetOracleWhiteList(address _oracleSigner);
    event SetPriceOracle(address _priceOracleModule);
    event SetFeeDiscountWhitlist(address _pool);
    event SetOptionModuleV2Handle(address _hanlde);
    function SubmitManagedOrder(ManagedOrder memory _info) external;
    function handleManagedOrder(ManagedOrder memory _info) external;
    function setManagedOptionsSettings(IOptionFacetV2.ManagedOptionsSettings[] memory _set,address _vault, uint256[] memory _deleteIndex) external;
    function getManagedOptionsSettings(address _vault) external view returns(IOptionFacetV2.ManagedOptionsSettings[] memory);
    function getFeeDiscountWhitlist(address _nft)external view returns(bool);
    function getOracleWhiteList(address _addr)external view returns(bool);
}