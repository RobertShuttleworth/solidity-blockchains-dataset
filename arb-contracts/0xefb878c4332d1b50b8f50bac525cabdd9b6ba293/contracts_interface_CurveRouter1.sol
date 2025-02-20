// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ICurveRouter {
    function get_dy(
        address[11] calldata _route,
        uint256[5][5] calldata _swap_params,
        uint256 _amount
    ) external view returns (uint256);

    function exchange(
        address[11] calldata _route,
        uint256[5][5] calldata _swap_params,
        uint256 _amount,
        uint256 _min_dy
    ) external returns (uint256);
}