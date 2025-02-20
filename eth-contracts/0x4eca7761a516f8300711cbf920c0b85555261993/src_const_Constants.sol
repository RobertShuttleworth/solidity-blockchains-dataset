// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

library Constants {
    address constant DEAD_ADDR = 0x000000000000000000000000000000000000dEaD;
    address constant PHOENIX_TITANX_STAKE = 0x6B59b8E9635909B7f0FF2C577BB15c936f32619A;
    address constant POOL_AND_BURN = 0x4da2EbDd129AdABc371297e4F651586B3691490B;
    address constant GENESIS = 0xa1a0834f21f88736827e8382DC9fC9786187f20d;
    address constant GENESIS_2 = 0x0a71b0F495948C4b3C3b9D0ADa939681BfBEEf30;
    address constant LP_WALLET = 0xA4A55205a4649b070EbD6c8D2ECE4442C8BdED2b;
    address constant LIQUIDITY_BONDING = 0xD37b9513115e86304de1F98c1A11E3319193A13b;
    address constant OWNER = 0xD37b9513115e86304de1F98c1A11E3319193A13b;
    address constant INFERNO_BNB_V2 = 0xa793016303Fc4E0b575e3D09173F351e11c801EC;

    uint64 constant WAD = 1e18;

    uint64 constant INCENTIVE_FEE = 0.015e18; //1.5%

    uint64 constant DEFAULT_INCENTIVE = 0.01e18; //1%

    ///@dev  The initial titan x amount needed to create liquidity pool
    uint256 constant INITIAL_TITAN_X_FOR_TITANX_GOATX = 5_000_000_000e18;
    uint256 constant INITIAL_TITANX_SENT_TO_LP = 10_000_000_000e18;

    ///@dev The intial GOATX that pairs with the TitanX received from the swap
    uint256 constant INITIAL_GOATX_FOR_LP = 2_500_000_000e18;

    uint24 constant POOL_FEE = 10_000; //1%

    int24 constant TICK_SPACING = 200; // Uniswap's tick spacing for 1% pools is 200

    uint128 constant MINTING_CAP_PER_CYCLE = 288_000_000_000e18;

    uint64 constant GOAT_FEED_DISTRO = 0.08e18; // 8%
    uint32 constant MINTING_CYCLE_DURATION = 24 hours;
    uint32 constant MINTING_CYCLE_GAP = 24 hours;
    uint8 constant MAX_MINT_CYCLE = 14;
    uint64 constant MINTING_STARTING_RATIO = 1e18;
}