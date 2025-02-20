// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import "./openzeppelin_contracts_token_ERC721_IERC721.sol";

interface IIronballStorage {
    // Events
    event FeeCollectorUpdated(address feeCollector);
    event ProtocolFeeUpdated(uint256 protocolFee);
    event BoostPriceUpdated(uint256 boostPrice);
    event NFTContractAddressUpdated(address NFTContractAddress);
    event MaxBoostsPerAddressPerCollectionUpdated(uint256 maxBoostsPerAddressPerCollection);
    event FactoryAdded(address factoryAddress);
    event CollectionAdded(address collectionAddress);

    // Function signatures
    function addCollection(address _collectionAddress) external;
    function addFactory(address _factoryAddress) external;
    function updateFeeCollector(address _feeCollector) external;
    function updateProtocolFee(uint256 _protocolFee) external;
    function updateBoostPrice(uint256 _boostPrice) external;
    function updateNFTContractAddress(address _NFTContractAddress) external;
    function updateMaxBoostsPerAddressPerCollection(uint256 _maxBoostsPerAddressPerCollection) external;
    function ccipSender() external view returns (address);
    function ccipReceiver() external view returns (address);
    // Public and external variable getters
    function whitelistSigner() external view returns (address);
    function lidomanager() external view returns (address);
    function stETH() external view returns (address);
    function keyBenefit() external view returns (bool);
    function keyHolderPriorityTime() external view returns (uint256);
    function keyHolderfeeDiscountFactor() external view returns (uint256);

    function feeCollector() external view returns (address);
    function blastPointsOperator() external view returns (address);
    function protocolFee() external view returns (uint256);
    function protocolFeeMarketPlace() external view returns (uint256);
    function referrerFee() external view returns (uint256);
    function boostPrice() external view returns (uint256);
    function NFTContractAddress() external view returns (address);
    function maxBoostsPerAddressPerCollection() external view returns (uint256);
    function isCollection(address) external view returns (bool);
    function isFactory(address) external view returns (bool);
    function validateTransfer(address,address,address) external view returns (bool);
    function royaltyInfo(uint256 tokenId, uint256 salePrice) external view returns (address receiver, uint256 royaltyAmount);
    function generateTokenURI(
        uint256 tokenId,
        string memory baseURI,
        string memory preRevealImageURI,
        string memory name,
        uint256 lockValue,
        uint256 lockUnlockTime,
        uint256 upgradedAtTime,
        address contractAddress
    ) external pure returns (string memory);
}