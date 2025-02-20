// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

interface IGluedSettings {
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event ExpProtocolFeeUpdated(uint256 newExpProtocolFee);
    event GlueFeeUpdated(uint256 newGlueFee);
    event GlueExpFeeUpdated(uint256 newGlueExpFee);
    event GlueFeeAddressUpdated(address indexed previousGlueFeeAddress, address indexed newGlueFeeAddress);
    event TeamAddressUpdated(address indexed previousTeamAddress, address indexed newTeamAddress);
    event ExpProtocolFeeOwnershipRemoved();
    event GlueOwnershipRemoved();
    event GlueFeeChangeRemoved();
    event GlueExpFeeChangeRemoved();

    function owner() external view returns (address);
    function transferOwnership(address newOwner) external;
    function updateExpProtocolFee(uint256 newExpProtocolFee) external;
    function updateGlueFee(uint256 newGlueFee) external;
    function updateGlueExpFee(uint256 newGlueExpFee) external;
    function setGlueFeeAddress(address newGlueFeeAddress) external;
    function setTeamAddress(address newTeamAddress) external;
    function getTeamAddress() external view returns (address);
    function getGlueFeeAddress() external view returns (address);
    function getExpProtocolFee() external view returns (uint256);
    function getGlueFee() external view returns (uint256);
    function getGlueExpFee() external view returns (uint256);
    function getProtocolFeeInfo() external view returns (uint256, address, address);
    function getExpProtocolFeeInfo() external view returns (uint256, uint256, address, address);
    function renounceOwnership() external;
    function removeExpProtocolFeeOwnership() external;
    function removeGlueOwnership() external;
    function removeGlueFeeReceiverOwnership() external;
    function removeGlueExpFeeOwnership() external;
    function getGlueOwnershipStatus() external view returns (bool, bool, bool, bool);
    function ExpProtocolFee() external view returns (uint256);
    function glueFee() external view returns (uint256);
    function glueExpFee() external view returns (uint256);
    function glueFeeAddress() external view returns (address);
    function teamAddress() external view returns (address);
}
