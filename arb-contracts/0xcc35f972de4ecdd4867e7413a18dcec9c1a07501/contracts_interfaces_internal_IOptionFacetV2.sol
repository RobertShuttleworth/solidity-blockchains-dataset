// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
import {IOptionFacet} from "./contracts_interfaces_internal_IOptionFacet.sol";
interface IOptionFacetV2 {
    enum PremiumOracleType {
        PAMMS,
        AMMS
    }
    struct ManagedOptionsSettings {
        bool isOpen;
        IOptionFacet.OrderType orderType;
        address writer;
        address lockAsset;
        address underlyingAsset;
        IOptionFacet.UnderlyingAssetType lockAssetType;
        uint256 underlyingNftID;
        IOptionFacet.LiquidateMode liquidateMode;
        address strikeAsset;
        uint256 maximum;
        PremiumOracleType  premiumOracleType;  
        address[] premiumAssets;
        uint64[] productTypes;
        uint256[] premiumFloorAMMs; 
        uint256[] premiumRates;
        uint256 maxUnderlyingAssetAmount;
        uint256 minUnderlyingAssetAmount;
        uint256 minQuantity;
        uint256 offerID;
    }
    struct OptionExtra {
        uint64 productType;
        uint8  optionSourceType; //todo 
        bool   liquidationToEOA; //todo   
    }
    event SetOptionExtra(uint64 _orderID, OptionExtra _data);
    event SetManagedOptionsSettings(ManagedOptionsSettings[]set, address _vault,uint256[]  _delIndex);
    function setOptionExtraData(uint64 _orderID, OptionExtra memory _data)external;
    function getOptionExtraData(uint64  _orderID)external view returns(OptionExtra memory _data);
    function getManagedOptionsSettings(address _vault) external view returns(IOptionFacetV2.ManagedOptionsSettings[] memory set);
    function getManagedOptionsSettingsByIndex(address _vault,uint256 index) external view returns(IOptionFacetV2.ManagedOptionsSettings memory set);
    function setManagedOptionsSettings(ManagedOptionsSettings[] memory set, address _vault,uint256[] memory _delIndex) external;
}