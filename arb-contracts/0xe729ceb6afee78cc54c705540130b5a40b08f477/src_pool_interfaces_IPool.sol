// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;
import {IERC721} from "./openzeppelin_contracts_token_ERC721_IERC721.sol";
import {ICurve} from "./src_bonding-curves_ICurve.sol";
import {IPoolFactoryLike} from "./src_factory_interfaces_IPoolFactoryLike.sol";
import {PoolInfo} from "./src_lib_Types.sol";

/// @title interface for pool functions
interface IPool {
    function owner() external view returns (address);

    /**
        @notice Returns all NFT IDs held by the pool
     */
    function getAllHeldIds() external view returns (uint256[] memory);

    /**
        @notice Returns the pair's variant (NFT is enumerable or not, pair uses ETH or ERC20)
     */
    function pairVariant() external pure returns (IPoolFactoryLike.PoolVariant);

    function factory() external pure returns (IPoolFactoryLike _factory);

    /**
        @notice Returns the type of bonding curve that parameterizes the pair
     */
    function bondingCurve() external pure returns (ICurve _bondingCurve);

    /**
        @notice Returns the NFT collection that parameterizes the pair
     */
    function nft() external pure returns (IERC721 _nft);

    /**
        @notice Returns the pair's type (PUBLIC/PRIVATE)
     */
    function poolType() external pure returns (PoolInfo.PoolType _poolType);

    /**
        @notice Current reserves of pool on both nft and eth/erc20 side
     */
    function getReserves()
        external
        view
        returns (uint256 reserveToken, uint128 reserveNft);
}