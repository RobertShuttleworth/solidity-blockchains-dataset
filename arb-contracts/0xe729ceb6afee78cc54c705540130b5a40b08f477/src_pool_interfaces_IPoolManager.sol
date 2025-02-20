// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;
import {PoolInfo} from "./src_lib_Types.sol";

/// @title The base contract for an NFT/TOKEN AMM pair
/// @author Liqui-devil
/// @notice This implements the core swap logic from NFT to TOKEN
interface IPoolManager {
    function initialize(
        PoolInfo.InitPoolParams calldata initPoolParams,
        address _lpfToken,
        address _lpnToken
    ) external;

    function addRemoveReserveNft(uint128 sumRarity, uint8 isAdded) external;

    function updatePoolParams(
        uint128[] memory _newCurveAttributes,
        uint256 fee,
        uint8 isFeeAdded
    ) external;

    /**
        @notice Returns the address that assets that receives assets when a swap is done with this pair
        Can be set to another address by the owner, if set to address(0), defaults to the pair's own address
     */
    function getRoyaltyReciever()
        external
        view
        returns (address payable _royaltyReciever);

    function getCurveAttributes() external view returns (uint128[] memory);

    function poolFeeMultiplier() external view returns (uint96);

    function royaltyFeeMultiplier() external view returns (uint96);

    function poolReservesNft() external view returns (uint128);

    function isVariableDelta() external view returns (uint8);

    function poolFeeAccrued() external view returns (uint256);

    /**
        @notice Updates the delta parameter. Only callable by the owner.
        @param _newCurveAttributes New paremeters for curve under use by this pool
        Warning Note: using this function will result in changing trade prices. 
     */
    function changeCurveAttributes(
        uint128[] memory _newCurveAttributes
    ) external;

    /**
        @notice Updates the fee taken by the LP. Only callable by the owner.
        Only callable if the pool is a Trade pool. Reverts if the fee is >=
        MAX_FEE.
        @param newFee The new LP fee percentage, 18 decimals
     */
    function changeFee(uint96 newFee) external;

    /**
        @notice Changes the address that will receive assets received from
        trades. Only callable by the owner.
        @param newRecipient The new asset recipient
     */
    function changeRoyaltyReciever(address payable newRecipient) external;

    /**
        @notice The sum of LPF and LPN minted so far.
        @param amountLp Total amount of LPF + LPN supply
     */
    function totalLp() external view returns (uint256 amountLp);

    /**
        @notice Allows the pair to make arbitrary external calls to contracts
        whitelisted by the protocol. Only callable by the owner.
        @param target The contract to call
        @param data The calldata to pass to the contract
     */
    function call(address payable target, bytes calldata data) external;

    /**
        @notice Allows owner to batch multiple calls, forked from: https://github.com/boringcrypto/BoringSolidity/blob/master/contracts/BoringBatchable.sol 
        @dev Intended for withdrawing/altering pool pricing in one tx, only callable by owner, cannot change owner
        @param calls The calldata for each call to make
        @param revertOnFail Whether or not to revert the entire tx if any of the calls fail
     */
    function multicall(bytes[] calldata calls, bool revertOnFail) external;

    function mintLpf(address recipient, uint256 tokenAmount) external;

    function mintLpn(address recipient, uint256 lpnIssued) external;

    function burnLpf(address wallet, uint256 tokenAmount) external;

    function burnLpn(address wallet, uint256 tokenAmount) external;

    function is721Contract(address nft) external view returns (bool);

    function is1155Contract(address nft) external view returns (bool);
}