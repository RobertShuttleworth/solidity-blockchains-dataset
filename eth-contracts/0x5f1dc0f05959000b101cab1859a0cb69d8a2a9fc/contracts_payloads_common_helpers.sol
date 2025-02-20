pragma solidity ^0.8.21;
pragma experimental ABIEncoderV2;

import {BigMathMinified} from "./contracts_payloads_libraries_bigMathMinified.sol";
import {LiquidityCalcs} from "./contracts_payloads_libraries_liquidityCalcs.sol";
import {LiquiditySlotsLink} from "./contracts_payloads_libraries_liquiditySlotsLink.sol";

import { IGovernorBravo } from "./contracts_payloads_common_interfaces_IGovernorBravo.sol";
import { ITimelock } from "./contracts_payloads_common_interfaces_ITimelock.sol";

import { IFluidLiquidityAdmin, AdminModuleStructs as FluidLiquidityAdminStructs } from "./contracts_payloads_common_interfaces_IFluidLiquidity.sol";
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

import { PayloadIGPConstants } from "./contracts_payloads_common_constants.sol";


contract PayloadIGPHelpers is PayloadIGPConstants {
    /**
     * |
     * |     Proposal Payload Helpers      |
     * |__________________________________
     */
    function getVaultAddress(uint256 vaultId_) public view returns (address) {
        return VAULT_FACTORY.getVaultAddress(vaultId_);
    }

    function getDexAddress(uint256 dexId_) public view returns (address) {
        return DEX_FACTORY.getDexAddress(dexId_);
    }

    struct SupplyProtocolConfig {
        address protocol;
        address supplyToken;
        uint256 expandPercent;
        uint256 expandDuration;
        uint256 baseWithdrawalLimitInUSD;
    }

    struct BorrowProtocolConfig {
        address protocol;
        address borrowToken;
        uint256 expandPercent;
        uint256 expandDuration;
        uint256 baseBorrowLimitInUSD;
        uint256 maxBorrowLimitInUSD;
    }

    function setSupplyProtocolLimits(
        SupplyProtocolConfig memory protocolConfig_
    ) internal {
        {
            // Supply Limits
            FluidLiquidityAdminStructs.UserSupplyConfig[]
                memory configs_ = new FluidLiquidityAdminStructs.UserSupplyConfig[](1);

            configs_[0] = FluidLiquidityAdminStructs.UserSupplyConfig({
                user: address(protocolConfig_.protocol),
                token: protocolConfig_.supplyToken,
                mode: 1,
                expandPercent: protocolConfig_.expandPercent,
                expandDuration: protocolConfig_.expandDuration,
                baseWithdrawalLimit: getRawAmount(
                    protocolConfig_.supplyToken,
                    0,
                    protocolConfig_.baseWithdrawalLimitInUSD,
                    true
                )
            });

            LIQUIDITY.updateUserSupplyConfigs(configs_);
        }
    }

    function setBorrowProtocolLimits(
        BorrowProtocolConfig memory protocolConfig_
    ) internal {
        {
            // Borrow Limits
            FluidLiquidityAdminStructs.UserBorrowConfig[]
                memory configs_ = new FluidLiquidityAdminStructs.UserBorrowConfig[](1);

            configs_[0] = FluidLiquidityAdminStructs.UserBorrowConfig({
                user: address(protocolConfig_.protocol),
                token: protocolConfig_.borrowToken,
                mode: 1,
                expandPercent: protocolConfig_.expandPercent,
                expandDuration: protocolConfig_.expandDuration,
                baseDebtCeiling: getRawAmount(
                    protocolConfig_.borrowToken,
                    0,
                    protocolConfig_.baseBorrowLimitInUSD,
                    false
                ),
                maxDebtCeiling: getRawAmount(
                    protocolConfig_.borrowToken,
                    0,
                    protocolConfig_.maxBorrowLimitInUSD,
                    false
                )
            });

            LIQUIDITY.updateUserBorrowConfigs(configs_);
        }
    }

    function getRawAmount(
        address token,
        uint256 amount,
        uint256 amountInUSD,
        bool isSupply
    ) public virtual view returns (uint256) {
        return 0;
    }
}