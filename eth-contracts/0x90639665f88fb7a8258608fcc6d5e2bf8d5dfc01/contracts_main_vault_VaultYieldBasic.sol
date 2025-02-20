// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.25;

import "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";
import "./openzeppelin_contracts-upgradeable_utils_PausableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_utils_ReentrancyGuardUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC20_extensions_ERC4626Upgradeable.sol";
import "./contracts_interfaces_IRedeemOperator.sol";
import "./contracts_interfaces_IStrategy.sol";
import "./contracts_interfaces_IVault.sol";
import "./contracts_main_libraries_StorageSlot.sol";
import "./contracts_main_libraries_Errors.sol";
import "./contracts_main_vault_StrategyFactory.sol";

/**
 * @title VaultYieldBasic contract
 * @author Naturelab
 * @dev This contract is the logical implementation of the vault,
 * and its main purpose is to provide users with a gateway for depositing
 * and withdrawing funds and to manage user shares.
 */
contract VaultYieldBasic is
    IVault,
    StrategyFactory,
    ERC4626Upgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;
    using StorageSlot for *;
    using EnumerableSet for EnumerableSet.AddressSet;

    // Use EIP-1153 to temporarily store prices for calculation.
    bytes32 internal constant EXCHANGE_PRICE_CACHE = keccak256("EXCHANGE_PRICE_CACHE");

    // Define a constant variable representing the fee denominator, 10000 (used for percentage calculations)
    uint256 internal constant FEE_DENOMINATOR = 1e4;

    // Up to 0.04% can be charged as a management fee in each cycle (4 / 10000)
    uint256 internal constant MAX_MANAGEMENT_FEE_RATE = 4;

    // The shortest cycle for charging the management fee is 7 days
    uint256 internal constant MIN_MANAGEMENT_FEE_CLAIM_PERIOD = 7 days;

    // The maximum interval for price updates. If prices are not updated for a long time,
    // deposits will be temporarily unavailable.
    uint256 internal constant MAX_PRICE_UPDATED_PERIOD = 3 days;

    // The maximum fee for withdrawing from the idle treasury is 1.2% (120 / 10000)
    uint256 internal constant MAX_EXIT_FEE_RATE = 120;

    // The maximum revenue fee rate is 15% (1500 / 10000)
    uint256 internal constant MAX_REVENUE_FEE_RATE = 1500;

    // Prevents erroneous price fluctuations. (100 / 10000)
    uint256 internal constant MAX_PRICE_CHANGE_RATE = 100;

    // Units of measurement used for precise calculations.
    uint256 internal immutable PRECISION;

    // Used to determine the initial exchange price.
    uint256 internal immutable INIT_EXCHANGE_PRICE;

    // Used to limit the minimum initial price.
    uint256 internal immutable MIN_MARKET_CAPACITY;

    // Vault parameters, encapsulating the configuration of the vault
    VaultParams internal vaultParams;

    // Vault state, encapsulating the state of the vault
    VaultState internal vaultState;

    // Used to manage tokens allowed to be deposited.
    EnumerableSet.AddressSet internal tokens;

    // The amount of unbacked minted shares
    uint256 public unbackedMintedAmount;

    // The allowed contract to mint unbacked shares
    address public unbackedMinter;

    /**
     * @dev  Ensure that this method is only called by authorized portfolio managers.
     */
    modifier onlyRebalancer() {
        if (msg.sender != vaultParams.rebalancer) revert Errors.CallerNotRebalancer();
        _;
    }

    /**
     * @dev Ensure that this method is only called by the unbacked minter.
     */
    modifier onlyUnbackedMinter() {
        if (msg.sender != unbackedMinter) revert Errors.CallerNotMinter();
        _;
    }

    constructor(uint256 _precision, uint256 _minMarketCapacity) {
        PRECISION = _precision;
        INIT_EXCHANGE_PRICE = _precision;
        MIN_MARKET_CAPACITY = _minMarketCapacity;
    }

    /**
     * @dev Initialize various parameters of the Vault contract.
     * @param _initBytes The encoded initialization parameters.
     */
    function initialize(bytes calldata _initBytes) external initializer {
        (VaultParams memory params_, address[] memory tokens_) = abi.decode(_initBytes, (IVault.VaultParams, address[]));

        __Pausable_init();
        __ReentrancyGuard_init();
        __ERC20_init(params_.name, params_.symbol);

        if (params_.underlyingToken == address(0)) revert Errors.InvalidUnderlyingToken();
        if (params_.rebalancer == address(0)) revert Errors.InvalidRebalancer();
        if (params_.admin == address(0)) revert Errors.InvalidAdmin();
        if (params_.feeReceiver == address(0)) revert Errors.InvalidFeeReceiver();
        if (params_.marketCapacity < MIN_MARKET_CAPACITY) revert Errors.MarketCapacityTooLow();
        if (params_.managementFeeRate > MAX_MANAGEMENT_FEE_RATE) revert Errors.ManagementFeeRateTooHigh();
        if (params_.managementFeeClaimPeriod < MIN_MANAGEMENT_FEE_CLAIM_PERIOD) {
            revert Errors.ManagementFeeClaimPeriodTooShort();
        }
        if (params_.maxPriceUpdatePeriod > MAX_PRICE_UPDATED_PERIOD) revert Errors.PriceUpdatePeriodTooLong();
        if (params_.revenueRate > MAX_REVENUE_FEE_RATE) revert Errors.RevenueFeeRateTooHigh();
        if (params_.exitFeeRate > MAX_EXIT_FEE_RATE) revert Errors.ExitFeeRateTooHigh();
        __Ownable_init(params_.admin);
        __ERC4626_init(IERC20(params_.underlyingToken));
        vaultState.lastClaimMngFeeTime = block.timestamp;
        vaultState.lastUpdatePriceTime = block.timestamp;
        vaultState.exchangePrice = INIT_EXCHANGE_PRICE;
        vaultParams = params_;

        for (uint256 i; i < tokens_.length; i++) {
            if (tokens_[i] == address(0)) revert Errors.InvalidUnderlyingToken();
            tokens.add(tokens_[i]);
        }
    }

    /**
     * @dev Returns the vault parameters.
     * @return A struct containing the vault parameters.
     */
    function getVaultParams() public view returns (VaultParams memory) {
        return vaultParams;
    }

    /**
     * @dev Returns the vault state.
     * @return A struct containing the vault state.
     */
    function getVaultState() public view returns (VaultState memory) {
        return vaultState;
    }

    function getPrecison() public view returns (uint256) {
        return PRECISION;
    }

    function getTokens() public view returns (address[] memory) {
        return tokens.values();
    }

    /**
     * @dev Update the size of the pool's capacity.
     * @param _newCapacityLimit The new size of the capacity.
     */
    function updateMarketCapacity(uint256 _newCapacityLimit) external onlyOwner {
        if (_newCapacityLimit <= vaultParams.marketCapacity) revert Errors.UnSupportedOperation();
        emit UpdateMarketCapacity(vaultParams.marketCapacity, _newCapacityLimit);
        vaultParams.marketCapacity = _newCapacityLimit;
    }

    /**
     * @dev Update the management fee rate.
     * @param _newManagementFeeRate The new rate.
     */
    function updateManagementFee(uint256 _newManagementFeeRate) external onlyOwner {
        if (_newManagementFeeRate > MAX_MANAGEMENT_FEE_RATE) revert Errors.ManagementFeeRateTooHigh();
        emit UpdateManagementFee(vaultParams.managementFeeRate, _newManagementFeeRate);
        vaultParams.managementFeeRate = _newManagementFeeRate;
    }

    /**
     * @dev Update the collection cycle of management fees.
     * @param _newmanagementFeeClaimPeriod The new management fee claim period.
     */
    function updateManagementFeeClaimPeriod(uint256 _newmanagementFeeClaimPeriod) external onlyOwner {
        if (_newmanagementFeeClaimPeriod < MIN_MANAGEMENT_FEE_CLAIM_PERIOD) {
            revert Errors.ManagementFeeClaimPeriodTooShort();
        }
        emit UpdateManagementFeeClaimPeriod(vaultParams.managementFeeClaimPeriod, _newmanagementFeeClaimPeriod);
        vaultParams.managementFeeClaimPeriod = _newmanagementFeeClaimPeriod;
    }

    /**
     * @dev Update the maximum allowed price update period.
     * @param _newMaxPriceUpdatePeriod The new period.
     */
    function updateMaxPriceUpdatePeriod(uint256 _newMaxPriceUpdatePeriod) external onlyOwner {
        if (_newMaxPriceUpdatePeriod > MAX_PRICE_UPDATED_PERIOD) revert Errors.PriceUpdatePeriodTooLong();
        emit UpdateMaxPriceUpdatePeriod(vaultParams.maxPriceUpdatePeriod, _newMaxPriceUpdatePeriod);
        vaultParams.maxPriceUpdatePeriod = _newMaxPriceUpdatePeriod;
    }

    /**
     * @dev Update the revenue fee rate.
     * @param _newRevenueRate The new rate.
     */
    function updateRevenueRate(uint256 _newRevenueRate) external onlyOwner {
        if (_newRevenueRate > MAX_REVENUE_FEE_RATE) revert Errors.RevenueFeeRateTooHigh();
        emit UpdateRevenueRate(vaultParams.revenueRate, _newRevenueRate);
        vaultParams.revenueRate = _newRevenueRate;
    }

    /**
     * @dev Update the exit fee rate.
     * @param _newExitFeeRate The new rate.
     */
    function updateExitFeeRate(uint256 _newExitFeeRate) external onlyOwner {
        if (_newExitFeeRate > MAX_EXIT_FEE_RATE) revert Errors.ExitFeeRateTooHigh();
        emit UpdateExitFeeRate(vaultParams.exitFeeRate, _newExitFeeRate);
        vaultParams.exitFeeRate = _newExitFeeRate;
    }

    /**
     * @dev Add a new address to the position adjustment whitelist.
     * @param _newRebalancer The new address to be added.
     */
    function updateRebalancer(address _newRebalancer) external onlyOwner {
        if (_newRebalancer == address(0)) revert Errors.InvalidRebalancer();
        emit UpdateRebalancer(vaultParams.rebalancer, _newRebalancer);
        vaultParams.rebalancer = _newRebalancer;
    }

    /**
     * @dev Update the address of the unbacked minter.
     * @param _newUnbackedMinter The new address of the unbacked minter.
     */
    function updateUnbackedMinter(address _newUnbackedMinter) external onlyOwner {
        emit UpdateUnbackedMinter(unbackedMinter, _newUnbackedMinter);
        unbackedMinter = _newUnbackedMinter;
    }

    /**
     * @dev Update the address of the recipient for management fees.
     * @param _newFeeReceiver The new address of the recipient for management fees.
     */
    function updateFeeReceiver(address _newFeeReceiver) external onlyOwner {
        if (_newFeeReceiver == address(0)) revert Errors.InvalidFeeReceiver();
        emit UpdateFeeReceiver(vaultParams.feeReceiver, _newFeeReceiver);
        vaultParams.feeReceiver = _newFeeReceiver;
    }

    /**
     * @dev Update the temporary address of shares when users redeem.
     * @param _newRedeemOperator The new redeem operator address.
     */
    function updateRedeemOperator(address _newRedeemOperator) external onlyOwner {
        if (_newRedeemOperator == address(0)) revert Errors.InvalidRedeemOperator();
        emit UpdateRedeemOperator(vaultParams.redeemOperator, _newRedeemOperator);
        vaultParams.redeemOperator = _newRedeemOperator;
    }

    function addToken(address _newToken) external onlyOwner {
        if (_newToken == address(0)) revert Errors.InvalidUnderlyingToken();
        tokens.add(_newToken);

        emit AddToken(_newToken);
    }

    function removeToken(address _token) external onlyOwner {
        tokens.remove(_token);

        emit RemoveToken(_token);
    }

    /*
     * @return newExchangePrice The new exercise price
     * @return newRevenue The new realized profit.
     */
    function updateExchangePrice() external onlyRebalancer returns (uint256 newExchangePrice, uint256 newRevenue) {
        EXCHANGE_PRICE_CACHE.asUint256().tstore(vaultState.exchangePrice);
        vaultState.lastUpdatePriceTime = block.timestamp;
        uint256 totalSupply_ = totalSupply();
        if (totalSupply_ == 0) {
            return (vaultState.exchangePrice, vaultState.revenue);
        }
        uint256 currentNetAssets_ = underlyingTvl();
        newExchangePrice = currentNetAssets_ * PRECISION / totalSupply_;
        if (newExchangePrice > vaultState.revenueExchangePrice) {
            if (vaultState.revenueExchangePrice == 0) {
                vaultState.revenueExchangePrice = newExchangePrice;
                vaultState.exchangePrice = newExchangePrice;
                return (vaultState.exchangePrice, vaultState.revenue);
            }
            uint256 newProfit_ = currentNetAssets_ - ((vaultState.revenueExchangePrice * totalSupply_) / PRECISION);
            newRevenue = (newProfit_ * vaultParams.revenueRate) / FEE_DENOMINATOR;
            vaultState.revenue += newRevenue;
            uint256 oldExchangePrice_ = vaultState.exchangePrice;
            vaultState.exchangePrice = ((currentNetAssets_ - newRevenue) * PRECISION) / totalSupply_;
            if (vaultState.exchangePrice - oldExchangePrice_ > oldExchangePrice_ * MAX_PRICE_CHANGE_RATE / 1e4) {
                revert Errors.IncorrectState();
            }
            vaultState.revenueExchangePrice = vaultState.exchangePrice;
        } else {
            uint256 diffExchangePrice_ = vaultState.exchangePrice > newExchangePrice
                ? vaultState.exchangePrice - newExchangePrice
                : newExchangePrice - vaultState.exchangePrice;
            if (diffExchangePrice_ > vaultState.exchangePrice * MAX_PRICE_CHANGE_RATE / 1e4) {
                revert Errors.IncorrectState();
            }
            vaultState.exchangePrice = newExchangePrice;
        }

        emit UpdateExchangePrice(newExchangePrice, newRevenue);
    }

    /**
     * @dev Transfer tokens to a strategy.
     * @param _token The address of the token to transfer.
     * @param _amount The amount of tokens to transfer.
     * @param _strategyIndex The index of the strategy to transfer to.
     */
    function transferToStrategy(address _token, uint256 _amount, uint256 _strategyIndex) external {
        address caller_ = msg.sender;
        if (_strategyIndex == 0) {
            if (caller_ != owner() && caller_ != vaultParams.rebalancer) revert Errors.InvalidOperator();
        } else {
            if (caller_ != owner()) revert Errors.InvalidOperator();
        }
        address strategyAddress_ = strategyAddress(_strategyIndex);
        uint256 positionLimit_ = positionLimit[strategyAddress_];
        uint256 nowAssets_ = IStrategy(strategyAddress_).getNetAssets();
        uint8 coreDecimals_ = decimals();
        uint8 tokenDecimals_ = IERC20Metadata(_token).decimals();
        uint256 transferAsset_ = _amount;
        if (tokenDecimals_ > coreDecimals_) {
            transferAsset_ = _amount / (10 ** (tokenDecimals_ - coreDecimals_));
        } else if (tokenDecimals_ < coreDecimals_) {
            transferAsset_ = _amount * (10 ** (coreDecimals_ - tokenDecimals_));
        }
        if ((nowAssets_ + transferAsset_) > (totalAssets() * positionLimit_ / 1e4)) revert Errors.InvalidLimit();
        IERC20(_token).safeIncreaseAllowance(strategyAddress_, _amount);
        if (!IStrategy(strategyAddress_).onTransferIn(_token, _amount)) revert Errors.IncorrectState();

        emit TransferToStrategy(_token, _amount, _strategyIndex);
    }

    /**
     * @dev Retrieve the amount of the exit fee.
     * @param _assetAmount The amount of asset to be withdrawn.
     * @return withdrawFee_ The exit fee to be deducted.
     */
    function getWithdrawFee(uint256 _assetAmount) public view returns (uint256 withdrawFee_) {
        withdrawFee_ = _assetAmount * vaultParams.exitFeeRate / FEE_DENOMINATOR;
    }

    /**
     * @dev Retrieve the total value locked (TVL) in underlying assets.
     * @return The total value locked in underlying assets.
     */
    function underlyingTvl() public virtual returns (uint256) {
        uint256 totalBal_;
        address token_;
        uint8 coreDecimals = decimals();

        for (uint256 i = 0; i < tokens.length(); i++) {
            token_ = tokens.at(i);

            uint256 tokenBal_ = IERC20(token_).balanceOf(address(this));
            uint8 tokenDecimals = IERC20Metadata(token_).decimals();

            // Adjust balance based on the difference in decimals
            if (tokenDecimals > coreDecimals) {
                // If tokenDecimals is greater than core asset decimals, scale down to match core asset
                tokenBal_ = tokenBal_ / (10 ** (tokenDecimals - coreDecimals));
            } else if (tokenDecimals < coreDecimals) {
                // If tokenDecimals is less than core asset decimals, scale up to match core asset
                tokenBal_ = tokenBal_ * (10 ** (coreDecimals - tokenDecimals));
            }

            totalBal_ += tokenBal_;
        }

        uint256 totalStrategy_ = totalStrategiesAssets();
        return totalStrategy_ + totalBal_ - vaultState.revenue;
    }

    /**
     * @dev Retrieve the amount of the actual shares in the vault.
     * @return The total amount of shares in the vault.
     */
    function totalSupply() public view override(ERC20Upgradeable, IERC20) returns (uint256) {
        return ERC20Upgradeable.totalSupply() - unbackedMintedAmount;
    }

    /**
     * @dev Retrieve the amount of assets in the strategy pool.
     * @return The total assets in the strategy pool.
     */
    function totalAssets() public view override returns (uint256) {
        if (block.timestamp - vaultState.lastUpdatePriceTime > vaultParams.maxPriceUpdatePeriod) {
            revert Errors.PriceNotUpdated();
        }

        return vaultState.exchangePrice * totalSupply() / PRECISION;
    }

    /**
     * @return Actual LP price during the user's deposit phase.
     */
    function exchangePrice() public view override returns (uint256) {
        return vaultState.exchangePrice;
    }

    /**
     * @dev When the actual LP price exceeds this price, performance fee settlement can be conducted.
     * @return LP price for settling performance fees.
     */
    function revenueExchangePrice() public view override returns (uint256) {
        return vaultState.revenueExchangePrice;
    }

    /**
     * @return Currently accumulated performance fees.
     */
    function revenue() public view override returns (uint256) {
        return vaultState.revenue;
    }

    /**
     * @return The remaining time. If it is 0, deposits are currently not allowed.
     * @dev If it is not 0, the admin needs to update the price within this period.
     */
    function remainingUpdateTime() public view returns (uint256) {
        uint256 timeDiff_ = block.timestamp - vaultState.lastUpdatePriceTime;
        return vaultParams.maxPriceUpdatePeriod > timeDiff_ ? (vaultParams.maxPriceUpdatePeriod - timeDiff_) : 0;
    }

    /**
     * @dev Retrieve the maximum amount that can be deposited by an address.
     * @return maxAssets_ The maximum deposit amount.
     */
    function maxDeposit(address) public view override returns (uint256 maxAssets_) {
        maxAssets_ = vaultParams.marketCapacity - totalAssets();
    }

    /**
     * @return The actual LP price before the last update.
     * @dev If it is lower than current price, there might be a withdrawal rebalancing loss,
     * which the user needs to bear. This usually does not happen.
     */
    function lastExchangePrice() public view override returns (uint256) {
        return EXCHANGE_PRICE_CACHE.asUint256().tload();
    }

    /**
     * @dev Optional deposit function allowing deposits in different token types.
     * @param _token The address of the token to deposit.
     * @param _assets The amount of assets to deposit.
     * @param _receiver The address of the receiver of the shares.
     * @param _referral  Address of the referrer.
     * @return shares_ The amount of shares issued.
     */
    function optionalDeposit(address _token, uint256 _assets, address _receiver, address _referral)
        public
        payable
        virtual
        nonReentrant
        whenNotPaused
        returns (uint256 shares_)
    {
        if (vaultParams.maxPriceUpdatePeriod < block.timestamp - vaultState.lastUpdatePriceTime) {
            revert Errors.PriceNotUpdated();
        }
        if (_token != asset()) revert Errors.InvalidUnderlyingToken();
        shares_ = super.deposit(_assets, _receiver);

        emit OptionalDeposit(msg.sender, _token, _assets, _receiver, _referral);
    }

    /**
     * @dev Redemption operation executed by the redeemOperator. Currently, only rsETH redemptions are supported.
     * @param _token The address of the token to be redeemed.
     * @param _shares The amount of share tokens to be redeemed.
     * @param _cutPercentage The percentage of the rebalancing loss incurred.
     * @param _receiver The address of the receiver of the assets.
     * @param _owner The owner address of the shares.
     * @return assetsAfterFee_ The amount of assets obtained.
     */
    function optionalRedeem(address _token, uint256 _shares, uint256 _cutPercentage, address _receiver, address _owner)
        public
        override
        nonReentrant
        whenNotPaused
        returns (uint256 assetsAfterFee_)
    {
        if (!tokens.contains(_token)) revert Errors.InvalidAsset();
        if (msg.sender != vaultParams.redeemOperator) revert Errors.UnSupportedOperation();
        if (vaultState.lastUpdatePriceTime != block.timestamp) revert Errors.PriceNotUpdated();

        if (_shares == type(uint256).max) {
            _shares = maxRedeem(_owner);
        } else {
            require(_shares <= maxRedeem(_owner), "ERC4626: redeem more than max");
        }

        if (msg.sender != _owner) {
            _spendAllowance(_owner, msg.sender, _shares);
        }

        uint256 assets_ = previewRedeem(_shares * (PRECISION - _cutPercentage) / PRECISION);
        _burn(_owner, _shares);
        assetsAfterFee_ = assets_ - getWithdrawFee(assets_);

        IERC20(_token).safeTransfer(_receiver, assetsAfterFee_);

        emit OptionalRedeem(_token, _shares, _receiver, _owner);
    }

    /**
     * @dev The deposit method of ERC4626, with the parameter being the amount of assets.
     * @param _assets The amount of asset being deposited.
     * @param _receiver The recipient of the share tokens.
     * @return shares_ The amount of share tokens obtained.
     */
    function deposit(uint256 _assets, address _receiver)
        public
        override
        nonReentrant
        whenNotPaused
        returns (uint256 shares_)
    {
        if (vaultParams.maxPriceUpdatePeriod < block.timestamp - vaultState.lastUpdatePriceTime) {
            revert Errors.PriceNotUpdated();
        }

        if (_assets == type(uint256).max) {
            _assets = IERC20(asset()).balanceOf(msg.sender);
        }
        shares_ = super.deposit(_assets, _receiver);
    }

    /**
     * @dev The deposit method of ERC4626, with the parameter being the amount of share tokens.
     * @param _shares The amount of share tokens to be minted.
     * @param _receiver The recipient of the share tokens.
     * @return assets_ The amount of assets consumed.
     */
    function mint(uint256 _shares, address _receiver)
        public
        override
        nonReentrant
        whenNotPaused
        returns (uint256 assets_)
    {
        if (vaultParams.maxPriceUpdatePeriod < block.timestamp - vaultState.lastUpdatePriceTime) {
            revert Errors.PriceNotUpdated();
        }

        assets_ = super.mint(_shares, _receiver);
    }

    function withdraw(uint256, address, address) public override returns (uint256) {
        // Only delayed withdrawals are supported
        revert Errors.NotSupportedYet();
    }

    function redeem(uint256, address, address) public override returns (uint256) {
        // Only delayed withdrawals are supported
        revert Errors.NotSupportedYet();
    }

    /**
     * @dev Burn unbacked minted shares.
     */
    function burnUnbacked(uint256 _amount) external onlyUnbackedMinter {
        if (_amount > unbackedMintedAmount) revert Errors.InvalidShares();
        unbackedMintedAmount -= _amount;
        _burn(unbackedMinter, _amount);
    }

    /**
     * @dev Mint unbacked minted shares, for providing liquidity on L2.
     */
    function mintUnbacked(uint256 _amount) external onlyUnbackedMinter {
        unbackedMintedAmount += _amount;
        _mint(unbackedMinter, _amount);
    }

    /**
     * @dev When a user applies for redemption, his share will be
     * transferred to the RedeemOperator address.
     * @param _shares The amount of share tokens to be redeemed.
     * @param _token The address of the token to redeem.
     */
    function requestRedeem(uint256 _shares, address _token) external nonReentrant whenNotPaused {
        if (_shares == 0) revert Errors.WithdrawZero();
        _transfer(msg.sender, vaultParams.redeemOperator, _shares);
        IRedeemOperator(vaultParams.redeemOperator).registerWithdrawal(msg.sender, _shares);

        emit RequestRedeem(msg.sender, _shares, _token);
    }

    /**
     * @dev Collect management fee.
     */
    function collectManagementFee() external {
        if (msg.sender != vaultParams.feeReceiver) revert Errors.InvalidFeeReceiver();
        uint256 nowTime_ = block.timestamp;
        if (nowTime_ - vaultState.lastClaimMngFeeTime < vaultParams.managementFeeClaimPeriod) {
            revert Errors.InvalidClaimTime();
        }
        vaultState.lastClaimMngFeeTime = nowTime_;
        uint256 assets_ = totalAssets() * vaultParams.managementFeeRate / FEE_DENOMINATOR;
        IERC20(asset()).safeTransfer(vaultParams.feeReceiver, assets_);

        emit CollectManagementFee(assets_);
    }

    /**
     * @dev Collect performance fees to the recipient address.
     */
    function collectRevenue() external {
        if (msg.sender != vaultParams.feeReceiver) revert Errors.InvalidFeeReceiver();
        IERC20(asset()).safeTransfer(vaultParams.feeReceiver, vaultState.revenue);
        emit CollectRevenue(vaultState.revenue);
        vaultState.revenue = 0;
    }

    function pause() external {
        if (msg.sender != owner() && msg.sender != vaultParams.rebalancer) revert Errors.UnSupportedOperation();
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    receive() external payable {}
}