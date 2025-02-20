// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.21;

import "./contracts_interfaces_eigenlayer_IStrategy.sol";
import "./contracts_interfaces_ssvNetwork_ISSVNetworkCore.sol";

interface INodeDelegator {
    // struct
    struct DepositData {
        bytes[] publicKeys;
        bytes[] signatures;
        bytes32[] depositDataRoots;
    }

    struct SSVPayload {
        uint64[] operatorIds;
        bytes[] sharesData;
        uint256 amount;
        ISSVNetworkCore.Cluster cluster;
    }

    // event
    event AssetDepositIntoStrategy(address indexed asset, address indexed strategy, uint256 depositAmount);
    event EigenPodCreated(address indexed createdEigenPod);
    event RewardsForwarded(address indexed destinatino, uint256 amount);
    event WithdrawalQueuedToEigenLayer(
        bytes32[] withdrawalRoot,
        IStrategy[] strategies,
        address[] assets,
        uint256[] withdrawalAmounts,
        uint256 startBlock
    );
    event DelegationAddressUpdated(address delegate);
    event GasSpent(address indexed spender, uint256 gasUsed);
    event GasRefunded(address indexed receiver, uint256 gasRefund);
    event NewProofSubmitter(address indexed oldProofSubmitter, address indexed _newProofSubmitter);
    event AVSRewardClaimerUpdated(address indexed _prevClaimer, address indexed _newClaimer);
    event BufferFilled(uint256 amount);

    // errors
    error TokenTransferFailed();
    error StrategyIsNotSetForAsset();
    error NoPubKeysProvided();
    error EigenPodExisted();
    error EigenPodDoesNotExist();
    error InvalidCall();
    error InvalidCaller();
    error AtLeastOneValidator();
    error MaxValidatorsInput();
    error PublicKeyNotMatch();
    error SignaturesNotMatch();
    error DelegateAddressAlreadySet();
    error InvalidAmount();

    // methods
    function depositAssetIntoStrategy(address asset) external;

    function maxApproveToEigenStrategyManager(address asset) external;

    function getAssetBalances() external view returns (address[] memory, uint256[] memory);

    function getAssetBalance(address asset) external view returns (uint256);

    function getEthBalance() external view returns (uint256);

    function createEigenPod() external;

    function queueWithdrawalToEigenLayer(address[] memory assets, uint256[] memory amount) external;
}