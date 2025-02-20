// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
import {IOptionFacet} from "./contracts_interfaces_internal_IOptionFacet.sol";

interface IOptionService {
    struct VerifyOrder {
        address holder;
        IOptionFacet.LiquidateMode liquidateMode;
        address writer;
        IOptionFacet.UnderlyingAssetType lockAssetType;
        address recipient;
        address lockAsset;
        address strikeAsset;
        uint256 lockAmount;
        uint256 strikeAmount;
        uint256 expirationDate;
        uint256 lockDate;
        uint256 underlyingNftID;
        uint256 writerType;
        uint256 holderType;
        uint256 quantity;
    }
    function createPutOrder(
        IOptionFacet.PutOrder memory _putOrder
    ) external;
     function createCallOrder(
        IOptionFacet.CallOrder memory _callOrder
    ) external;
    function getParts(uint256 quantity,uint256 strikeAmount)  external view returns(uint256);
    enum LiquidateType {
        NotExercising,
        Exercising,
        ProfitTaking
    }
    struct LiquidateResult{
        uint amount;
        uint strikeAssetPrice;
        uint lockAssetPrice;
    }
    event LiquidateOption(
        IOptionFacet.OrderType _orderType,
        uint64 _orderID,
        LiquidateType _type,
        uint64 _index,
        LiquidateResult _result
    );
    struct LiquidateParams {
        IOptionFacet.OrderType _orderType;
        uint64 _orderID;
        LiquidateType _type;
        uint64 _index;
        bytes[]  lockAssetPricData;
        bytes[]  strikeAssetPricData;
    }
    function liquidateOption(
        LiquidateParams memory _params
    ) external payable ;
}