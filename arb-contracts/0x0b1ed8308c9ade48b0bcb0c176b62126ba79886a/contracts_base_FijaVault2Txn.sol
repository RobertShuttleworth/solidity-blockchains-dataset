// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "./contracts_base_FijaVault.sol";
import "./contracts_interfaces_IFijaVault2Txn.sol";
import "./contracts_interfaces_IFijaStrategy2Txn.sol";
import "./contracts_base_types.sol";

import "./openzeppelin_contracts_utils_math_Math.sol";

///
/// @title FijaVault2Tx
/// @author Fija
/// @notice Enables users to deposit assets and receive vault tokens in return.
/// User can withdraw back assets by burning their vault tokens,
/// potentially increased for vault interest.
/// @dev In order for Vault to function properly, following needs to be completed:
/// - "Deployer" deployed Strategy which vault will use and it's address is known
/// - "Deployer" invoked Strategy.addAddressToWhitelist and added this Vault to Strategy's whitelist
/// NOTE: Vault supports 2 tx processes for deposits/withdraw/redeem
///
contract FijaVault2Txn is IFijaVault2Txn, FijaVault {
    using Math for uint256;

    ///
    /// @dev holder for input params of deposit/redeem/withdraw calls
    /// passed to strategy - strategy.deposit/withdraw/redeem will read
    /// this when called. This so we do not break IERC4626.
    ///
    TxParams internal _txParams;

    ///
    /// @dev flag indicating strategy is in update process
    ///
    bool internal _strategyUpdateInProgress;

    ///
    /// @dev fee for GMX keeper
    /// Taken into account with totalAssets,
    /// set here to not break IERC4626.
    ///
    uint256 internal _executionFee;

    constructor(
        IFijaStrategy strategy_,
        IERC20 asset_,
        string memory tokenName_,
        string memory tokenSymbol_,
        address governance_,
        address reseller_,
        uint256 approvalDelay_,
        uint256 maxTicketSize_,
        uint256 maxVaultValue_
    )
        FijaVault(
            strategy_,
            asset_,
            tokenName_,
            tokenSymbol_,
            governance_,
            reseller_,
            approvalDelay_,
            maxTicketSize_,
            maxVaultValue_
        )
    {
        _addAddressToWhitelist(address(strategy_));
    }

    ///
    /// @dev Throws if strategy is in update mode
    ///
    modifier isUpdateStrategyInProgress() {
        _strategyUpdateInProgressCheck();
        _;
    }

    ///
    /// @dev Throws if caller is not strategy or strategy candidate
    ///
    modifier onlyStrategy() {
        _onlyStrategy();
        _;
    }

    ///
    /// @dev gets amount of assets under vault management
    /// @return amount in assets
    ///
    function totalAssets()
        public
        view
        virtual
        override(FijaVault, IERC4626)
        returns (uint256)
    {
        if (asset() == ETH) {
            return super.totalAssets() - _executionFee;
        } else {
            return super.totalAssets();
        }
    }

    ///
    /// @dev calculates amount of vault tokens receiver will get from the Vault based on asset deposit.
    /// @param assets amount of assets caller wants to deposit
    /// @param receiver address of the owner of deposit once deposit completes, this address will receive vault tokens.
    /// @return amount of vault tokens receiver will receive
    /// NOTE: Main entry method for receiving deposits, which will be then distrubuted through strategy contract.
    /// Access rights for the method are defined by FijaERC4626Base contract.
    /// Caller and receiver must be whitelisted
    /// Additional parameters to strategy are passed by _txParams
    /// Emits IERC4626.Deposit
    ///
    function deposit(
        uint256 assets,
        address receiver
    )
        public
        payable
        virtual
        override(FijaVault, IERC4626)
        onlyWhitelisted
        nonZeroAmount(assets)
        onlyReceiverWhitelisted(receiver)
        isUpdateStrategyInProgress
        returns (uint256)
    {
        uint256 tokens;

        if (asset() == ETH) {
            uint256 executionFee = msg.value - assets;

            _executionFee = executionFee;
            uint256 totalAssetBeforeDeposit = totalAssets() - assets;
            require(
                assets <= _maxDeposit(receiver, totalAssetBeforeDeposit),
                "ERC4626: deposit more than max"
            );

            uint256 supply = totalSupply();
            tokens = (assets == 0 || supply == 0)
                ? _initialConvertToShares(assets, Math.Rounding.Down)
                : assets.mulDiv(
                    supply,
                    totalAssetBeforeDeposit,
                    Math.Rounding.Down
                );

            uint256 balance = address(this).balance;

            // store vault.deposit params for afterDeposit callback called by strategy in 2 tx
            _txParams = TxParams(
                assets,
                tokens,
                receiver,
                address(0),
                TxType.DEPOSIT
            );

            _strategy.deposit{value: balance}(
                balance - executionFee,
                address(this)
            );

            _txParams = TxParams(0, 0, address(0), address(0), TxType.DEPOSIT);
            _executionFee = 0;
        } else {
            require(
                assets <= maxDeposit(receiver),
                "ERC4626: deposit more than max"
            );

            tokens = ERC4626.previewDeposit(assets);

            SafeERC20.safeTransferFrom(
                IERC20(asset()),
                msg.sender,
                address(this),
                assets
            );

            uint256 balance = IERC20(asset()).balanceOf(address(this));

            SafeERC20.forceApprove(
                IERC20(asset()),
                address(_strategy),
                balance
            );
            // store vault.deposit params for afterDeposit callback called by strategy in 2 tx
            _txParams = TxParams(
                assets,
                tokens,
                receiver,
                address(0),
                TxType.DEPOSIT
            );

            _strategy.deposit{value: msg.value}(balance, address(this));

            _txParams = TxParams(0, 0, address(0), address(0), TxType.DEPOSIT);
        }
        return tokens;
    }

    ///
    /// @dev Burns exact number of vault tokens from owner and sends assets to receiver.
    /// This method is invoked by end user and is part of 1st tx in 2 tx redeem process.
    /// When afterRedeem callback is invoked by strategy in 2nd tx end user will receive assets.
    /// @param tokens amount of vault tokens caller wants to redeem
    /// @param receiver address of the asset receiver
    /// @param owner address of the owner of vault tokens
    /// @return amount of assets receiver will receive based on exact burnt vault tokens
    /// NOTE: Unwinds investments from strategy.
    /// Access rights for the method are defined by FijaERC4626Base contract.
    /// Caller, receiver and owner must be whitelisted
    /// Additional parameters to strategy are passed by _txParams
    /// Emits IERC4626.Withdraw
    ///
    function redeem(
        uint256 tokens,
        address receiver,
        address owner
    )
        public
        payable
        virtual
        override(FijaVault, IERC4626)
        onlyWhitelisted
        nonZeroAmount(tokens)
        onlyReceiverOwnerWhitelisted(receiver, owner)
        isUpdateStrategyInProgress
        returns (uint256)
    {
        uint256 assets;
        uint256 assetsToReturn;
        uint256 currentBalanceAvailable;

        if (asset() == ETH) {
            _executionFee = msg.value;

            // execution fee is reduced from current balance
            currentBalanceAvailable = address(this).balance - msg.value;
        } else {
            currentBalanceAvailable = IERC20(asset()).balanceOf(address(this));
        }
        assets = previewRedeem(tokens);

        if (tokens > maxRedeem(owner)) {
            revert VaultMaxRedeemExceeded();
        }

        if (assets <= currentBalanceAvailable) {
            assetsToReturn = FijaERC4626Base.redeem(tokens, receiver, owner);
        } else {
            SafeERC20.safeIncreaseAllowance(
                IERC20(_strategy),
                address(_strategy),
                type(uint256).max / 10
            );

            if (
                (!_strategyUpdateInProgress && msg.sender == owner) ||
                allowance(owner, msg.sender) >= tokens
            ) {
                _approve(
                    owner,
                    address(_strategy),
                    allowance(owner, address(_strategy)) +
                        type(uint256).max /
                        10
                );
            } else {
                revert VaultUnauthorizedCaller();
            }

            uint256 strategyTokens = _strategy.previewWithdraw(
                assets - currentBalanceAvailable
            );

            // store vault.deposit params for afterRedeem callback called by strategy in 2 tx
            _txParams = TxParams(0, tokens, receiver, owner, TxType.REDEEM);

            _strategy.redeem{value: msg.value}(
                strategyTokens,
                address(this),
                address(this)
            );

            _txParams = TxParams(0, 0, address(0), address(0), TxType.REDEEM);

            assetsToReturn = 0;
        }
        _executionFee = 0;

        return assetsToReturn;
    }

    ///
    /// @dev Burns tokens from owner and sends exact number of assets to receiver.
    /// This method is invoked by end user and is part of 1st tx in 2 tx withdrawal process.
    /// When afterWithdraw callback is invoked by strategy in 2nd tx end user will receive assets.
    /// @param assets amount of assets caller wants to withdraw
    /// @param receiver address of the asset receiver
    /// @param owner address of the owner of vault tokens
    /// @return amount of vault tokens burnt based on exact assets requested
    /// NOTE: Unwinds investments from strategy.
    /// Access rights for the method are defined by FijaERC4626Base contract.
    /// Caller, receiver and owner must be whitelisted
    /// Additional parameters to strategy are passed by _txParams
    /// Emits IERC4626.Withdraw
    ///
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    )
        public
        payable
        virtual
        override(FijaVault, IERC4626)
        onlyWhitelisted
        nonZeroAmount(assets)
        onlyReceiverOwnerWhitelisted(receiver, owner)
        isUpdateStrategyInProgress
        returns (uint256)
    {
        uint256 tokens;
        uint256 currentBalanceAvailableToUser;

        if (asset() == ETH) {
            _executionFee = msg.value;

            // execution fee is reduced from current balance
            currentBalanceAvailableToUser = address(this).balance - msg.value;
        } else {
            currentBalanceAvailableToUser = IERC20(asset()).balanceOf(
                address(this)
            );
        }
        if (assets > maxWithdraw(owner)) {
            revert VaultMaxRedeemExceeded();
        }

        if (assets <= currentBalanceAvailableToUser) {
            tokens = FijaERC4626Base.withdraw(assets, receiver, owner);
        } else {
            SafeERC20.safeIncreaseAllowance(
                IERC20(_strategy),
                address(_strategy),
                type(uint256).max / 10
            );

            if (
                msg.sender == owner ||
                allowance(owner, msg.sender) >= previewWithdraw(assets)
            ) {
                _approve(
                    owner,
                    address(_strategy),
                    allowance(owner, address(_strategy)) +
                        type(uint256).max /
                        10
                );
            } else {
                revert VaultUnauthorizedCaller();
            }

            // store vault withdraw params for afterWithdraw callback
            _txParams = TxParams(assets, 0, receiver, owner, TxType.WITHDRAW);

            _strategy.withdraw{value: msg.value}(
                assets - currentBalanceAvailableToUser,
                address(this),
                address(this)
            );

            _txParams = TxParams(0, 0, address(0), address(0), TxType.WITHDRAW);
            tokens = 0;
        }
        _executionFee = 0;

        return tokens;
    }

    ///
    /// NOTE: caller only strategy
    /// @inheritdoc IFijaVault2Txn
    ///
    function afterDeposit(
        uint256 assets,
        uint256 tokensToMint,
        address receiver,
        bool isSuccess
    ) external onlyStrategy {
        if (isSuccess) {
            if (!_strategyUpdateInProgress) {
                _mint(receiver, tokensToMint);
                emit Deposit(msg.sender, receiver, assets, tokensToMint);
            }
        } else {
            if (_strategyUpdateInProgress) {
                _strategyUpdateInProgress = false;
            }
            emit DepositFailed(receiver, assets, block.timestamp);
        }
    }

    ///
    /// NOTE: caller only strategy
    /// @inheritdoc IFijaVault2Txn
    ///
    function afterRedeem(
        uint256 tokens,
        address receiver,
        address owner,
        bool isSuccess
    ) external onlyStrategy {
        if (isSuccess) {
            if (!_strategyUpdateInProgress) {
                FijaERC4626Base.redeem(tokens, receiver, owner);
            }
        } else {
            if (_strategyUpdateInProgress) {
                _strategyUpdateInProgress = false;
            }

            emit RedeemFailed(receiver, owner, tokens, block.timestamp);
        }

        uint256 subtrahend = type(uint256).max / 10;
        if (
            _strategy.allowance(address(this), address(_strategy)) <= subtrahend
        ) {
            SafeERC20.safeApprove(IERC20(_strategy), address(_strategy), 0);
        } else {
            SafeERC20.safeDecreaseAllowance(
                IERC20(_strategy),
                address(_strategy),
                subtrahend
            );
        }

        if (!_strategyUpdateInProgress) {
            uint256 allowance = allowance(owner, address(_strategy));
            _approve(
                owner,
                address(_strategy),
                allowance <= subtrahend ? 0 : allowance - subtrahend
            );
        }
    }

    ///
    /// NOTE: caller only strategy
    /// @inheritdoc IFijaVault2Txn
    ///
    function afterWithdraw(
        uint256 assets,
        address receiver,
        address owner,
        bool isSuccess
    ) external onlyStrategy {
        if (isSuccess) {
            FijaERC4626Base.withdraw(assets, receiver, owner);
        } else {
            emit WithdrawFailed(receiver, owner, assets, block.timestamp);
        }

        uint256 subtrahend = type(uint256).max / 10;
        if (
            _strategy.allowance(address(this), address(_strategy)) <= subtrahend
        ) {
            SafeERC20.safeApprove(IERC20(_strategy), address(_strategy), 0);
        } else {
            SafeERC20.safeDecreaseAllowance(
                IERC20(_strategy),
                address(_strategy),
                subtrahend
            );
        }

        if (!_strategyUpdateInProgress) {
            uint256 allowance = allowance(owner, address(_strategy));
            _approve(
                owner,
                address(_strategy),
                allowance <= subtrahend ? 0 : allowance - subtrahend
            );
        }
    }

    ///
    /// @inheritdoc IFijaVault2Txn
    ///
    function txParams() external view returns (TxParams memory) {
        return _txParams;
    }

    ///
    /// NOTE: only be called when proposedTime + approvalDelay has passed,
    /// Update process is executed in multiple tx by first redeeming
    /// vault assets from current strategy and then depositing assets in new strategy
    /// @dev Updates strategy for vault
    /// Emits IFijaVault.UpdateStrategyEvent
    /// @inheritdoc IFijaVault
    ///
    function updateStrategy()
        public
        payable
        virtual
        override(FijaVault, IFijaVault)
        onlyGovernance
    {
        if (_strategyCandidate.implementation == address(0)) {
            revert VaultNoUpdateCandidate();
        }
        if (
            _strategyCandidate.proposedTime + _approvalDelay >= block.timestamp
        ) {
            revert VaultUpdateStrategyTimeError();
        }

        _strategyUpdateInProgress = true;

        _redeemFromCurrentStrategy();
    }

    ///
    /// @dev required gas to provide to GMX keeper to execute deposit/withdrawal requests
    /// @param txType enum to determine the type of transaction to calculate gas limit
    /// @return gas amount
    ///
    function getExecutionGasLimit(TxType txType) public view returns (uint256) {
        return
            IFijaStrategy2Txn(address(_strategy)).getExecutionGasLimit(txType);
    }

    ///
    /// @dev helper for withdrawing vault assets from current strategy as part of strategy update process
    ///
    function _redeemFromCurrentStrategy() private {
        uint256 remainingTokens = _strategy.balanceOf(address(this));
        // get assets back from strategy in batches
        if (remainingTokens > 0) {
            uint256 maxRedeem = _strategy.maxRedeem(address(this));
            uint256 redeemAmount = remainingTokens > maxRedeem
                ? maxRedeem
                : remainingTokens;

            SafeERC20.safeIncreaseAllowance(
                IERC20(_strategy),
                address(_strategy),
                type(uint256).max / 10
            );
            _strategy.redeem{value: msg.value}(
                redeemAmount,
                address(this),
                address(this)
            );

            return;
        }

        // give new strategy allowance for asset transfer
        if (asset() != ETH) {
            uint256 totalAssetsInVault = IERC20(asset()).balanceOf(
                address(this)
            );
            SafeERC20.forceApprove(
                IERC20(asset()),
                address(_strategyCandidate.implementation),
                totalAssetsInVault
            );
        }

        // deposit assets received from old strategy to new strategy
        // and receive strategy tokens from new strategy, in batches

        _depositToNewStrategy();
    }

    ///
    /// @dev helper for depositing vault assets to new strategy as part of strategy update process
    ///
    function _depositToNewStrategy() private {
        address newStrategy = _strategyCandidate.implementation;
        uint256 totalAssetsInVault;

        if (asset() == ETH) {
            totalAssetsInVault = address(this).balance - msg.value;
        } else {
            totalAssetsInVault = IERC20(asset()).balanceOf(address(this));
        }

        if (totalAssetsInVault > 0) {
            uint256 maxDeposit = IFijaStrategy(newStrategy).maxDeposit(
                address(this)
            );
            uint256 depositAmount = totalAssetsInVault > maxDeposit
                ? maxDeposit
                : totalAssetsInVault;

            uint256 ethValue;
            if (asset() == ETH) {
                ethValue = depositAmount + msg.value;
            } else {
                ethValue = msg.value;
            }
            IFijaStrategy(newStrategy).deposit{value: ethValue}(
                depositAmount,
                address(this)
            );
            return;
        }
        uint256 subtrahend = type(uint256).max / 10;
        if (
            _strategy.allowance(address(this), address(_strategy)) <= subtrahend
        ) {
            SafeERC20.safeApprove(IERC20(_strategy), address(_strategy), 0);
        } else {
            SafeERC20.safeDecreaseAllowance(
                IERC20(_strategy),
                address(_strategy),
                subtrahend
            );
        }

        _addAddressToWhitelist(newStrategy);
        _removeAddressFromWhitelist(address(_strategy));

        _strategyUpdateInProgress = false;

        _strategy = IFijaStrategy(newStrategy);
        // resets strategy candidate after strategy update has been completed
        _strategyCandidate.implementation = address(0);
        _strategyCandidate.proposedTime = type(uint64).max; //set proposed time to far future

        emit UpdateStrategyEvent(
            _strategyCandidate.implementation,
            block.timestamp
        );
    }

    ///
    /// @dev helper for modifier - checks if vault is updating strategy
    ///
    function _strategyUpdateInProgressCheck() internal view virtual {
        if (_strategyUpdateInProgress) {
            revert FijaStrategyUpdateInProgress();
        }
    }

    ///
    /// @dev helper for modifier - checks if vault is caller is strategy or strategy candidate
    ///
    function _onlyStrategy() internal view {
        bool isStrategySender = msg.sender == address(_strategy);
        bool isStrategyCandidateSender = msg.sender ==
            _strategyCandidate.implementation &&
            _strategyUpdateInProgress;

        if (!isStrategySender && !isStrategyCandidateSender) {
            revert VaultUnauthorizedAccess();
        }
    }
}