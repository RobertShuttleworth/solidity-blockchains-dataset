pragma solidity ^0.8.21;
pragma experimental ABIEncoderV2;

import {BigMathMinified} from "./contracts_payloads_libraries_bigMathMinified.sol";
import {LiquidityCalcs} from "./contracts_payloads_libraries_liquidityCalcs.sol";
import {LiquiditySlotsLink} from "./contracts_payloads_libraries_liquiditySlotsLink.sol";

import { IGovernorBravo } from "./contracts_payloads_common_interfaces_IGovernorBravo.sol";
import { ITimelock } from "./contracts_payloads_common_interfaces_ITimelock.sol";

import { IFluidLiquidityAdmin } from "./contracts_payloads_common_interfaces_IFluidLiquidity.sol";
import { IFluidReserveContract } from "./contracts_payloads_common_interfaces_IFluidReserveContract.sol";

import { IFluidVaultFactory } from "./contracts_payloads_common_interfaces_IFluidVaultFactory.sol";
import { IFluidDexFactory } from "./contracts_payloads_common_interfaces_IFluidDexFactory.sol";

import { IFluidDex } from "./contracts_payloads_common_interfaces_IFluidDex.sol";
import { IFluidDexResolver } from "./contracts_payloads_common_interfaces_IFluidDex.sol";

import { IFluidVault } from "./contracts_payloads_common_interfaces_IFluidVault.sol";
import { IFluidVaultT1 } from "./contracts_payloads_common_interfaces_IFluidVault.sol";

import { IFTokenAdmin } from "./contracts_payloads_common_interfaces_IFToken.sol";
import { ILendingRewards } from "./contracts_payloads_common_interfaces_IFToken.sol";

import { IDSAV2 } from "./contracts_payloads_common_interfaces_IDSA.sol";

import { ILite } from "./contracts_payloads_common_interfaces_ILite.sol";


contract PayloadIGPConstants {
    address public immutable ADDRESS_THIS;

    // Proposal Creators
    address public constant PROPOSER =
        0xA45f7bD6A5Ff45D31aaCE6bCD3d426D9328cea01;
    address public constant PROPOSER_AVO_MULTISIG =
        0x059A94A72951c0ae1cc1CE3BF0dB52421bbE8210;
    address public constant PROPOSER_AVO_MULTISIG_2 =
        0x9efdE135CA4832AbF0408c44c6f5f370eB0f35e8;
    address public constant PROPOSER_AVO_MULTISIG_3 =
        0x5C43AAC965ff230AC1cF63e924D0153291D78BaD;
    address public constant PROPOSER_AVO_MULTISIG_4 =
        0x3dAff61fe5cfB1f1B4eA7FBa8173A58532Ef1841;
    address public constant PROPOSER_AVO_MULTISIG_5 =
        0xE7EB63a8B6392481A9FDEbb108Cfd580DC8664d3;

    // Governance Addresses
    IGovernorBravo public constant GOVERNOR =
        IGovernorBravo(0x0204Cd037B2ec03605CFdFe482D8e257C765fA1B);
    ITimelock public constant TIMELOCK =
        ITimelock(0x2386DC45AdDed673317eF068992F19421B481F4c);
    IDSAV2 public constant TREASURY = IDSAV2(0x28849D2b63fA8D361e5fc15cB8aBB13019884d09);

    // Team Multisig
    address public constant TEAM_MULTISIG =
        0x4F6F977aCDD1177DCD81aB83074855EcB9C2D49e;

    // Fluid Addresses
    IFluidLiquidityAdmin public constant LIQUIDITY =
        IFluidLiquidityAdmin(0x52Aa899454998Be5b000Ad077a46Bbe360F4e497);
    IFluidReserveContract public constant FLUID_RESERVE =
        IFluidReserveContract(0x264786EF916af64a1DB19F513F24a3681734ce92);


    // Fluid Factory Addresses
    IFluidVaultFactory public constant VAULT_FACTORY =
        IFluidVaultFactory(0x324c5Dc1fC42c7a4D43d92df1eBA58a54d13Bf2d);
    IFluidDexFactory public constant DEX_FACTORY =
        IFluidDexFactory(0x91716C4EDA1Fb55e84Bf8b4c7085f84285c19085);

    
    ILite public constant IETHV2 =
        ILite(0xA0D3707c569ff8C87FA923d3823eC5D81c98Be78);


    // Tokens
    address internal constant ETH_ADDRESS =
        0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address internal constant wstETH_ADDRESS =
        0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address internal constant weETH_ADDRESS =
        0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee;
    address internal constant rsETH_ADDRESS =
        0xA1290d69c65A6Fe4DF752f95823fae25cB99e5A7;
    address internal constant weETHs_ADDRESS =
        0x917ceE801a67f933F2e6b33fC0cD1ED2d5909D88;
    address internal constant mETH_ADDRESS =
        0xd5F7838F5C461fefF7FE49ea5ebaF7728bB0ADfa;

    address internal constant USDC_ADDRESS =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant USDT_ADDRESS =
        0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address internal constant sUSDe_ADDRESS =
        0x9D39A5DE30e57443BfF2A8307A4256c8797A3497;
    address internal constant sUSDs_ADDRESS =
        0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD;
    address internal constant USDe_ADDRESS =
        0x4c9EDD5852cd905f086C759E8383e09bff1E68B3;
    address internal constant GHO_ADDRESS =
        0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f;

    address internal constant WBTC_ADDRESS =
        0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address internal constant cbBTC_ADDRESS =
        0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;

    address internal constant INST_ADDRESS = 
        0x6f40d4A6237C257fff2dB00FA0510DeEECd303eb;

    // fTokens
    address internal constant F_USDT_ADDRESS = 0x5C20B550819128074FD538Edf79791733ccEdd18;
    address internal constant F_USDC_ADDRESS = 0x9Fb7b4477576Fe5B32be4C1843aFB1e55F251B33;
    address internal constant F_WETH_ADDRESS = 0x90551c1795392094FE6D29B758EcCD233cFAa260;
    address internal constant F_GHO_ADDRESS = 0x6A29A46E21C730DcA1d8b23d637c101cec605C5B;

    // Constants
    uint256 internal constant X8 = 0xff;
    uint256 internal constant X10 = 0x3ff;
    uint256 internal constant X14 = 0x3fff;
    uint256 internal constant X15 = 0x7fff;
    uint256 internal constant X16 = 0xffff;
    uint256 internal constant X18 = 0x3ffff;
    uint256 internal constant X24 = 0xffffff;
    uint256 internal constant X64 = 0xffffffffffffffff;

    uint256 internal constant DEFAULT_EXPONENT_SIZE = 8;
    uint256 internal constant DEFAULT_EXPONENT_MASK = 0xff;

    constructor() {
        ADDRESS_THIS = address(this);
    }
}