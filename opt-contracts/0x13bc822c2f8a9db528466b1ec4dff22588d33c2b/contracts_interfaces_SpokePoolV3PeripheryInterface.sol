//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import { IERC20 } from "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import { IERC20Permit } from "./openzeppelin_contracts_token_ERC20_extensions_IERC20Permit.sol";
import { IERC20Auth } from "./contracts_external_interfaces_IERC20Auth.sol";
import { SpokePoolV3Periphery } from "./contracts_SpokePoolV3Periphery.sol";
import { PeripherySigningLib } from "./contracts_libraries_PeripherySigningLib.sol";
import { IPermit2 } from "./contracts_external_interfaces_IPermit2.sol";

interface SpokePoolV3PeripheryProxyInterface {
    function swapAndBridge(SpokePoolV3PeripheryInterface.SwapAndDepositData calldata swapAndDepositData) external;
}

/**
 * @title SpokePoolV3Periphery
 * @notice Contract for performing more complex interactions with an Across spoke pool deployment.
 * @dev Variables which may be immutable are not marked as immutable, nor defined in the constructor, so that this
 * contract may be deployed deterministically at the same address across different networks.
 * @custom:security-contact bugs@across.to
 */
interface SpokePoolV3PeripheryInterface {
    // Enum describing the method of transferring tokens to an exchange.
    enum TransferType {
        // Approve the exchange so that it may transfer tokens from this contract.
        Approval,
        // Transfer tokens to the exchange before calling it in this contract.
        Transfer,
        // Approve the exchange by authorizing a transfer with Permit2.
        Permit2Approval
    }

    // Submission fees can be set by user to pay whoever submits the transaction in a gasless flow.
    // These are assumed to be in the same currency that is input into the contract.
    struct Fees {
        // Amount of fees to pay recipient for submitting transaction.
        uint256 amount;
        // Recipient of fees amount.
        address recipient;
    }

    // Params we'll need caller to pass in to specify an Across Deposit. The input token will be swapped into first
    // before submitting a bridge deposit, which is why we don't include the input token amount as it is not known
    // until after the swap.
    struct BaseDepositData {
        // Token deposited on origin chain.
        address inputToken;
        // Token received on destination chain.
        address outputToken;
        // Amount of output token to be received by recipient.
        uint256 outputAmount;
        // The account credited with deposit who can submit speedups to the Across deposit.
        address depositor;
        // The account that will receive the output token on the destination chain. If the output token is
        // wrapped native token, then if this is an EOA then they will receive native token on the destination
        // chain and if this is a contract then they will receive an ERC20.
        address recipient;
        // The destination chain identifier.
        uint256 destinationChainId;
        // The account that can exclusively fill the deposit before the exclusivity parameter.
        address exclusiveRelayer;
        // Timestamp of the deposit used by system to charge fees. Must be within short window of time into the past
        // relative to this chain's current time or deposit will revert.
        uint32 quoteTimestamp;
        // The timestamp on the destination chain after which this deposit can no longer be filled.
        uint32 fillDeadline;
        // The timestamp or offset on the destination chain after which anyone can fill the deposit. A detailed description on
        // how the parameter is interpreted by the V3 spoke pool can be found at https://github.com/across-protocol/contracts/blob/fa67f5e97eabade68c67127f2261c2d44d9b007e/contracts/SpokePool.sol#L476
        uint32 exclusivityParameter;
        // Data that is forwarded to the recipient if the recipient is a contract.
        bytes message;
    }

    // Minimum amount of parameters needed to perform a swap on an exchange specified. We include information beyond just the router calldata
    // and exchange address so that we may ensure that the swap was performed properly.
    struct SwapAndDepositData {
        // Amount of fees to pay for submitting transaction. Unused in gasful flows.
        Fees submissionFees;
        // Deposit data to use when interacting with the Across spoke pool.
        BaseDepositData depositData;
        // Token to swap.
        address swapToken;
        // Address of the exchange to use in the swap.
        address exchange;
        // Method of transferring tokens to the exchange.
        TransferType transferType;
        // Amount of the token to swap on the exchange.
        uint256 swapTokenAmount;
        // Minimum output amount of the exchange, and, by extension, the minimum required amount to deposit into an Across spoke pool.
        uint256 minExpectedInputTokenAmount;
        // The calldata to use when calling the exchange.
        bytes routerCalldata;
    }

    // Extended deposit data to be used specifically for signing off on periphery deposits.
    struct DepositData {
        // Amount of fees to pay for submitting transaction. Unused in gasful flows.
        Fees submissionFees;
        // Deposit data describing the parameters for the V3 Across deposit.
        BaseDepositData baseDepositData;
        // The precise input amount to deposit into the spoke pool.
        uint256 inputAmount;
    }

    function deposit(
        address recipient,
        address inputToken,
        uint256 inputAmount,
        uint256 outputAmount,
        uint256 destinationChainId,
        address exclusiveRelayer,
        uint32 quoteTimestamp,
        uint32 fillDeadline,
        uint32 exclusivityParameter,
        bytes memory message
    ) external payable;

    function swapAndBridge(SwapAndDepositData calldata swapAndDepositData) external payable;

    function swapAndBridgeWithPermit(
        address signatureOwner,
        SwapAndDepositData calldata swapAndDepositData,
        uint256 deadline,
        bytes calldata permitSignature,
        bytes calldata swapAndDepositDataSignature
    ) external;

    function swapAndBridgeWithPermit2(
        address signatureOwner,
        SwapAndDepositData calldata swapAndDepositData,
        IPermit2.PermitTransferFrom calldata permit,
        bytes calldata signature
    ) external;

    function swapAndBridgeWithAuthorization(
        address signatureOwner,
        SwapAndDepositData calldata swapAndDepositData,
        uint256 validAfter,
        uint256 validBefore,
        bytes32 nonce,
        bytes calldata receiveWithAuthSignature,
        bytes calldata swapAndDepositDataSignature
    ) external;

    function depositWithPermit(
        address signatureOwner,
        DepositData calldata depositData,
        uint256 deadline,
        bytes calldata permitSignature,
        bytes calldata depositDataSignature
    ) external;

    function depositWithPermit2(
        address signatureOwner,
        DepositData calldata depositData,
        IPermit2.PermitTransferFrom calldata permit,
        bytes calldata signature
    ) external;

    function depositWithAuthorization(
        address signatureOwner,
        DepositData calldata depositData,
        uint256 validAfter,
        uint256 validBefore,
        bytes32 nonce,
        bytes calldata receiveWithAuthSignature,
        bytes calldata depositDataSignature
    ) external;
}