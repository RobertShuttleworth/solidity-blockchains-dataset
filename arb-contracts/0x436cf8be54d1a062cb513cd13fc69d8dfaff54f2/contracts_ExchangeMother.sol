// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import { IERC20Metadata } from "./openzeppelin_contracts_token_ERC20_extensions_IERC20Metadata.sol";
import { SafeERC20, IERC20 } from "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";
import { Initializable } from "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";
import { AccessControlUpgradeable } from "./openzeppelin_contracts-upgradeable_access_AccessControlUpgradeable.sol";
import { UUPSUpgradeable } from "./openzeppelin_contracts-upgradeable_proxy_utils_UUPSUpgradeable.sol";
import { PausableUpgradeable } from "./openzeppelin_contracts-upgradeable_security_PausableUpgradeable.sol";

import { IInsuranceExchange, Multicall2 } from "./contracts_interfaces_IInsuranceExchange.sol";
import { IPortfolioManager } from "./contracts_interfaces_IPortfolioManager.sol";
import { IRemoteHub, IXusdToken, IPayoutManager, IRoleManager } from "./contracts_interfaces_IRemoteHub.sol";
import { IStrategy } from "./contracts_interfaces_IStrategy.sol";
import { NonRebaseInfo } from "./contracts_interfaces_IPayoutManager.sol";

contract ExchangeMother is Initializable, AccessControlUpgradeable, UUPSUpgradeable, PausableUpgradeable {
    uint256 public constant LIQ_DELTA_DM = 1e6;
    uint256 public constant RISK_FACTOR_DM = 1e5;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 public reentrancyGuardStatus;

    IERC20 public asset;

    IPortfolioManager public portfolioManager; //portfolio manager contract

    address public profitRecipient;

    uint256 public buyFee;
    uint256 public buyFeeDenominator; // ~ 100 %

    uint256 public redeemFee;
    uint256 public redeemFeeDenominator; // ~ 100 %

    // next payout time in epoch seconds
    uint256 public nextPayoutTime;

    // period between payouts in seconds, need to calc nextPayoutTime
    uint256 public payoutPeriod;

    uint256 public payoutTimeRange;

    address public blockGetter;

    // last block number when buy/redeem was executed
    uint256 public lastBlockNumber;

    uint256 private DELETED_1;
    uint256 public abroadMax;

    address public insurance;

    uint256 public oracleLoss;
    uint256 public oracleLossDenominator;

    uint256 public compensateLoss;
    uint256 public compensateLossDenominator;

    uint256 public profitFee;
    uint256 public profitFeeDenominator;

    IRemoteHub public remoteHub;

    // ---  events

    event AssetUpdated(address asset);
    event RemoteHubUpdated(address remoteHub);
    event PortfolioManagerUpdated(address portfolioManager);
    event BuyFeeUpdated(uint256 fee, uint256 feeDenominator);
    event RedeemFeeUpdated(uint256 fee, uint256 feeDenominator);
    event ProfitFeeUpdated(uint256 fee, uint256 feeDenominator);
    event PayoutTimesUpdated(uint256 nextPayoutTime, uint256 payoutPeriod, uint256 payoutTimeRange);
    event InsuranceUpdated(address insurance);
    event BlockGetterUpdated(address blockGetter);
    event ProfitRecipientUpdated(address recipient);
    event OracleLossUpdate(uint256 oracleLoss, uint256 denominator);
    event CompensateLossUpdate(uint256 compensateLoss, uint256 denominator);
    event MaxAbroadUpdated(uint256 abroad);
    event EventExchange(string label, uint256 amount, uint256 fee, address sender);
    event PayoutEvent(uint256 profit, uint256 excessProfit, uint256 insurancePremium, uint256 insuranceLoss);
    event NextPayoutTime(uint256 nextPayoutTime);
    event PayoutSimulationForInsurance(int256 premium);

    error OracleLoss();
    error SimilationRevert();

    // ---  initializer

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function UPGRADER_ROLE() public pure returns (bytes32) {
        return keccak256("UPGRADER_ROLE");
    }

    function initialize(address _remoteHub) public initializer {
        __AccessControl_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE(), msg.sender);

        buyFee = 40;
        buyFeeDenominator = 100000;

        redeemFee = 40;
        redeemFeeDenominator = 100000;

        // 1637193600 = 2021-11-18T00:00:00Z
        nextPayoutTime = 1637193600;
        payoutPeriod = 24 * 60 * 60;
        payoutTimeRange = 24 * 60 * 60; // 24 hours
        abroadMax = 1000350;
        oracleLossDenominator = 100000;
        compensateLossDenominator = 100000;

        profitFee = 0; // 0%
        profitFeeDenominator = 100000;

        remoteHub = IRemoteHub(_remoteHub);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyUpgrader {}

    // ---  remoteHub getters

    function roleManager() internal view returns (IRoleManager) {
        return remoteHub.roleManager();
    }

    function xusd() internal view returns (IXusdToken) {
        return remoteHub.xusd();
    }

    function payoutManager() internal view returns (IPayoutManager) {
        return remoteHub.payoutManager();
    }

    // ---  modifiers

    modifier onlyPortfolioAgent() {
        IRoleManager _roleManager = roleManager();
        require(
            _roleManager.hasRole(_roleManager.PORTFOLIO_AGENT_ROLE(), msg.sender),
            "Caller doesn't have PORTFOLIO_AGENT_ROLE role"
        );
        _;
    }

    modifier onlyUnit() {
        IRoleManager _roleManager = roleManager();
        require(_roleManager.hasRole(_roleManager.UNIT_ROLE(), msg.sender), "Caller doesn't have UNIT_ROLE role");
        _;
    }

    modifier onlyUpgrader() {
        require(hasRole(UPGRADER_ROLE(), msg.sender), "Caller doesn't have UPGRADER_ROLE role");
        _;
    }

    modifier nonReentrant() {
        require(reentrancyGuardStatus != _ENTERED, "ReentrancyGuard: reentrant call");
        reentrancyGuardStatus = _ENTERED;
        _;
        reentrancyGuardStatus = _NOT_ENTERED;
    }

    // --- setters

    function setAsset(address _asset) external onlyUpgrader {
        require(_asset != address(0), "Zero address not allowed");
        asset = IERC20(_asset);
        emit AssetUpdated(_asset);
    }

    function setPortfolioManager(address _portfolioManager) external onlyUpgrader {
        require(_portfolioManager != address(0), "Zero address not allowed");
        portfolioManager = IPortfolioManager(_portfolioManager);
        emit PortfolioManagerUpdated(_portfolioManager);
    }

    function setRemoteHub(address _remoteHub) external onlyUpgrader {
        require(_remoteHub != address(0), "Zero address not allowed");
        remoteHub = IRemoteHub(_remoteHub);
        emit RemoteHubUpdated(_remoteHub);
    }

    function setInsurance(address _insurance) external onlyUpgrader {
        require(_insurance != address(0), "Zero address not allowed");
        insurance = _insurance;
        emit InsuranceUpdated(_insurance);
    }

    function setBlockGetter(address _blockGetter) external onlyUpgrader {
        require(_blockGetter != address(0), "Zero address not allowed");
        blockGetter = _blockGetter;
        emit BlockGetterUpdated(_blockGetter);
    }

    function setProfitRecipient(address _profitRecipient) external onlyUpgrader {
        require(_profitRecipient != address(0), "Zero address not allowed");
        profitRecipient = _profitRecipient;
        emit ProfitRecipientUpdated(_profitRecipient);
    }

    function setBuyFee(uint256 _fee, uint256 _feeDenominator) external onlyPortfolioAgent {
        require(_feeDenominator != 0, "Zero denominator not allowed");
        require(_feeDenominator >= _fee, "fee > denominator");
        buyFee = _fee;
        buyFeeDenominator = _feeDenominator;
        emit BuyFeeUpdated(buyFee, buyFeeDenominator);
    }

    function setRedeemFee(uint256 _fee, uint256 _feeDenominator) external onlyPortfolioAgent {
        require(_feeDenominator != 0, "Zero denominator not allowed");
        require(_feeDenominator >= _fee, "fee > denominator");
        redeemFee = _fee;
        redeemFeeDenominator = _feeDenominator;
        emit RedeemFeeUpdated(redeemFee, redeemFeeDenominator);
    }

    function setProfitFee(uint256 _fee, uint256 _feeDenominator) external onlyPortfolioAgent {
        require(_feeDenominator != 0, "Zero denominator not allowed");
        require(_feeDenominator >= _fee, "fee > denominator");
        profitFee = _fee;
        profitFeeDenominator = _feeDenominator;
        emit ProfitFeeUpdated(profitFee, profitFeeDenominator);
    }

    function setOracleLoss(uint256 _oracleLoss, uint256 _denominator) external onlyPortfolioAgent {
        require(_denominator != 0, "Zero denominator not allowed");
        oracleLoss = _oracleLoss;
        oracleLossDenominator = _denominator;
        emit OracleLossUpdate(_oracleLoss, _denominator);
    }

    function setCompensateLoss(uint256 _compensateLoss, uint256 _denominator) external onlyPortfolioAgent {
        require(_denominator != 0, "Zero denominator not allowed");
        compensateLoss = _compensateLoss;
        compensateLossDenominator = _denominator;
        emit CompensateLossUpdate(_compensateLoss, _denominator);
    }

    function setMaxAbroad(uint256 _max) external onlyPortfolioAgent {
        abroadMax = _max;
        emit MaxAbroadUpdated(abroadMax);
    }

    function setPayoutTimes(
        uint256 _nextPayoutTime,
        uint256 _payoutPeriod,
        uint256 _payoutTimeRange
    ) external onlyPortfolioAgent {
        require(_nextPayoutTime != 0, "Zero _nextPayoutTime not allowed");
        require(_payoutPeriod != 0, "Zero _payoutPeriod not allowed");
        require(_nextPayoutTime > _payoutTimeRange, "_nextPayoutTime shoud be more than _payoutTimeRange");
        nextPayoutTime = _nextPayoutTime;
        payoutPeriod = _payoutPeriod;
        payoutTimeRange = _payoutTimeRange;
        emit PayoutTimesUpdated(nextPayoutTime, payoutPeriod, payoutTimeRange);
    }

    // ---  logic

    function pause() public onlyPortfolioAgent {
        _pause();
    }

    function unpause() public onlyPortfolioAgent {
        _unpause();
    }

    struct MintParams {
        address asset;
        uint256 amount;
    }

    // Minting xUSD in exchange for an asset
    function mint(MintParams calldata params) external whenNotPaused nonReentrant returns (uint256) {
        address _asset = params.asset;
        uint256 _amount = params.amount;

        require(_asset == address(asset), "Only asset available for buy");

        uint256 currentBalance = asset.balanceOf(msg.sender);
        require(currentBalance >= _amount, "Not enough tokens to buy");

        require(_amount > 0, "Amount of asset is zero");

        uint256 xusdAmount = _assetToRebase(_amount);
        require(xusdAmount > 0, "Amount of xUSD is zero");

        uint256 _targetBalance = asset.balanceOf(address(portfolioManager)) + _amount;
        SafeERC20.safeTransferFrom(asset, msg.sender, address(portfolioManager), _amount);
        require(asset.balanceOf(address(portfolioManager)) == _targetBalance, "pm balance != target");

        portfolioManager.deposit();
        _requireOncePerBlock(false);

        uint256 buyFeeAmount;
        uint256 buyAmount;
        (buyAmount, buyFeeAmount) = _takeFee(xusdAmount, true);

        xusd().mint(msg.sender, buyAmount);

        emit EventExchange("mint", buyAmount, buyFeeAmount, msg.sender);

        return buyAmount;
    }

    /**
     * @param _asset Asset to redeem
     * @param _amount Amount of xUSD to burn
     * @return Amount of asset unstacked and transferred to caller
     */
    function redeem(address _asset, uint256 _amount) external whenNotPaused nonReentrant returns (uint256) {
        require(_asset == address(asset), "Only asset available for redeem");
        require(_amount > 0, "Amount of xUSD is zero");
        require(xusd().balanceOf(msg.sender) >= _amount, "Not enough tokens to redeem");

        uint256 assetAmount = _rebaseToAsset(_amount);
        require(assetAmount > 0, "Amount of asset is zero");

        uint256 redeemFeeAmount;
        uint256 redeemAmount;

        (redeemAmount, redeemFeeAmount) = _takeFee(assetAmount, false);

        (, bool isBalanced) = portfolioManager.withdraw(redeemAmount);
        _requireOncePerBlock(isBalanced);

        xusd().burn(msg.sender, _amount);

        require(asset.balanceOf(address(this)) >= redeemAmount, "Not enough for transfer redeemAmount");
        SafeERC20.safeTransfer(asset, msg.sender, redeemAmount);

        emit EventExchange("redeem", redeemAmount, redeemFeeAmount, msg.sender);

        return redeemAmount;
    }

    /**
     * @dev Payout
     * The root method of protocol xUSD
     * Calculates delta total NAV - total supply xUSD and accrues profit or loss among all token holders
     *
     * What this method does?
     * - Claim rewards from all strategy
     * - Increase liquidity index xUSD on amount of profit
     * - Decrease liquidity index xUSD on amount of loss
     *
     * Support Insurance mode: Only if insurance is set
     * What are Insurance's main actions?
     * If xUSD has loss then Exchange covers the loss through Insurance
     * if xUSD has profit then Exchange send premium amount to Insurance
     *
     * Explain params:
     * @param simulate - allow to get amount loss/premium for prepare swapData (call.static)
     * @param swapData - Odos swap data for swapping OVN->asset or asset->OVN in Insurance
     */
    function payout(
        bool simulate,
        IInsuranceExchange.SwapData memory swapData
    ) external payable whenNotPaused onlyUnit nonReentrant {
        IXusdToken _xusd = xusd();
        IPayoutManager _payoutManager = payoutManager();

        require(
            address(_payoutManager) != address(0) || _xusd.nonRebaseOwnersLength() == 0,
            "Need to specify payoutManager address"
        );
        require(block.timestamp + payoutTimeRange >= nextPayoutTime, "payout not ready");

        // 0. call claiming reward and balancing on PM
        // 1. get current amount of xUSD
        // 2. get total sum of asset we can get from any source
        // 3. calc difference between total count of xUSD and asset
        // 4. update xUSD liquidity index

        portfolioManager.claimAndBalance();

        uint256 totalXusd = _xusd.totalSupply();
        uint256 previousXusd = totalXusd;

        uint256 totalNav = _assetToRebase(portfolioManager.totalNetAssets());
        uint256 excessProfit;
        uint256 premium;
        uint256 loss;

        uint256 delta;

        if (totalXusd > totalNav) {
            // Negative rebase
            // xUSD have loss and we need to execute next steps:
            // 1. Loss may be related to oracles: we wait
            // 2. Loss is real then compensate all loss + [1] bps

            loss = totalXusd - totalNav;
            uint256 oracleLossAmount = (totalXusd * oracleLoss) / oracleLossDenominator;

            if (loss <= oracleLossAmount) {
                revert OracleLoss();
            } else {
                loss += (totalXusd * compensateLoss) / compensateLossDenominator;
                loss = _rebaseToAsset(loss);
                if (simulate) {
                    emit PayoutSimulationForInsurance(-int256(loss));
                    revert SimilationRevert();
                }
                if (swapData.amountIn != 0) {
                    IInsuranceExchange(insurance).compensate(swapData, loss, address(portfolioManager));
                    portfolioManager.deposit();
                }
            }
        } else {
            // Positive rebase
            // xUSD have profit and we need to execute next steps:
            // 1. Pay premium to Insurance
            // 2. If profit is more than max delta then transfer excess profit to OVN wallet

            if (profitFee > 0) {
                require(profitRecipient != address(0), "profitRecipient address is zero");
                uint256 profitRecipientAmount = ((totalNav - totalXusd) * profitFee) / profitFeeDenominator;
                portfolioManager.withdraw(profitRecipientAmount);
                SafeERC20.safeTransfer(asset, profitRecipient, profitRecipientAmount);
                totalNav = totalNav - _assetToRebase(profitRecipientAmount);
            }

            premium = _rebaseToAsset(((totalNav - totalXusd) * portfolioManager.getTotalRiskFactor()) / RISK_FACTOR_DM);

            if (simulate) {
                emit PayoutSimulationForInsurance(int256(premium));
                revert SimilationRevert();
            }

            if (premium > 0 && swapData.amountIn != 0) {
                portfolioManager.withdraw(premium);
                SafeERC20.safeTransfer(asset, insurance, premium);

                IInsuranceExchange(insurance).premium(swapData, premium);
                totalNav = totalNav - _assetToRebase(premium);
            }

            delta = (totalNav * LIQ_DELTA_DM) / _xusd.totalSupply();

            if (abroadMax < delta) {
                // Calculate the amount of xUSD to hit the maximum delta.
                // We send the difference to the OVN wallet.

                uint256 newTotalSupply = (totalNav * LIQ_DELTA_DM) / abroadMax;
                excessProfit = newTotalSupply - _xusd.totalSupply();

                // Mint xUSD to OVN wallet
                require(profitRecipient != address(0), "profitRecipient address is zero");
                _xusd.mint(profitRecipient, excessProfit);
            }
        }

        // In case positive rebase and negative rebase the value changes and we must update it:
        // - totalXusd
        // - totalNav

        totalXusd = _xusd.totalSupply();
        totalNav = _assetToRebase(portfolioManager.totalNetAssets());
        uint256 newDelta = (totalNav * LIQ_DELTA_DM) / totalXusd;

        require(totalNav >= totalXusd, "negative rebase");

        // Calculating how much users profit after excess fee
        uint256 profit = totalNav - totalXusd;

        uint256 expectedTotalXusd = previousXusd + profit + excessProfit;

        (NonRebaseInfo[] memory nonRebaseInfo, uint256 nonRebaseDelta) = _xusd.changeSupply(totalNav);

        // notify listener about payout done
        if (address(_payoutManager) != address(0)) {
            _xusd.mint(address(_payoutManager), nonRebaseDelta);
            _payoutManager.payoutDone(address(_xusd), nonRebaseInfo);
        }

        require(_xusd.totalSupply() == totalNav, "total != nav");
        require(_xusd.totalSupply() == expectedTotalXusd, "total != expected");

        remoteHub.execMultiPayout{ value: address(this).balance }(newDelta);

        emit PayoutEvent(profit, excessProfit, premium, loss);

        // Update next payout time. Cycle for preventing gaps
        // Allow execute payout every day in one time (10:00)

        // If we cannot execute payout (for any reason) in 10:00 and execute it in 15:00
        // then this cycle make 1 iteration and next payout time will be same 10:00 in next day

        // If we cannot execute payout more than 2 days and execute it in 15:00
        // then this cycle make 3 iteration and next payout time will be same 10:00 in next day

        for (; block.timestamp >= nextPayoutTime - payoutTimeRange; ) {
            nextPayoutTime = nextPayoutTime + payoutPeriod;
        }
        emit NextPayoutTime(nextPayoutTime);
    }

    function getAvailabilityInfo() external view returns (uint256 _available, bool _paused) {
        _paused = paused() || xusd().isPaused();

        IPortfolioManager.StrategyWeight[] memory weights = portfolioManager.getAllStrategyWeights();
        uint256 count = weights.length;

        for (uint8 i = 0; i < count; ++i) {
            IPortfolioManager.StrategyWeight memory weight = weights[i];
            IStrategy strategy = IStrategy(weight.strategy);

            if (weight.enabled) {
                _available += strategy.netAssetValue();
            }
        }
    }

    /**
     * @dev Protect from flashloan attacks
     * Allow execute only one mint or redeem transaction in per block
     * ONLY if balance function triggered on PortfolioManager
     * in other cases: stake/unstake only from cash strategy is safe
     */
    function _requireOncePerBlock(bool isBalanced) internal {
        // https://developer.arbitrum.io/time#case-study-multicall
        uint256 blockNumber = Multicall2(0x842eC2c7D803033Edf55E478F461FC547Bc54EB2).getBlockNumber();

        IRoleManager _roleManager = roleManager();
        bool isFreeRider = _roleManager.hasRole(_roleManager.FREE_RIDER_ROLE(), msg.sender);

        // Flag isBalanced take about:
        // PortfolioManager run balance function and unstake liquidity from non cash strategies
        // Check is not actual if stake/unstake will be only from cash strategy (for example Aave)
        if (!isFreeRider && isBalanced) {
            require(lastBlockNumber < blockNumber, "Only once in block");
        }

        lastBlockNumber = blockNumber;
    }

    function _takeFee(uint256 _amount, bool isBuy) internal view returns (uint256, uint256) {
        uint256 fee;
        uint256 feeDenominator;

        if (isBuy) {
            fee = buyFee;
            feeDenominator = buyFeeDenominator;
        } else {
            fee = redeemFee;
            feeDenominator = redeemFeeDenominator;
        }

        IRoleManager _roleManager = roleManager();
        bool isFreeRider = _roleManager.hasRole(_roleManager.FREE_RIDER_ROLE(), msg.sender);

        uint256 feeAmount = isFreeRider ? 0 : (_amount * fee) / feeDenominator;
        uint256 resultAmount = _amount - feeAmount;

        return (resultAmount, feeAmount);
    }

    function _rebaseToAsset(uint256 _amount) internal view returns (uint256) {
        uint256 assetDecimals = IERC20Metadata(address(asset)).decimals();
        uint256 xusdDecimals = xusd().decimals();
        if (assetDecimals > xusdDecimals) {
            _amount = _amount * (10 ** (assetDecimals - xusdDecimals));
        } else {
            _amount = _amount / (10 ** (xusdDecimals - assetDecimals));
        }

        return _amount;
    }

    function _assetToRebase(uint256 _amount) internal view returns (uint256) {
        uint256 assetDecimals = IERC20Metadata(address(asset)).decimals();
        uint256 xusdDecimals = xusd().decimals();
        if (assetDecimals > xusdDecimals) {
            _amount = _amount / (10 ** (assetDecimals - xusdDecimals));
        } else {
            _amount = _amount * (10 ** (xusdDecimals - assetDecimals));
        }
        return _amount;
    }

    // ---  for deploy
    // delete after deploy

    function initialize_v2() public reinitializer(2) onlyPortfolioAgent {
        reentrancyGuardStatus = _NOT_ENTERED;
        profitRecipient = 0x9030D5C596d636eEFC8f0ad7b2788AE7E9ef3D46;
        blockGetter = 0xE3c6B98B77BB5aC53242c4B51c566e95703538F7;
    }
}