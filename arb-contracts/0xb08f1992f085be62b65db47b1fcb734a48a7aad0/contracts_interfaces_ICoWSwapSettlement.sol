pragma solidity 0.8.25;

interface ICoWSwapSettlement {
    function setPreSignature(bytes calldata orderUid, bool signed) external;

    function preSignature(bytes calldata orderUid) external view returns (uint256);
}