pragma solidity ^0.8.21;
pragma experimental ABIEncoderV2;

import {BigMathMinified} from "./contracts_payloads_libraries_bigMathMinified.sol";
import {LiquidityCalcs} from "./contracts_payloads_libraries_liquidityCalcs.sol";
import {LiquiditySlotsLink} from "./contracts_payloads_libraries_liquiditySlotsLink.sol";

import {IGovernorBravo} from "./contracts_payloads_common_interfaces_IGovernorBravo.sol";
import {ITimelock} from "./contracts_payloads_common_interfaces_ITimelock.sol";

import {IFluidLiquidityAdmin, AdminModuleStructs as FluidLiquidityAdminStructs} from "./contracts_payloads_common_interfaces_IFluidLiquidity.sol";
import {IFluidReserveContract} from "./contracts_payloads_common_interfaces_IFluidReserveContract.sol";

import {IFluidVaultFactory} from "./contracts_payloads_common_interfaces_IFluidVaultFactory.sol";
import {IFluidDexFactory} from "./contracts_payloads_common_interfaces_IFluidDexFactory.sol";

import {IFluidDex, IFluidAdminDex, IFluidDexResolver} from "./contracts_payloads_common_interfaces_IFluidDex.sol";

import {IFluidVault, IFluidVaultT1} from "./contracts_payloads_common_interfaces_IFluidVault.sol";

import {IFTokenAdmin, ILendingRewards} from "./contracts_payloads_common_interfaces_IFToken.sol";

import {IDSAV2} from "./contracts_payloads_common_interfaces_IDSA.sol";
import {IERC20} from "./contracts_payloads_common_interfaces_IERC20.sol";
import {IProxy} from "./contracts_payloads_common_interfaces_IProxy.sol";
import {PayloadIGPConstants} from "./contracts_payloads_common_constants.sol";
import {PayloadIGPHelpers} from "./contracts_payloads_common_helpers.sol";

contract PayloadIGP71 is PayloadIGPConstants, PayloadIGPHelpers {
    uint256 public constant PROPOSAL_ID = 71;

    function propose(string memory description) external {
        require(
            msg.sender == PROPOSER ||
                msg.sender == TEAM_MULTISIG ||
                address(this) == PROPOSER_AVO_MULTISIG ||
                address(this) == PROPOSER_AVO_MULTISIG_2 ||
                address(this) == PROPOSER_AVO_MULTISIG_3 ||
                address(this) == PROPOSER_AVO_MULTISIG_4 ||
                address(this) == PROPOSER_AVO_MULTISIG_5,
            "msg.sender-not-allowed"
        );

        uint256 totalActions = 1;
        address[] memory targets = new address[](totalActions);
        uint256[] memory values = new uint256[](totalActions);
        string[] memory signatures = new string[](totalActions);
        bytes[] memory calldatas = new bytes[](totalActions);

        targets[0] = address(TIMELOCK);
        values[0] = 0;
        signatures[0] = "executePayload(address,string,bytes)";
        calldatas[0] = abi.encode(ADDRESS_THIS, "execute()", abi.encode());

        uint256 proposedId = GOVERNOR.propose(
            targets,
            values,
            signatures,
            calldatas,
            description
        );

        require(proposedId == PROPOSAL_ID, "PROPOSAL_IS_NOT_SAME");
    }

    function execute() external {
        require(address(this) == address(TIMELOCK), "not-valid-caller");

        // Action 1: Increase Allowance of stETH redemption protocol
        action1();
    }

    function verifyProposal() external view {}

    /**
     * |
     * |     Proposal Payload Actions      |
     * |__________________________________
     */

    /// @notice Action 1: Increase Allowance of stETH redemption protocol
    function action1() internal {
        {
            uint256 exchangePriceAndConfig_ = LIQUIDITY.readFromStorage(
                LiquiditySlotsLink.calculateMappingStorageSlot(
                    LiquiditySlotsLink.LIQUIDITY_EXCHANGE_PRICES_MAPPING_SLOT,
                    ETH_ADDRESS
                )
            );

            (
                uint256 supplyExchangePrice,
                uint256 borrowExchangePrice
            ) = LiquidityCalcs.calcExchangePrices(exchangePriceAndConfig_);

            uint256 amount_ = (10_000 * 1e18 * 1e12) / borrowExchangePrice;

            // Borrow Limits
            FluidLiquidityAdminStructs.UserBorrowConfig[]
                memory configs_ = new FluidLiquidityAdminStructs.UserBorrowConfig[](
                    1
                );

            configs_[0] = FluidLiquidityAdminStructs.UserBorrowConfig({
                user: address(0x1F6B2bFDd5D1e6AdE7B17027ff5300419a56Ad6b),
                token: ETH_ADDRESS,
                mode: 1,
                expandPercent: 0,
                expandDuration: 1,
                baseDebtCeiling: amount_,
                maxDebtCeiling: (amount_ * 1001) / 1000
            });

            LIQUIDITY.updateUserBorrowConfigs(configs_);
        }
    }
}