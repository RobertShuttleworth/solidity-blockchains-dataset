// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

interface IOptionFacet {
    enum OrderType {
        Call,
        Put
    }
    enum CollateralNftType {
        Default,
        UniswapV3
    }
    enum UnderlyingAssetType {
        Original,
        Token,
        Nft
    }

    enum LiquidateMode {
        Both,
        ProfitSettlement,
        PhysicalDelivery
    }

    struct PutOrder {
        address holder;
        LiquidateMode liquidateMode;
        address writer;
        UnderlyingAssetType lockAssetType;
        address recipient;
        address lockAsset;
        address underlyingAsset;
        address strikeAsset;
        uint256 lockAmount;
        uint256 strikeAmount;
        uint256 expirationDate;
        uint256 lockDate;
        uint256 underlyingNftID;
        uint256 quantity;
    }

    struct CallOrder {
        address holder;
        LiquidateMode liquidateMode;
        address writer;
        UnderlyingAssetType lockAssetType;
        address recipient;
        address lockAsset;
        address underlyingAsset;
        address strikeAsset;
        uint256 lockAmount;
        uint256 strikeAmount;
        uint256 expirationDate;
        uint256 lockDate;
        uint256 underlyingNftID;
        uint256 quantity;
    }

    //---event---
    event SetOrderId(uint64 _orderId);
    event AddPutOrder(uint64 _orderId, PutOrder _putOrder,address _holderWallet,address _writerWallet);
    event DeletePutOrder(uint64 _orderId,PutOrder _putOrder);
    event AddCallOrder(uint64 _orderId, CallOrder _callOrder,address _holderWallet,address _writerWallet);
    event DeleteCallOrder(uint64 _orderId,CallOrder _callOrder);
    event SetDomain(
        string _name,
        string _version,
        address _contract,
        bytes32 _domain
    );
    event SetFeeRecipient(address _feeRecipient);
    event SetNftType(address _nft, CollateralNftType _type);
    event SetFeeRate(uint256 _feeRate);
    event SetSigatureLock(address _vault,OrderType _orderType,address _underlyingAsset, uint256 _timestamp);
    event SetUnderlyTotal(address _vault,OrderType _orderType,address _underlyingAsset, uint256 _total);
    //---put---
    function addPutOrder(uint64 _orderId, PutOrder memory _putOrder) external;

    function deletePutOrder(uint64 _orderId) external;

    function getPutOrder(
        uint64 _orderId
    ) external view returns (PutOrder memory);

    function getHolderPuts(
        address _holder
    ) external view returns (uint64[] memory);

    function getWriterPuts(
        address _writer
    ) external view returns (uint64[] memory);

    //---call---
    function addCallOrder(
        uint64 _orderId,
        CallOrder memory _callOrder
    ) external;

    function deleteCallOrder(uint64 _orderId) external;

    function getCallOrder(
        uint64 _orderId
    ) external view returns (CallOrder memory);

    function getHolderCalls(
        address _holder
    ) external view returns (uint64[] memory);

    function getWriterCalls(
        address _writer
    ) external view returns (uint64[] memory);

    //---other----
    function getOrderId() external view returns(uint64);
    function setOrderId() external;
    function getFeeRecipient() external view returns (address);

    function setFeeRecipient(address _feeRecipient) external;

    function setFeeRate(uint256 _feeRate) external;

    function getFeeRate() external view returns (uint256);

    function setNftType(address _nft, CollateralNftType _type) external;

    function getNftType(address _nft) external view returns (CollateralNftType);

    //----safe verify----
    function getDomain() external view returns (bytes32);

    function setDomain(
        string memory _name,
        string memory _version,
        address _contract
    ) external;


}