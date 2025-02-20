// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ReentrancyGuard} from "./lib_openzeppelin-contracts_contracts_security_ReentrancyGuard.sol";
import {AccessControl} from "./lib_openzeppelin-contracts_contracts_access_AccessControl.sol";
import {IERC721} from "./lib_openzeppelin-contracts_contracts_token_ERC721_IERC721.sol";
import {IERC1155} from "./lib_openzeppelin-contracts_contracts_token_ERC1155_IERC1155.sol";
import {Math} from "./lib_openzeppelin-contracts_contracts_utils_math_Math.sol";
import {Address} from "./lib_openzeppelin-contracts_contracts_utils_Address.sol";
import {IUniversalOracle} from "./contracts_interfaces_IUniversalOracle.sol";
import {CryptonergyManager} from "./contracts_CryptonergyManager.sol";
import {BaseModule} from "./contracts_modules_BaseModule.sol";
import {ERC721Holder} from "./lib_openzeppelin-contracts_contracts_token_ERC721_utils_ERC721Holder.sol";
import {ERC1155Holder, IERC1155Receiver} from "./lib_openzeppelin-contracts_contracts_token_ERC1155_utils_ERC1155Holder.sol";
import {IVaultStrategy} from "./contracts_interfaces_IVaultStrategy.sol";
import {Uint32Array} from "./contracts_utils_Uint32Array.sol";
import {ERC4626Initializable, ERC20Initializable, Initializable} from "./contracts_ERC4626Initializable.sol";
import {SafeTransferLib} from "./lib_solmate_src_utils_SafeTransferLib.sol";
import {ERC20} from "./lib_solmate_src_tokens_ERC20.sol";

error StrategyAlreadyUsed(uint32 strategy);
error StrategyNotInCatalogue(uint32 position);
error StrategyNotEmpty(uint32 position, uint256 sharesRemaining);
error StrategyArrayFull(uint256 maxStrategies);
error FailedToForceOutStrategy();
error PermissionDenied();
error AssetsDeviationAfterModuleCall();
error TotalSupplyChangedAfterModuleCall();
error NotOwnerOfDeposit(address owner, address sender);
error ZeroValue(string argument);
error MaxWithdraw();
error InvalidPercentage();
error UndefinedModule(address module);
error WithdrawRequestClosedOrNotDefined(uint256 id);
error InitialDeposit(uint256 minDeposit, uint256 initialDeposit);
error Paused();
error VaultDisabled();

contract VaultV5 is
    ERC4626Initializable,
    ReentrancyGuard,
    AccessControl,
    ERC721Holder,
    ERC1155Holder
{
    using Math for uint256;
    using Math for uint32;
    using SafeTransferLib for ERC20;
    using Address for address;
    using Uint32Array for uint32[];

    struct WithdrawalQueueItem {
        uint256 id; /// @notice Unique id for queue item
        address receiver; /// @notice Address to send assets
        address owner; /// @notice Address of owner
        uint256 sharesAmount; /// @notice Amount of shares
        uint256 assetsAmount; /// @notice Amount of assets
        bool isOpen; /// @notice Flag to check if request is open
    }

    struct ModuleCall {
        address module;
        bytes[] callData;
    }

    struct UserDeposit {
        uint256 initialDeposit;
        uint256 highWaterMark;
    }

    struct ManagementFeeInfo {
        uint256 previousTimestamp;
        uint256 previousTotalSupply;
    }
    ManagementFeeInfo public managementFeeInfo;
    mapping(address => UserDeposit) public userDeposits;

    uint8 internal constant UNIVERSAL_ORACLE_MANAGER_SLOT = 1;
    uint8 internal constant MAX_STRATEGIES = 64;
    uint32 internal constant MIN_CONSTRUCTOR_MINT = 1e4;
    uint256 internal constant PRECISION = 1e18;
    uint32 public constant MAX_PERFORMANCE_FEE = 40_000;
    uint32 public constant MAX_MANAGEMENT_FEE = 10_000;
    bytes32 public constant VAULT_STRATEGIST_ROLE =
        keccak256("VAULT_STRATEGIST_ROLE");

    uint256 public perfomanceFee; // 4
    uint256 public perfomanceTreshold; // 4
    uint256 public minPerfomanceFeeAmount;
    uint256 public managementFee; // 4
    uint32 public holdingStrategy; // 4
    /// @notice deviation for module calls        <===== 1 storage slot
    uint256 public allowedDeviationForModuleCalls; // 4
    address public strategist; // 20

    uint96 public withdrawQueueItemId; // 12
    CryptonergyManager public cryptonergyManager; // 20

    address public universalOracle; // 20

    bool public isDisabled; // 1
    bool public ignorePause; // 1
    bool public blockExternalReceiver; // 1

    mapping(uint32 => bool) public isStrategyUsed;
    mapping(address => uint256) private depositsInAssets;
    mapping(uint256 => WithdrawalQueueItem) public withdrawQueue;
    mapping(uint32 => CryptonergyManager.StrategyData) public getStrategyData;
    mapping(uint32 => bool) internal strategiesCatalogue;
    mapping(address => bool) internal modulesCatalogue;
    uint32[] internal strategies;

    /// @notice Emitted when withdraw request is created
    /// @param id Unique id for queue item
    /// @param receiver Address to send assets
    /// @param assets Amount of assets
    /// @param shares Amount of shares
    event RequestWithdraw(
        uint256 id,
        address indexed receiver,
        uint256 assets,
        uint256 shares
    );
    event ModuleCalled(address module, bytes data, uint256 value);
    /// @notice Emitted when withdraw request is approved
    /// @param strategist Address of strategist
    /// @param id Unique id for queue item
    /// @param receiver Address to send assets
    /// @param owner Address of owner
    /// @param assets Amount of assets
    /// @param shares Amount of shares
    event WithdrawApproved(
        address indexed strategist,
        uint256 id,
        address indexed receiver,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );

    /// @notice Emitted when withdraw request is closed
    /// @param id Unique id for queue item
    event WithdrawClosed(uint256 id);

    /// @notice Emitted when strategist updated
    /// @param strategist Address of strategist
    event SetStrategist(address indexed strategist);
    /// @notice Emitted when perfomance fee updated
    /// @param fee Fee in basis points
    event UpdatePerfomanceFee(uint256 fee);
    /// @notice Emitted when management fee updated
    /// @param fee Fee in basis points
    event UpdateManagementFee(uint256 fee);
    /// @notice Emitted when module is added
    event AddModule(address indexed module);
    /// @notice Emitted when module is removed
    event RemoveModule(address indexed module);
    /// @notice Emitted when module is called
    event UpdateAllowedAssetDeviation(uint256 deviation);
    /// @notice Emitted when price oracle is updated
    event UniversalOracleUpdated(address indexed universalOracle);
    event StrategyAdded(uint32 position, uint256 index);
    event StrategyRemoved(uint32 position, uint256 index);
    event StrategyAddedToCatalogue(uint32 strategyId, bool inCatalogue);
    event ModuleAddedToCatalogue(address module, bool inCatalogue);
    event UpdatePerfomanceTreshold(uint256 treshold);
    event Disabled(bool disabled);
    event ManagementFeeCollected(
        address receiver,
        uint256 previousTotalSupply,
        uint256 totalSupply,
        uint256 feeInShares,
        uint256 feeInAssets
    );
    event PerfomanceFeeCollected(
        address user,
        address receiver,
        uint256 feeInAssets,
        uint256 feeInShares,
        uint256 newHighWaterMark
    );

    constructor() {}

    function initialize(bytes memory _initHash) external initializer {
        (
            string memory _name,
            string memory _symbol,
            address _asset,
            address _strategist,
            address _admin,
            address _cryptonergyManager,
            uint256 _initialDeposit,
            uint32 _holdingStrategy
        ) = abi.decode(
                _initHash,
                (
                    string,
                    string,
                    address,
                    address,
                    address,
                    address,
                    uint256,
                    uint32
                )
            );

        __initERC4626(ERC20(_asset), _name, _symbol);
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(VAULT_STRATEGIST_ROLE, _strategist);

        strategist = _strategist;
        cryptonergyManager = CryptonergyManager(_cryptonergyManager);
        perfomanceFee = 2e17;
        managementFee = 2e16;
        perfomanceTreshold = 1e17;
        minPerfomanceFeeAmount = 10e6;
        universalOracle = CryptonergyManager(_cryptonergyManager)
            .getAddressById(UNIVERSAL_ORACLE_MANAGER_SLOT);
        allowedDeviationForModuleCalls = 4e16;

        if (_initialDeposit < MIN_CONSTRUCTOR_MINT)
            revert InitialDeposit(MIN_CONSTRUCTOR_MINT, _initialDeposit);
        addStrategyToCatalogue(_holdingStrategy);
        addStrategy(0, _holdingStrategy);

        ERC20(asset).safeTransferFrom(
            msg.sender,
            address(this),
            _initialDeposit
        );
        _mint(_strategist, _initialDeposit);
        _revokeRole(DEFAULT_ADMIN_ROLE, msg.sender);

        managementFeeInfo = ManagementFeeInfo({
            previousTimestamp: uint64(block.timestamp),
            previousTotalSupply: totalSupply
        });
    }

    receive() external payable {}

    /// ================================================== ERC-4626 ==================================================
    /// @notice Function performs minting of shares for assets.
    /// @param shares Amount of shares to mint
    /// @param receiver Address to receive shares
    function mint(
        uint256 shares,
        address receiver
    ) public override nonReentrant returns (uint256 assets) {
        beforeDeposit(0, shares);
        assets = previewMint(shares); // No need to check for rounding error, previewMint rounds up.

        // Need to transfer before minting or ERC777s could reenter.
        asset.safeTransferFrom(msg.sender, address(this), assets);

        _mint(receiver, shares);
        userDeposits[receiver].initialDeposit += assets;

        emit Deposit(msg.sender, receiver, assets, shares);

        afterDeposit(assets, shares);
    }

    /// @notice Function performs depositing of assets and minting of shares.
    /// @param assets Amount of assets to deposit
    /// @param receiver Address to receive shares
    function deposit(
        uint256 assets,
        address receiver
    ) public override nonReentrant returns (uint256 shares) {
        beforeDeposit(assets, 0);
        shares = previewDeposit(assets);
        if (shares == 0) revert ZeroValue("shares");
        // Need to transfer before minting or ERC777s could reenter.
        asset.safeTransferFrom(msg.sender, address(this), assets);

        _mint(receiver, shares);
        userDeposits[receiver].initialDeposit += assets;

        emit Deposit(msg.sender, receiver, assets, shares);

        afterDeposit(assets, shares);
    }

    /// @notice Function performs creating of withdraw request.
    /// @param _assets Amount of assets to withdraw
    /// @param _receiver Address to receive assets
    /// @param _owner Address of owner
    function withdraw(
        uint256 _assets,
        address _receiver,
        address _owner
    ) public override returns (uint256) {
        if (msg.sender != _owner) {
            revert NotOwnerOfDeposit(_owner, msg.sender);
        }
        if (_assets == 0) revert ZeroValue("_assets");

        if (_assets > maxWithdraw(_owner)) revert MaxWithdraw();

        uint256 shares = _assets == maxWithdraw(_owner)
            ? maxRedeem(_owner)
            : convertToShares(_assets);
        beforeWithdraw(_assets, shares);
        uint256 queueItemId = _createQueueItem(
            _receiver,
            _owner,
            shares,
            _assets
        );
        emit RequestWithdraw(queueItemId, _receiver, _assets, shares);

        return shares;
    }

    /// @notice Function performs redeeming of shares for assets.
    /// And creating of withdraw request.
    /// @param _shares Amount of shares to redeem
    /// @param _receiver Address to receive assets
    /// @param _owner Address of owner
    function redeem(
        uint256 _shares,
        address _receiver,
        address _owner
    ) public override returns (uint256) {
        if (_owner != msg.sender) revert NotOwnerOfDeposit(_owner, msg.sender);
        if (_shares == 0) revert ZeroValue("_shares");

        if (_shares > maxRedeem(_owner)) revert MaxWithdraw();

        uint256 assets = convertToAssets(_shares);
        beforeWithdraw(assets, _shares);
        uint256 queueItemId = _createQueueItem(
            _receiver,
            _owner,
            _shares,
            assets
        );
        emit RequestWithdraw(queueItemId, _receiver, assets, _shares);

        return assets;
    }

    /// @notice Function performs approval of withdraw request.
    /// Only admin or strategist roles can call this function
    /// @param _withdrawQueueItemId Id of withdraw request
    function approveWithdraw(
        uint128 _withdrawQueueItemId,
        ModuleCall[] memory data
    ) external payable checkPermission returns (uint256) {
        if (data.length > 0) {
            uint256 totalShares = totalSupply;
            _makeModuleCalls(data, msg.value);
            if (totalShares != totalSupply) {
                revert TotalSupplyChangedAfterModuleCall();
            }
        }

        WithdrawalQueueItem memory withdrawQueueItem = withdrawQueue[
            _withdrawQueueItemId
        ];
        if (!withdrawQueueItem.isOpen)
            revert WithdrawRequestClosedOrNotDefined(_withdrawQueueItemId);

        // uint assetsAmount = convertToAssets(withdrawQueueItem.sharesAmount);
        uint assetsAmount = withdrawQueueItem.assetsAmount;

        (
            uint256 feeInShares,
            uint256 feeInAssets,
            uint256 currentDepositInAssets,
            uint256 maxWithdrawInAssets,
            uint256 newHighWaterMark
        ) = calculatePerfomanceFee(withdrawQueueItem.owner);
        uint256 assetsToWithdraw;
        if (assetsAmount >= maxWithdrawInAssets) {
            assetsToWithdraw = maxWithdrawInAssets;
            userDeposits[withdrawQueueItem.owner].highWaterMark = 0;
            userDeposits[withdrawQueueItem.owner].initialDeposit = 0;
            _burn(withdrawQueueItem.owner, balanceOf[withdrawQueueItem.owner]);
            if (feeInShares > 0) {
                _mint(strategist, feeInShares);
                emit PerfomanceFeeCollected(
                    withdrawQueueItem.owner,
                    strategist,
                    feeInAssets,
                    feeInShares,
                    0
                );
            }
        } else {
            userDeposits[withdrawQueueItem.owner]
                .highWaterMark = newHighWaterMark;
            uint256 initialDepositUpdated = currentDepositInAssets -
                assetsAmount +
                feeInAssets;
            if (
                initialDepositUpdated <
                userDeposits[withdrawQueueItem.owner].initialDeposit
            ) {
                userDeposits[withdrawQueueItem.owner]
                    .initialDeposit = initialDepositUpdated;
            }
            assetsToWithdraw = assetsAmount;
            _burn(
                withdrawQueueItem.owner,
                convertToShares(assetsAmount) + feeInShares
            );
            if (feeInShares > 0) {
                _mint(strategist, feeInShares);
                emit PerfomanceFeeCollected(
                    withdrawQueueItem.owner,
                    strategist,
                    feeInAssets,
                    feeInShares,
                    newHighWaterMark
                );
            }
        }
        withdrawQueue[_withdrawQueueItemId].isOpen = false;
        asset.safeTransfer(withdrawQueueItem.receiver, assetsToWithdraw);

        emit Withdraw(
            msg.sender,
            withdrawQueueItem.receiver,
            withdrawQueueItem.owner,
            assetsAmount,
            withdrawQueueItem.sharesAmount
        );
        emit WithdrawApproved(
            msg.sender,
            _withdrawQueueItemId,
            withdrawQueueItem.receiver,
            withdrawQueueItem.owner,
            assetsAmount,
            withdrawQueueItem.sharesAmount
        );

        return assetsAmount;
    }

    /// @notice Function performs closing of withdraw request.
    /// Only admin or strategist roles can call this function
    /// @param _withdrawQueueItemId Id of withdraw request
    function closeWithdraw(
        uint128 _withdrawQueueItemId
    ) external checkPermission {
        if (withdrawQueue[_withdrawQueueItemId].isOpen) {
            withdrawQueue[_withdrawQueueItemId].isOpen = false;
        } else {
            revert WithdrawRequestClosedOrNotDefined(_withdrawQueueItemId);
        }
        emit WithdrawClosed(_withdrawQueueItemId);
    }

    function beforeDeposit(uint256, uint256) internal virtual {
        _whenEnabled();
        _checkIfPaused();
    }

    function afterDeposit(uint256, uint256) internal virtual override {
        if (managementFee > 0) {
            chargeManagementFee();
        }
    }

    /**
     * @notice called at the beginning of withdraw.
     */
    function beforeWithdraw(uint256, uint256) internal virtual override {
        chargeManagementFee();
        _checkIfPaused();
    }

    function beforeTransfer(address, address, uint256) internal override {}

    function afterTransfer(
        address from,
        address to,
        uint256 value
    ) internal override {
        uint256 senderCurrentDeposit = convertToAssets(balanceOf[from] + value);
        uint256 senderInitialDeposit = userDeposits[from].initialDeposit;
        uint256 valueInAssets = convertToAssets(value);

        uint256 subValue = (valueInAssets * senderInitialDeposit) /
            senderCurrentDeposit;
        userDeposits[from].initialDeposit -= subValue;
        userDeposits[to].initialDeposit += convertToAssets(value);
    }

    function maxWithdraw(address owner) public view override returns (uint256) {
        (, , , uint256 maxWithdrawInAssets, ) = calculatePerfomanceFee(owner);
        return maxWithdrawInAssets;
    }

    /// ================================================== Fees ==================================================

    function chargePerfomanceFee(address user) external checkPermission {
        (
            uint256 feeInShares,
            uint256 feeInAssets,
            ,
            ,
            uint256 newHighWaterMark
        ) = calculatePerfomanceFee(user);
        address strategistCashed = strategist;

        if (feeInAssets > 0) {
            _burn(user, feeInShares);
            _mint(strategistCashed, feeInShares);
            userDeposits[user].highWaterMark = newHighWaterMark;
            emit PerfomanceFeeCollected(
                user,
                strategistCashed,
                feeInAssets,
                feeInShares,
                newHighWaterMark
            );
        }
    }

    function chargeManagementFee() public {
        uint256 totalSupplyCashed = totalSupply;
        address strategistCashed = strategist;
        (uint256 fee, uint256 feeInAssets) = calculateManagementFee();
        if (fee > 0) {
            _mint(strategistCashed, fee);
            emit ManagementFeeCollected(
                strategistCashed,
                managementFeeInfo.previousTotalSupply,
                totalSupplyCashed,
                fee,
                feeInAssets
            );
        }
        managementFeeInfo.previousTimestamp = uint64(block.timestamp);
        managementFeeInfo.previousTotalSupply = totalSupplyCashed;
    }

    function calculatePerfomanceFee(
        address user
    )
        public
        view
        returns (
            uint256 feeInShares,
            uint256 feeInAssets,
            uint256 currentDepositInAssets,
            uint256 maxWithdrawInAssets,
            uint256 newHighWaterMark
        )
    {
        if (user == strategist) {
            uint256 balanceInAssets = convertToAssets(balanceOf[user]);
            return (0, 0, balanceInAssets, balanceInAssets, 0);
        }
        UserDeposit memory userDeposit = userDeposits[user];
        currentDepositInAssets = convertToAssets(balanceOf[user]);
        uint256 earnings = currentDepositInAssets > userDeposit.initialDeposit
            ? currentDepositInAssets - userDeposit.initialDeposit
            : 0;
        uint256 hwEarnings = earnings > userDeposit.highWaterMark
            ? earnings - userDeposit.highWaterMark
            : 0;

        if (
            hwEarnings >
            (userDeposit.initialDeposit * perfomanceTreshold) / PRECISION &&
            hwEarnings > minPerfomanceFeeAmount
        ) {
            feeInAssets = earnings.mulDiv(
                perfomanceFee,
                PRECISION,
                Math.Rounding.Ceil
            );
            feeInShares = convertToShares(feeInAssets);
            maxWithdrawInAssets = currentDepositInAssets - feeInAssets;
            newHighWaterMark = earnings;
        } else {
            feeInShares = 0;
            feeInAssets = 0;
            maxWithdrawInAssets = currentDepositInAssets;
            newHighWaterMark = userDeposit.highWaterMark;
        }
    }

    function calculateManagementFee()
        public
        view
        returns (uint256 feeInShares, uint256 feeInAssets)
    {
        uint256 feePercentPerSecond = managementFee / 365 days;
        uint256 timeElapsed = block.timestamp -
            managementFeeInfo.previousTimestamp;
        uint256 feePercent = feePercentPerSecond * timeElapsed;
        feeInShares = managementFeeInfo.previousTotalSupply.mulDiv(
            feePercent,
            1e18,
            Math.Rounding.Ceil
        );
        feeInAssets = convertToAssets(feeInShares);
    }

    /// ================================================== Strategies ==================================================
    function addStrategyToCatalogue(uint32 strategyId) public checkPermission {
        cryptonergyManager.revertIfStrategyIsNotTrusted(strategyId);
        strategiesCatalogue[strategyId] = true;
        emit StrategyAddedToCatalogue(strategyId, true);
    }

    function removeStrategyFromCatalogue(
        uint32 strategyId
    ) external checkPermission {
        strategiesCatalogue[strategyId] = false;
        emit StrategyAddedToCatalogue(strategyId, false);
    }

    function addModuleToCatalogue(address module) external checkPermission {
        cryptonergyManager.revertIfModuleIsNotTrusted(module);
        modulesCatalogue[module] = true;
        emit ModuleAddedToCatalogue(module, true);
    }

    function removeModuleFromCatalogue(
        address module
    ) external checkPermission {
        modulesCatalogue[module] = false;
        emit ModuleAddedToCatalogue(module, false);
    }

    function addStrategy(
        uint32 index,
        uint32 strategyId
    ) public checkPermission {
        _whenEnabled();
        if (isStrategyUsed[strategyId]) revert StrategyAlreadyUsed(strategyId);

        if (!strategiesCatalogue[strategyId])
            revert StrategyNotInCatalogue(strategyId);

        (address module, bytes memory moduleData) = cryptonergyManager
            .addStrategyToVault(strategyId);

        getStrategyData[strategyId] = CryptonergyManager.StrategyData({
            module: module,
            moduleData: moduleData
        });

        if (strategies.length >= MAX_STRATEGIES)
            revert StrategyArrayFull(MAX_STRATEGIES);
        strategies.add(index, strategyId);

        isStrategyUsed[strategyId] = true;

        emit StrategyAdded(strategyId, index);
    }

    function removeStrategy(uint32 index) external checkPermission {
        uint32 positionId = strategies[index];
        uint256 positionBalance = _getBalance(positionId);
        if (positionBalance > 0)
            revert StrategyNotEmpty(positionId, positionBalance);

        _removePosition(index, positionId);
    }

    function forceStrategyOut(
        uint32 index,
        uint32 positionId
    ) external checkPermission {
        uint32 _positionId = strategies[index];
        if (
            positionId != _positionId ||
            cryptonergyManager.isStrategyTrusted(positionId)
        ) revert FailedToForceOutStrategy();

        _removePosition(index, positionId);
    }

    /// ================================================== Vault Settings ==================================================

    function syncUniversalOracle(
        address oracle,
        uint16 allowedDeviation,
        bool checkTotalAssets
    ) external checkPermission {
        uint256 minAssets;
        uint256 maxAssets;

        if (checkTotalAssets) {
            uint256 assetsBefore = totalAssets();
            minAssets = assetsBefore.mulDiv(
                1e4 - allowedDeviation,
                1e4,
                Math.Rounding.Floor
            );
            maxAssets = assetsBefore.mulDiv(
                1e4 + allowedDeviation,
                1e4,
                Math.Rounding.Ceil
            );
        }

        if (
            CryptonergyManager(cryptonergyManager).getAddressById(
                UNIVERSAL_ORACLE_MANAGER_SLOT
            ) != oracle
        ) {
            revert("Error");
        }

        universalOracle = oracle;
        uint256 assetsAfter = totalAssets();

        if (checkTotalAssets) {
            if (assetsAfter < minAssets || assetsAfter > maxAssets) {
                revert("Assets deviation after oracle update");
            }
        }
        emit UniversalOracleUpdated(universalOracle);
    }

    function toggleIgnorePause() external checkPermission {
        ignorePause = ignorePause ? false : true;
    }

    /**
     * @notice Shutdown the cellar. Used in an emergency or if the cellar has been deprecated.
     * @dev Callable by Sommelier Strategist.
     */
    function enable() external checkPermission {
        _whenEnabled();
        isDisabled = true;

        emit Disabled(true);
    }

    function disable() external {
        if (!isDisabled) revert VaultDisabled();
        isDisabled = false;

        emit Disabled(false);
    }

    /// @notice Function performs setting of performance fee.
    /// Only admin or strategist roles can call this function
    /// @param _feePercent Fee in basis points
    function updatePerfomanceFee(uint32 _feePercent) external checkPermission {
        if (_feePercent > MAX_PERFORMANCE_FEE) revert InvalidPercentage();
        perfomanceFee = _feePercent;
        emit UpdatePerfomanceFee(_feePercent);
    }

    /// @notice Function performs setting of management fee.
    /// Only admin or strategist roles can call this function
    /// @param _feePercent Fee in basis points
    function updateManagementFee(uint32 _feePercent) external checkPermission {
        if (_feePercent > MAX_MANAGEMENT_FEE) revert InvalidPercentage();
        managementFee = _feePercent;
        emit UpdateManagementFee(_feePercent);
    }

    function updatePerfomanceTreshold(
        uint32 _treshold
    ) external checkPermission {
        if (_treshold == 0) revert InvalidPercentage();
        perfomanceTreshold = _treshold;
        emit UpdatePerfomanceTreshold(_treshold);
    }

    function updateMinPerfomanceFeeAmount(
        uint32 _minPerfomanceFeeAmount
    ) external checkPermission {
        minPerfomanceFeeAmount = _minPerfomanceFeeAmount;
    }

    /// @notice Function performs setting or changing of strategist address.
    /// Only admin or strategist roles can call this function
    /// @param _strategist Address of strategist
    function setStrategist(
        address _strategist
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        strategist = _strategist;
        emit SetStrategist(_strategist);
    }

    function updateAllowedDeviationForModuleCalls(
        uint256 _allowedDeviationForModuleCalls
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_allowedDeviationForModuleCalls >= PRECISION)
            revert InvalidPercentage();
        allowedDeviationForModuleCalls = _allowedDeviationForModuleCalls;
        emit UpdateAllowedAssetDeviation(_allowedDeviationForModuleCalls);
    }

    /**
     * @notice View function external contracts can use to see if the cellar is paused.
     */
    function isPaused() external view returns (bool) {
        if (!ignorePause) {
            return cryptonergyManager.isVaultPaused(address(this));
        }
        return false;
    }

    /**
     * @notice Pauses all user entry/exits, and strategist rebalances.
     */
    function _checkIfPaused() internal view {
        if (!ignorePause) {
            if (cryptonergyManager.isVaultPaused(address(this)))
                revert Paused();
        }
    }

    function _whenEnabled() internal view {
        if (isDisabled) revert VaultDisabled();
    }

    /// @notice Modifier to check if sender has permission to call function
    modifier checkPermission() {
        if (
            !hasRole(DEFAULT_ADMIN_ROLE, msg.sender) &&
            !hasRole(VAULT_STRATEGIST_ROLE, msg.sender)
        ) revert PermissionDenied();
        _;
    }

    /// ================================================== Interaction With Modules/Strategies ==================================================
    /// @notice Function performs calls to modules. UniswapV3, UniswapV2 swaps.
    /// Only admin or strategist roles can call this function
    /// @param data Array of module calls
    function callToModule(
        ModuleCall[] memory data
    ) external payable nonReentrant checkPermission {
        _whenEnabled();
        _checkIfPaused();
        blockExternalReceiver = true;

        uint256 minimumAllowedAssets;
        uint256 maximumAllowedAssets;
        uint256 totalShares;
        {
            uint256 assetsBeforeAdaptorCall = totalAssets();
            minimumAllowedAssets = assetsBeforeAdaptorCall.mulDiv(
                (PRECISION - allowedDeviationForModuleCalls),
                PRECISION,
                Math.Rounding.Ceil
            );
            maximumAllowedAssets = assetsBeforeAdaptorCall.mulDiv(
                (PRECISION + allowedDeviationForModuleCalls),
                PRECISION,
                Math.Rounding.Ceil
            );
            totalShares = totalSupply;
        }
        _makeModuleCalls(data, msg.value);
        uint256 assets = totalAssets();
        if (assets < minimumAllowedAssets || assets > maximumAllowedAssets) {
            revert AssetsDeviationAfterModuleCall();
        }
        if (totalShares != totalSupply) {
            revert TotalSupplyChangedAfterModuleCall();
        }
        blockExternalReceiver = true;
    }

    function getStrategies() external view returns (uint32[] memory) {
        return strategies;
    }

    function getStrategyBalanceInAsset(
        uint32 position
    ) external view returns (uint256) {
        address strategyBaseAsset = _baseAsset(position);
        uint256 balance = _getBalance(position);
        return
            IUniversalOracle(universalOracle).getValue(
                strategyBaseAsset,
                balance,
                address(asset)
            );
    }

    /// @notice View function that returns withdraw requests queue.
    /// @return withdrawItems Array of withdraw requests
    function getWithdrawQueue()
        public
        view
        returns (WithdrawalQueueItem[] memory withdrawItems)
    {
        withdrawItems = new WithdrawalQueueItem[](withdrawQueueItemId);

        for (uint i = 0; i < withdrawQueueItemId; i++) {
            withdrawItems[i] = (withdrawQueue[i]);
        }

        return withdrawItems;
    }

    /// @notice View function that calculates total assets in vault and strategies.
    /// @return virtualTotalAssets Amount of total assets
    function totalAssets() public view override returns (uint256) {
        return getAssetsAtStrategies();
    }

    function getAssetsAtStrategies() public view returns (uint256) {
        uint256 numOfV2Strategies = strategies.length;
        address[] memory assets = new address[](numOfV2Strategies);
        uint256[] memory balances = new uint256[](numOfV2Strategies);

        for (uint32 i = 0; i < numOfV2Strategies; i++) {
            uint32 position = strategies[i];

            if ((balances[i] = _getBalance(position)) == 0) continue;
            assets[i] = _baseAsset(position);
        }
        return
            IUniversalOracle(universalOracle).getValues(
                assets,
                balances,
                address(asset)
            );
    }

    /// @notice internal function that make calls to modules
    /// @param data Array of module calls
    /// @param value msg.value
    function _makeModuleCalls(
        ModuleCall[] memory data,
        uint256 value
    ) internal {
        for (uint256 i = 0; i < data.length; ++i) {
            address module = data[i].module;
            if (!modulesCatalogue[module]) {
                revert UndefinedModule(module);
            }
            for (uint256 j = 0; j < data[i].callData.length; j++) {
                Address.functionDelegateCall(module, data[i].callData[j]);
                emit ModuleCalled(module, data[i].callData[j], value);
            }
        }
    }

    /// @notice Internal function that performs creating of withdraw request.
    /// @param _receiver Address to send assets
    /// @param _owner Address of owner
    /// @param _shares Amount of shares
    /// @param _assets Amount of assets
    function _createQueueItem(
        address _receiver,
        address _owner,
        uint256 _shares,
        uint256 _assets
    ) internal returns (uint256) {
        uint256 queueItemId = _getWithdrawQueueItemId();

        WithdrawalQueueItem storage queueItem = withdrawQueue[queueItemId];

        queueItem.id = queueItemId;
        queueItem.receiver = _receiver;
        queueItem.owner = _owner;
        queueItem.sharesAmount = _shares;
        queueItem.assetsAmount = _assets;
        queueItem.isOpen = true;

        return queueItemId;
    }

    function _removePosition(uint32 index, uint32 positionId) internal {
        strategies.remove(index);

        isStrategyUsed[positionId] = false;
        delete getStrategyData[positionId];

        emit StrategyRemoved(positionId, index);
    }

    function _getBalance(uint32 strategy) public view returns (uint256) {
        address adaptor = getStrategyData[strategy].module;
        return
            BaseModule(adaptor).getBalance(
                getStrategyData[strategy].moduleData
            );
    }

    function _baseAsset(uint32 position) public view returns (address) {
        address adaptor = getStrategyData[position].module;
        return
            address(
                BaseModule(adaptor).baseAsset(
                    getStrategyData[position].moduleData
                )
            );
    }

    /// @notice Internal function that returns withdraw queue item id.
    function _getWithdrawQueueItemId() internal returns (uint128) {
        return withdrawQueueItemId++;
    }

    /// @notice return vault balance in assets
    function _vaultBalance() internal view returns (uint256) {
        return asset.balanceOf(address(this));
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(AccessControl, ERC1155Holder)
        returns (bool)
    {
        return
            interfaceId == type(AccessControl).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}