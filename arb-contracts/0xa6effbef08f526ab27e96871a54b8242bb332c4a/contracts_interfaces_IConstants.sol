// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IConstants {
    /// @dev Uniswap v3 Related
    function UNISWAP_V3_FACTORY_ADDRESS() external view returns (address);
    function NONFUNGIBLE_POSITION_MANAGER_ADDRESS() external view returns (address);
    function SWAP_ROUTER_ADDRESS() external view returns (address);

    /// @dev Distribute reward token address
    function DISTRIBUTE_REWARD_ADDRESS() external view returns (address);

    /// @dev Token address (combine each chain)
    function WETH_ADDRESS() external view returns (address);
    function WBTC_ADDRESS() external view returns (address);
    function ARB_ADDRESS() external view returns (address);
    function USDC_ADDRESS() external view returns (address);
    function USDCE_ADDRESS() external view returns (address);
    function USDT_ADDRESS() external view returns (address);
    function RDNT_ADDRESS() external view returns (address);
    function LINK_ADDRESS() external view returns (address);
    function DEGEN_ADDRESS() external view returns (address);
    function BRETT_ADDRESS() external view returns (address);
    function TOSHI_ADDRESS() external view returns (address);
    function CIRCLE_ADDRESS() external view returns (address);
    function ROOST_ADDRESS() external view returns (address);
    function AERO_ADDRESS() external view returns (address);
    function INT_ADDRESS() external view returns (address);
    function HIGHER_ADDRESS() external view returns (address);
    function KEYCAT_ADDRESS() external view returns (address);

    /// @dev Black hole address
    function BLACK_HOLE_ADDRESS() external view returns (address);
}