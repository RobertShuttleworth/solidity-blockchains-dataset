// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.21;

import { UtilLib } from "./contracts_utils_UtilLib.sol";
import { TransferHelper } from "./contracts_utils_TransferHelper.sol";
import { EigenpieConstants } from "./contracts_utils_EigenpieConstants.sol";
import { SafeERC20 } from "./lib_openzeppelin-contracts_contracts_token_ERC20_utils_SafeERC20.sol";

import { EigenpieConfigRoleChecker, IEigenpieConfig } from "./contracts_utils_EigenpieConfigRoleChecker.sol";
import { IMintableERC20 } from "./contracts_interfaces_IMintableERC20.sol";
import { INodeDelegator } from "./contracts_interfaces_INodeDelegator.sol";
import { IEigenpieStaking } from "./contracts_interfaces_IEigenpieStaking.sol";
import { IMLRT } from "./contracts_interfaces_IMLRT.sol";
import { IEigenpiePreDepositHelper } from "./contracts_interfaces_IEigenpiePreDepositHelper.sol";

import { IERC20 } from "./lib_openzeppelin-contracts_contracts_token_ERC20_IERC20.sol";
import { PausableUpgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_security_PausableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_security_ReentrancyGuardUpgradeable.sol";

/// @title EigenpieStaking - Deposit Pool Contract for LSTs
/// @notice Handles LST asset deposits
contract EigenpieStaking is
    IEigenpieStaking,
    EigenpieConfigRoleChecker,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;

    uint256 public maxNodeDelegatorLimit;
    uint256 public minAmountToDeposit;

    mapping(address => uint256) public isNodeDelegator; // 0: not a node delegator, 1: is a node delegator
    address[] public nodeDelegatorQueue;
    //1st upgrade
    bool public isPreDeposit;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    receive() external payable { }

    /// @dev Initializes the contract
    /// @param eigenpieConfigAddr eigenpieConfig address
    function initialize(address eigenpieConfigAddr) external initializer {
        UtilLib.checkNonZeroAddress(eigenpieConfigAddr);

        __Pausable_init();
        __ReentrancyGuard_init();

        maxNodeDelegatorLimit = 10;
        eigenpieConfig = IEigenpieConfig(eigenpieConfigAddr);

        emit UpdatedEigenpieConfig(eigenpieConfigAddr);
    }

    modifier onlyEigenpieWithdrawManager() {
        address eigenpieWithdrawManager = eigenpieConfig.getContract(EigenpieConstants.EIGENPIE_WITHDRAW_MANAGER);
        if (msg.sender != eigenpieWithdrawManager) revert InvalidCaller();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            view functions
    //////////////////////////////////////////////////////////////*/
    /// @notice gets the total asset present in protocol
    /// @param asset Asset address
    /// @return totalAssetDeposit total asset present in protocol
    function getTotalAssetDeposits(address asset) public view override returns (uint256 totalAssetDeposit) {
        (
            uint256 assetLyingInDepositPool,
            uint256 assetLyingInNDCs,
            uint256 assetStakedInEigenLayer,
            uint256 assetLyingInEWD
        ) = getAssetDistributionData(asset);
        return (assetLyingInDepositPool + assetLyingInNDCs + assetStakedInEigenLayer + assetLyingInEWD);
    }

    /// @notice gets the current limit of asset deposit
    /// @param asset Asset address
    /// @return currentLimit Current limit of asset deposit
    function getAssetCurrentLimit(address asset) public view override returns (uint256) {
        uint256 totalDeposits = getTotalAssetDeposits(asset);
        uint256 depositLimit = eigenpieConfig.depositLimitByAsset(asset);

        if (totalDeposits > depositLimit) {
            return 0;
        }

        return depositLimit - totalDeposits;
    }

    /// @dev get node delegator queue
    /// @return nodeDelegatorQueue Array of node delegator contract addresses
    function getNodeDelegatorQueue() external view override returns (address[] memory) {
        return nodeDelegatorQueue;
    }

    /// @dev provides asset amount distribution data among depositPool, NDCs and eigenLayer
    /// @param asset the asset to get the total amount of
    /// @return assetLyingInDepositPool asset amount lying in this EigenpieStaking contract
    /// @return assetLyingInNDCs asset amount sum lying in all NDC contract
    /// @return assetStakedInEigenLayer asset amount deposited in eigen layer strategies through all NDCs
    /// @return assetLyingInEWD asset amount sum lying in all eigenpieWithdrawManager contract
    function getAssetDistributionData(address asset)
        public
        view
        override
        onlySupportedAsset(asset)
        returns (
            uint256 assetLyingInDepositPool,
            uint256 assetLyingInNDCs,
            uint256 assetStakedInEigenLayer,
            uint256 assetLyingInEWD
        )
    {
        assetLyingInDepositPool = TransferHelper.balanceOf(asset, address(this));

        if (asset == EigenpieConstants.PLATFORM_TOKEN_ADDRESS) {
            address eigenpieWithdrawManager = eigenpieConfig.getContract(EigenpieConstants.EIGENPIE_WITHDRAW_MANAGER);
            assetLyingInEWD = TransferHelper.balanceOf(asset, eigenpieWithdrawManager);
        }

        uint256 ndcsCount = nodeDelegatorQueue.length;
        for (uint256 i; i < ndcsCount;) {
            assetLyingInNDCs += TransferHelper.balanceOf(asset, nodeDelegatorQueue[i]);
            assetStakedInEigenLayer += INodeDelegator(nodeDelegatorQueue[i]).getAssetBalance(asset);
            unchecked {
                ++i;
            }
        }
    }

    /// @notice View amount of mLRT to mint for given asset amount
    /// @param asset Asset address
    /// @param amount Asset amount
    /// @return mLRTAmountToMint Amount of mLRT to mint
    /// @return mLRTReceipt reciept token to mint
    function getMLRTAmountToMint(
        address asset,
        uint256 amount
    )
        public
        view
        returns (uint256 mLRTAmountToMint, address mLRTReceipt)
    {
        address receipt = eigenpieConfig.mLRTReceiptByAsset(asset);

        uint256 rate = IMLRT(receipt).exchangeRateToLST();

        return ((amount * 1 ether) / rate, receipt);
    }

    /*//////////////////////////////////////////////////////////////
                            write functions
    //////////////////////////////////////////////////////////////*/
    /// @notice helps user stake LST to the protocol
    /// @param asset LST asset address to stake
    /// @param minRec min amount of mLRT Receipt to receive
    /// @param depositAmount LST asset amount to stake
    function depositAsset(
        address asset,
        uint256 depositAmount,
        uint256 minRec,
        address referral
    )
        external
        payable
        whenNotPaused
        nonReentrant
        onlySupportedAsset(asset)
    {
        // checks
        bool isNative = UtilLib.isNativeToken(asset);

        // If the asset is NOT native, but msg.value > 0 (ETH sent), revert the transaction
        if (!isNative && msg.value > 0) {
            revert IncorrectAssetForNativeToken();
        }

        if (isNative && msg.value != depositAmount) {
            revert InvalidAmountToDeposit();
        }

        if (depositAmount == 0 || depositAmount < minAmountToDeposit) {
            revert InvalidAmountToDeposit();
        }

        if (depositAmount > getAssetCurrentLimit(asset)) {
            revert MaximumDepositLimitReached();
        }

        uint256 mintedAmount;

        if (isPreDeposit && !isNative) {
            // only when not native and in pre deposit phase, we don't min receipt token to users
            address eigenpiePreDepositHelper = eigenpieConfig.getContract(EigenpieConstants.EIGENPIE_PREDEPOSITHELPER);
            mintedAmount = _mintMLRT(address(eigenpiePreDepositHelper), asset, depositAmount);
            IEigenpiePreDepositHelper(eigenpiePreDepositHelper).feedUserDeposit(msg.sender, asset, mintedAmount);
        } else {
            // mint receipt
            mintedAmount = _mintMLRT(msg.sender, asset, depositAmount);
        }

        if (mintedAmount < minRec) {
            revert MinimumAmountToReceiveNotMet();
        }

        if (!isNative) {
            IERC20(asset).safeTransferFrom(msg.sender, address(this), depositAmount);
        }

        emit AssetDeposit(msg.sender, asset, depositAmount, referral, mintedAmount, isPreDeposit);
    }

    // TODO don't open this as we need to avoid exchange rate manipulation.
    function withdrawFromPreDeposit(
        uint256 cycle,
        address asset,
        uint256 mLRTAmount
    )
        external
        whenNotPaused
        nonReentrant
    {
    //     if (cycle <= 0) revert InvalidCycle();

    //     IEigenpiePreDepositHelper preDepositHelper =
    //         IEigenpiePreDepositHelper(eigenpieConfig.getContract(EigenpieConstants.EIGENPIE_PREDEPOSITHELPER));

    //     /* if the cycle becomes claimmable for mlrt receipt, that means underlying LST already depositted into
    //     Eigenlayer,
    //     hence, withdraw from the preDeposit cycle is not allowed anymore, have to go through normal withdraw flow*/
    //     if (preDepositHelper.claimableCycles(cycle)) revert OnlyWhenPredeposit();

    //     address mLRT = eigenpieConfig.mLRTReceiptByAsset(asset);
    //     uint256 rate = IMLRT(mLRT).exchangeRateToLST();
    //     uint256 assetToReturn = mLRTAmount * rate / 1 ether;

    //     preDepositHelper.withdraw(cycle, msg.sender, asset, mLRT, mLRTAmount);

    //     TransferHelper.safeTransferToken(asset, msg.sender, assetToReturn);
    }

    /// @notice add new node delegator contract addresses
    /// @dev only callable by Eigenpie default
    /// @param nodeDelegatorContracts Array of NodeDelegator contract addresses
    function addNodeDelegatorContractToQueue(address[] calldata nodeDelegatorContracts) external onlyDefaultAdmin {
        uint256 length = nodeDelegatorContracts.length;

        // Loop through the input array first to check and add unique NodeDelegators
        for (uint256 i; i < length;) {
            UtilLib.checkNonZeroAddress(nodeDelegatorContracts[i]);

            // If the NodeDelegator is not already added, mark it as added
            if (isNodeDelegator[nodeDelegatorContracts[i]] == 0) {
                nodeDelegatorQueue.push(nodeDelegatorContracts[i]);
                isNodeDelegator[nodeDelegatorContracts[i]] = 1;
            }

            unchecked {
                ++i;
            }
        }

        // After the loop, check if the total number of NodeDelegators exceeds the limit
        if (nodeDelegatorQueue.length > maxNodeDelegatorLimit) {
            revert MaximumNodeDelegatorLimitReached();
        }

        emit NodeDelegatorAddedinQueue(nodeDelegatorContracts);
    }

    /// @notice transfers asset lying in this DepositPool to node delegator contract
    /// @dev only callable by Eigenpie manager
    /// @param ndcIndex Index of NodeDelegator contract address in nodeDelegatorQueue
    /// @param asset Asset address
    /// @param amount Asset amount to transfer

    function transferAssetToNodeDelegator(
        uint256 ndcIndex,
        address asset,
        uint256 amount
    )
        external
        whenNotPaused
        nonReentrant
        onlyEigenpieManager
        onlySupportedAsset(asset)
    {
        if (ndcIndex >= nodeDelegatorQueue.length) revert InvalidIndex();
        address nodeDelegator = nodeDelegatorQueue[ndcIndex];

        TransferHelper.safeTransferToken(asset, nodeDelegator, amount);
    }

    /// @notice update max node delegator count
    /// @dev only callable by Eigenpie default
    /// @param maxNodeDelegatorLimit_ Maximum count of node delegator
    function updateMaxNodeDelegatorLimit(uint256 maxNodeDelegatorLimit_) external onlyDefaultAdmin {
        if (maxNodeDelegatorLimit_ < nodeDelegatorQueue.length) {
            revert InvalidMaximumNodeDelegatorLimit();
        }

        maxNodeDelegatorLimit = maxNodeDelegatorLimit_;
        emit MaxNodeDelegatorLimitUpdated(maxNodeDelegatorLimit);
    }

    /// @notice update min amount to deposit
    /// @dev only callable by Eigenpie default
    /// @param minAmountToDeposit_ Minimum amount to deposit
    function setMinAmountToDeposit(uint256 minAmountToDeposit_) external onlyDefaultAdmin {
        minAmountToDeposit = minAmountToDeposit_;
        emit MinAmountToDepositUpdated(minAmountToDeposit_);
    }

    /// @dev Triggers stopped state. Contract must not be paused.
    function pause() external onlyEigenpieManager {
        _pause();
    }

    /// @dev Returns to normal state. Contract must be paused
    function unpause() external onlyDefaultAdmin {
        _unpause();
    }

    function setIsPreDeposit(bool _isPreDeposit) external onlyDefaultAdmin {
        isPreDeposit = _isPreDeposit;
        emit PreDepositStatusChanged(_isPreDeposit);
    }

    function _mintMLRT(address _for, address asset, uint256 depositAmount) private returns (uint256 mintedMLRTAmount) {
        (uint256 toMint, address receipt) = getMLRTAmountToMint(asset, depositAmount);

        IMintableERC20(receipt).mint(_for, toMint);

        return toMint;
    }
}