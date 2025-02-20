// SPDX-License-Identifier: MIT
pragma solidity =0.8.23;

enum CurvePoolType {
    CURVE_STABLE_SWAP_NG,
    CURVE_TWO_CRYPTO_OPTIMIZED
}
/// @title ICurvePool
/// @notice Defines the basic interface for Curve Pool contract.

interface ICurvePool {
    function coins(uint256 i) external view returns (address);

    function exchange(
        int128 i,
        int128 j,
        uint256 _dx,
        uint256 _min_dy,
        address _receiver
    )
        external
        returns (uint256);

    function add_liquidity(
        uint256[] memory amounts,
        uint256 _min_mint_amount,
        address _receiver
    )
        external
        returns (uint256);

    function add_liquidity(
        uint256[2] memory amounts,
        uint256 _min_mint_amount,
        address _receiver
    )
        external
        returns (uint256);

    function remove_liquidity_one_coin(
        uint256 _burn_amount,
        int128 i,
        uint256 _min_received,
        address _receiver
    )
        external
        returns (uint256);
}