// SPDX-License-Identifier: GPL-3.0
// Copyright: https://github.com/credit-cooperative/Line-Of-Credit-v2/blob/master/COPYRIGHT.md

pragma solidity ^0.8.25;

import {ISpigotedLine} from "./lib_Line-Of-Credit-v2_contracts_interfaces_ISpigotedLine.sol";
import {BeneficiaryData} from "./lib_Line-Of-Credit-v2_contracts_utils_DiscreteDistribution.sol";
import {IOTC} from "./lib_Line-Of-Credit-v2_contracts_interfaces_IOTC.sol";

interface ISpigot {
    struct Setting {
        uint8 ownerSplit; // x/100 % to Owner, rest to Operator
        bytes4 claimFunction; // function signature on contract to call and claim tokens
        bytes4 transferOwnerFunction; // function signature on contract to call and transfer ownership
    }

    // in BPS 4 decimals  fee = 50 loan amount = 10000 * (50/100)
    struct Fees {
        uint128 swapFee;
        uint128 servicingFee;
    }

    enum FeeTypes {
        SWAP,
        SERVICING
    }

    // Spigot Events
    event AddSpigot(address indexed borrowerContract, uint256 ownerSplit, bytes4 claimFnSig, bytes4 trsfrFnSig);
    event RemoveSpigot(address indexed borrowerContract, address token);
    event UpdateWhitelistFunction(bytes4 indexed func, bool indexed allowed);
    event ClaimTokens(address indexed token, uint256 indexed amount, uint256 operatorTokens, address borrowerContract);
    event ClaimOwnerTokens(address indexed token, uint256 indexed amount, address owner);
    event ClaimOperatorTokens(address indexed token, uint256 indexed amount, address operator);

    // Stakeholder Events
    event UpdateOwner(address indexed newOwner);
    event UpdateOperator(address indexed newOperator);
    event UpdateBorrowerContractSplit(address indexed borrowerContract, uint8 indexed split);
    event RemoveSpigot(address indexed borrowerContract);

    // Errors
    error BadFunction();
    error OperatorFnNotWhitelisted();
    error OperatorFnNotValid();
    error OperatorFnCallFailed();
    error ClaimFailed();
    error NoClaimableTokens();
    error CallerAccessDenied();
    error BadSetting();
    error InvalidBorrowerContract();
    error InsufficientFunds();
    error InvalidToken();
    error LineMustBeDefaultBeneficiary(address beneficiary);
    error BadAddress();
    error BadStatus();

    error AlreadyInitialized();
    error BeneficiaryDebtOutstanding();
    error LineHasActiveCreditPositions(uint256);
    error InvalidSplit();
    error SpigotSettingsExist();
    error TradeFailed();
    error CannotBeZeroAddress();
    error NoTradedTokens();
    error CannotOverpayBeneficiaryDebt();
    error MustRepayWithTradedTokens();
    error CannotClaimBeneficiaryTradedTokens();
    error BadBeneficiary();

    // initialization funcs

    function initializeFromFactory(address _operator, BeneficiaryData memory defaultBeneficiary, address _weth)
        external;

    // ops funcs

    function pullTokens(address borrowerContract, address token, bytes calldata data)
        external
        returns (uint256 claimed);

    function repayBeneficiary(bytes calldata functionData, address beneficiary, uint256 amount) external;
    function repayBeneficiaryWithTradedTokens(bytes calldata functionData, address beneficiary) external;

    function tradeAndDistribute(
        address beneficiary,
        address sellToken,
        uint256 sellAmount,
        uint256 minBuyAmount,
        bytes calldata zeroExTradeData
    ) external;

    function otcSwap(address beneficiary, address oracle, IOTC.OTC memory otc) external;

    // owner funcs
    function claimOwnerTokens(address token) external returns (uint256 claimed);
    function claimOperatorTokens(address token) external returns (uint256 claimed);
    function sweepOwnerOperatorTokens(address token, address to)
        external
        returns (uint256 operatorTokens, uint256 ownerTokens);

    // admin funcs
    function resetBeneficiaries(
        address operator,
        BeneficiaryData memory defaultBeneficiary,
        BeneficiaryData[] calldata beneficiaries_,
        address[] memory tokens
    ) external;

    function reassignTokens(address beneficiary, address[] calldata tokens) external;

    function impairBeneficiaryDebtOwed(address beneficiary) external;

    // Recovery functionality
    function recoverBeneficiaryTokens(address beneficiary, address token, address to) external;
    function recoverSpigotTokens(address token, address to) external;

    // Update beneficiary functions
    function updateBeneficiaryRepaymentFunc(address beneficiary, bytes4 repaymentFunc) external;
    function updateBeneficiaryPoolAddress(address beneficiary, address poolAddress) external;

    // maintainer funcs
    function addSpigot(address borrowerContract, Setting memory setting) external;
    function removeSpigot(address borrowerContract) external;

    // operator funcs
    function operate(address borrowerContract, bytes calldata data) external returns (bool);

    // stakeholder funcs
    function updateBorrowerContractSplit(address borrowerContract, uint8 ownerSplit) external;
    function updateOwner(address newOwner) external returns (bool);
    function updateOperator(address newOperator) external;
    function updateWhitelistedFunction(bytes4 func, bool allowed) external;
    function updateStableCoinWhitelist(address token, bool includeToken) external;
    function updateAllowedOTCPriceImpact(uint128 allowedPriceImpact) external;

    // Getters

    function allocationOf(address token, address beneficiary) external view returns (uint256);

    function getDefaultBeneficiaryBasicData()
        external
        view
        returns (uint256 allocation, address creditToken, uint256 debtOwed);

    function getBeneficiaryBasicData(address beneficiary)
        external
        view
        returns (uint256 allocation, address creditToken, uint256 debtOwed);

    function getBeneficiaryTokens(address beneficiary, address token) external view returns (uint256);

    function beneficiaries() external view returns (address[] memory);
    function owner() external view returns (address);
    function operator() external view returns (address);
    function isWhitelisted(bytes4 func) external view returns (bool);
    function getOwnerTokens(address token) external view returns (uint256);
    function getOperatorTokens(address token) external view returns (uint256);

    function getSetting(address borrowerContract)
        external
        view
        returns (uint8 split, bytes4 claimFunc, bytes4 transferFunc);

    function hasBeneficiaryDebtOutstanding() external returns (bool);
    function getBeneficiaryData(address beneficiary) external view returns (BeneficiaryData memory);
    function totalBennyAmountTradedFor(address) external view returns (uint256);
    function bennyAmountTradedFor(address) external view returns (uint256); 
}