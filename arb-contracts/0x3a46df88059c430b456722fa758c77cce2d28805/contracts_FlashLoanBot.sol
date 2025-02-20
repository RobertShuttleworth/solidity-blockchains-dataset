// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * FRÅN OpenZeppelin:
 *    - IERC20 (standard)
 *    - SafeERC20 (safeApprove m.m.)
 *    - OwnableUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable ...
 */
import "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";
import "./openzeppelin_contracts-upgradeable_access_OwnableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_proxy_utils_UUPSUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_security_ReentrancyGuardUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC20_IERC20Upgradeable.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC20_utils_SafeERC20Upgradeable.sol";
import "./openzeppelin_contracts_governance_TimelockController.sol";

/**
 * FRÅN Aave:
 *   - IPoolAddressesProvider
 *   - IPool
 *   - IFlashLoanReceiver
 */
import "./aave_core-v3_contracts_interfaces_IPoolAddressesProvider.sol";
import "./aave_core-v3_contracts_interfaces_IPool.sol";
import "./aave_core-v3_contracts_flashloan_interfaces_IFlashLoanReceiver.sol";

/**
 * FRÅN Uniswap & Chainlink
 */
import "./uniswap_v2-periphery_contracts_interfaces_IUniswapV2Router02.sol";
import "./chainlink_contracts_src_v0.8_interfaces_AggregatorV3Interface.sol";

/**
 * Custom errors
 */
error ArbitrageAlreadyExecuting();
error DexesRequired();
error DexAddressZero();
error SlippageTooHigh();
error MinimumProfitZero();
error FractionTooHigh();
error InsufficientDexes();
error CallerNotAavePool();
error InitiatorNotContract();
error ProfitBelowMinThreshold();
error NoProfitableArbFound();
error NotProfitable();
error TriangularNotProfitable();
error MissingOracle(address token);
error InvalidPrice(address token);
error FeedOutdated(address token, bool isFromToken);
error GetAmountsOutFailed();
error SwapExactTokensFailed();

contract FlashLoanBot is
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable,
    IFlashLoanReceiver
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    // ------------------------------------
    // AAVE-lagring
    // ------------------------------------
    IPoolAddressesProvider public poolAddressesProvider;
    IPool public pool;

    // ------------------------------------
    // Bot-lagring
    // ------------------------------------
    address[] public dexes;
    mapping(address => address) public chainlinkOracles;

    uint256 public constant MAX_FEED_DELAY = 3600;
    uint256 public slippageBips;
    uint256 public minimumProfit;

    bool private executingArbitrage;
    TimelockController public timelock;

    // ------------------------------------
    // Event
    // ------------------------------------
    event ArbitrageExecuted(
        address indexed baseToken,
        address indexed tokenOut,
        uint256 loanAmount,
        uint256 outDex1,
        uint256 finalAmount,
        uint256 profit
    );
    event FlashLoanRequested(address indexed token, uint256 amount);
    event SwapExecuted(
        address indexed dex,
        address indexed fromToken,
        address indexed toToken,
        uint256 amountIn,
        uint256 amountOut
    );
    event DexAddressesUpdated(address[] dexes);
    event SlippageUpdated(uint256 slippageBips);
    event ChainlinkOracleSet(address indexed token, address indexed oracle);
    event MinimumProfitUpdated(uint256 minimumProfit);
    event TokenApproved(
        address indexed token,
        address indexed dex,
        uint256 amount
    );
    event TriangularArbitrageExecuted(
        address indexed tokenA,
        address indexed tokenB,
        address indexed tokenC,
        uint256 amountA,
        uint256 amountB,
        uint256 amountC,
        uint256 profit
    );
    event PricesValidated(
        address indexed fromToken,
        address indexed toToken,
        int256 fromPrice,
        int256 toPrice
    );

    // ------------------------------------
    // Mods
    // ------------------------------------
    modifier singleArbitrage() {
        if (executingArbitrage) revert ArbitrageAlreadyExecuting();
        executingArbitrage = true;
        _;
        executingArbitrage = false;
    }

    // ------------------------------------
    // AAVE: IFlashLoanReceiver
    // Vi måste implementera ADDRESSES_PROVIDER() och POOL()
    // ------------------------------------
    function ADDRESSES_PROVIDER()
        external
        view
        override
        returns (IPoolAddressesProvider)
    {
        return poolAddressesProvider;
    }

    function POOL() external view override returns (IPool) {
        return pool;
    }

    // ------------------------------------
    // init
    // ------------------------------------
    function initialize(
        IPoolAddressesProvider _provider,
        address[] memory _dexes,
        uint256 _slippageBips,
        uint256 _minimumProfit,
        address[] memory proposers,
        address[] memory executors,
        uint256 minDelay
    ) public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        if (_dexes.length < 2) revert DexesRequired();
        for (uint256 i = 0; i < _dexes.length; i++) {
            if (_dexes[i] == address(0)) revert DexAddressZero();
            dexes.push(_dexes[i]);
        }
        if (_slippageBips > 500) revert SlippageTooHigh();
        if (_minimumProfit == 0) revert MinimumProfitZero();

        poolAddressesProvider = _provider;
        pool = IPool(poolAddressesProvider.getPool());

        slippageBips = _slippageBips;
        minimumProfit = _minimumProfit;

        timelock = new TimelockController(
            minDelay,
            proposers,
            executors,
            address(0)
        );
        transferOwnership(address(timelock));
    }

    // ------------------------------------
    // UUPS
    // ------------------------------------
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {
        // valfri logik
        // super._authorizeUpgrade(newImplementation);
    }

    // ------------------------------------
    // Externa Helpers
    // ------------------------------------
    function autoRequestFlashLoan(
        address token,
        address tokenOut,
        uint256 fractionX100
    ) external onlyOwner {
        address poolAddr = poolAddressesProvider.getPool();
        uint256 totalBalanceInPool = IERC20Upgradeable(token).balanceOf(
            poolAddr
        );
        if (fractionX100 > 100) revert FractionTooHigh();

        uint256 loanAmount = (totalBalanceInPool * fractionX100) / 100;
        emit FlashLoanRequested(token, loanAmount);
        _requestFlashLoan(token, loanAmount, tokenOut);
    }

    function manualRequestFlashLoan(
        address token,
        uint256 amount,
        address tokenOut
    ) external onlyOwner {
        if (amount == 0) revert MinimumProfitZero();
        emit FlashLoanRequested(token, amount);
        _requestFlashLoan(token, amount, tokenOut);
    }

    // ------------------------------------
    // Intern: request
    // ------------------------------------
    function _requestFlashLoan(
        address _token,
        uint256 _amount,
        address _tokenOut
    ) internal {
        address[] memory assets = new address[](1);
        assets[0] = _token;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = _amount;

        uint256[] memory modes = new uint256[](1);
        modes[0] = 0; // “no debt” flash loan

        bytes memory params = abi.encode(_tokenOut);

        pool.flashLoan(
            address(this),
            assets,
            amounts,
            modes,
            address(this),
            params,
            0
        );
    }

    // ------------------------------------
    // AAVE callback: executeOperation
    // ------------------------------------
    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external override nonReentrant singleArbitrage returns (bool) {
        if (msg.sender != address(pool)) revert CallerNotAavePool();
        if (initiator != address(this)) revert InitiatorNotContract();

        address baseToken = assets[0];
        uint256 loanAmount = amounts[0];
        uint256 fee = premiums[0];

        address tokenOut = abi.decode(params, (address));
        if (dexes.length < 2) revert InsufficientDexes();

        _validatePrices(baseToken, tokenOut);

        // Hitta bästa DEX-kombo
        uint256 bestProfit;
        uint256 bestFinalAmount;
        address bestDex1;
        address bestDex2;

        for (uint256 i = 0; i < dexes.length; i++) {
            for (uint256 j = 0; j < dexes.length; j++) {
                if (i == j) continue;

                try
                    this._simulateArbitrage(
                        dexes[i],
                        dexes[j],
                        baseToken,
                        tokenOut,
                        loanAmount
                    )
                returns (uint256 profit, uint256 simulatedFinalAmount) {
                    if (profit > bestProfit) {
                        bestProfit = profit;
                        bestFinalAmount = simulatedFinalAmount;
                        bestDex1 = dexes[i];
                        bestDex2 = dexes[j];
                    }
                } catch {
                    // ignoring failed simulate
                    continue;
                }
            }
        }

        // Triangular
        if (dexes.length >= 3) {
            (uint256 triProfit, uint256 triFinalAmount) = this
                .triangularArbitrage(
                    dexes[0],
                    dexes[1],
                    dexes[2],
                    baseToken,
                    tokenOut,
                    baseToken,
                    loanAmount
                );
            if (triProfit > bestProfit) {
                bestProfit = triProfit;
                bestFinalAmount = triFinalAmount;
            }
        }

        if (bestProfit < minimumProfit) revert ProfitBelowMinThreshold();
        if (bestProfit == 0) revert NoProfitableArbFound();

        // -------------------------------------------------
        // Approve baseToken => bestDex1
        // -------------------------------------------------
        {
            IERC20Upgradeable(baseToken).safeApprove(bestDex1, 0); // Nollställ om behövs
            IERC20Upgradeable(baseToken).safeApprove(bestDex1, loanAmount);
        }

        // Swap
        uint256 outDex1 = _swapOnDex(bestDex1, baseToken, loanAmount, tokenOut);

        // -------------------------------------------------
        // Approve tokenOut => bestDex2
        // -------------------------------------------------
        {
            IERC20Upgradeable(tokenOut).safeApprove(bestDex2, 0); // Nollställ om behövs
            IERC20Upgradeable(tokenOut).safeApprove(bestDex2, outDex1);
        }

        // Swap
        uint256 finalAmount = _swapOnDex(
            bestDex2,
            tokenOut,
            outDex1,
            baseToken
        );

        uint256 totalDebt = loanAmount + fee;
        if (finalAmount <= totalDebt) revert NotProfitable();

        uint256 profitAmount = finalAmount - totalDebt;

        // -------------------------------------------------
        // repay flashloan
        // -------------------------------------------------
        {
            IERC20Upgradeable baseTokenERC = IERC20Upgradeable(baseToken);
            baseTokenERC.safeApprove(address(pool), 0);
            baseTokenERC.safeApprove(address(pool), totalDebt);
        }

        emit ArbitrageExecuted(
            baseToken,
            tokenOut,
            loanAmount,
            outDex1,
            finalAmount,
            profitAmount
        );
        return true;
    }

    // ------------------------------------
    // Dex-swap
    // ------------------------------------
    function _swapOnDex(
        address dex,
        address fromToken,
        uint256 amountIn,
        address toToken
    ) internal returns (uint256) {
        IUniswapV2Router02 router = IUniswapV2Router02(dex);

        address[] memory path = new address[](2);
        path[0] = fromToken;
        path[1] = toToken;

        uint256[] memory amountsOut;
        try router.getAmountsOut(amountIn, path) returns (
            uint256[] memory _amountsOut
        ) {
            amountsOut = _amountsOut;
        } catch {
            revert GetAmountsOutFailed();
        }

        uint256 minAmountOut = (amountsOut[1] * (10000 - slippageBips)) / 10000;
        if (minAmountOut == 0) revert SlippageTooHigh();

        uint256[] memory outAmounts;
        try
            router.swapExactTokensForTokens(
                amountIn,
                minAmountOut,
                path,
                address(this),
                block.timestamp
            )
        returns (uint256[] memory _outAmounts) {
            outAmounts = _outAmounts;
        } catch {
            revert SwapExactTokensFailed();
        }

        emit SwapExecuted(
            dex,
            fromToken,
            toToken,
            amountIn,
            outAmounts[outAmounts.length - 1]
        );
        return outAmounts[outAmounts.length - 1];
    }

    // ------------------------------------
    // Simulate Arb
    // ------------------------------------
    function _simulateArbitrage(
        address dex1,
        address dex2,
        address fromToken,
        address toToken,
        uint256 loanAmount
    ) external view returns (uint256 profit, uint256 finalAmount) {
        IUniswapV2Router02 router1 = IUniswapV2Router02(dex1);
        IUniswapV2Router02 router2 = IUniswapV2Router02(dex2);

        // Dex1
        address[] memory path = new address[](2);
        path[0] = fromToken;
        path[1] = toToken;
        uint256[] memory amountsOut1 = router1.getAmountsOut(loanAmount, path);
        uint256 outDex1 = amountsOut1[1];
        uint256 minAmountOut1 = (outDex1 * (10000 - slippageBips)) / 10000;
        if (minAmountOut1 == 0) {
            return (0, 0);
        }

        // Dex2
        path[0] = toToken;
        path[1] = fromToken;
        uint256[] memory amountsOut2 = router2.getAmountsOut(outDex1, path);
        uint256 finalOut = amountsOut2[1];
        uint256 minAmountOut2 = (finalOut * (10000 - slippageBips)) / 10000;
        if (minAmountOut2 == 0) {
            return (0, 0);
        }

        // approx flashloan fee ~0.09% => loanAmount * 9 / 10000
        uint256 totalDebt = loanAmount + ((loanAmount * 9) / 10000);

        if (minAmountOut2 > totalDebt) {
            return (minAmountOut2 - totalDebt, minAmountOut2);
        } else {
            return (0, 0);
        }
    }

    // ------------------------------------
    // Triangular Arb
    // ------------------------------------
    function triangularArbitrage(
        address dexA,
        address dexB,
        address dexC,
        address tokenA,
        address tokenB,
        address tokenC,
        uint256 amountA
    ) external nonReentrant returns (uint256 profit, uint256 finalAmount) {
        uint256 amountB = _swapOnDex(dexA, tokenA, amountA, tokenB);
        uint256 amountC = _swapOnDex(dexB, tokenB, amountB, tokenC);
        // Byt var-namn => amountAFinal
        uint256 amountAFinal = _swapOnDex(dexC, tokenC, amountC, tokenA);

        uint256 totalDebt = amountA + ((amountA * 9) / 10000);
        if (amountAFinal <= totalDebt) revert TriangularNotProfitable();

        profit = amountAFinal - totalDebt;
        finalAmount = amountAFinal;

        emit TriangularArbitrageExecuted(
            tokenA,
            tokenB,
            tokenC,
            amountA,
            amountB,
            amountC,
            profit
        );
    }

    // ------------------------------------
    // Validate chainlink
    // ------------------------------------
    function _validatePrices(address fromToken, address toToken) internal {
        AggregatorV3Interface fromPriceOracle = AggregatorV3Interface(
            chainlinkOracles[fromToken]
        );
        AggregatorV3Interface toPriceOracle = AggregatorV3Interface(
            chainlinkOracles[toToken]
        );

        if (address(fromPriceOracle) == address(0))
            revert MissingOracle(fromToken);
        if (address(toPriceOracle) == address(0)) revert MissingOracle(toToken);

        (, int256 fromPrice, , uint256 fromUpdatedAt, ) = fromPriceOracle
            .latestRoundData();
        (, int256 toPrice, , uint256 toUpdatedAt, ) = toPriceOracle
            .latestRoundData();

        if (fromPrice <= 0) revert InvalidPrice(fromToken);
        if (toPrice <= 0) revert InvalidPrice(toToken);

        if (block.timestamp - fromUpdatedAt > MAX_FEED_DELAY) {
            revert FeedOutdated(fromToken, true);
        }
        if (block.timestamp - toUpdatedAt > MAX_FEED_DELAY) {
            revert FeedOutdated(toToken, false);
        }

        emit PricesValidated(fromToken, toToken, fromPrice, toPrice);
    }

    // ------------------------------------
    // Admin updates
    // ------------------------------------
    function getOracle(address token) external view returns (address) {
        return chainlinkOracles[token];
    }

    function setDexAddresses(address[] memory _dexes) external onlyOwner {
        if (_dexes.length < 2) revert DexesRequired();
        delete dexes;
        for (uint256 i = 0; i < _dexes.length; i++) {
            if (_dexes[i] == address(0)) revert DexAddressZero();
            dexes.push(_dexes[i]);
        }
        emit DexAddressesUpdated(_dexes);
    }

    function setSlippageBips(uint256 _slippageBips) external onlyOwner {
        if (_slippageBips > 500) revert SlippageTooHigh();
        slippageBips = _slippageBips;
        emit SlippageUpdated(_slippageBips);
    }

    function setChainlinkOracle(
        address token,
        address oracle
    ) external onlyOwner {
        if (token == address(0) || oracle == address(0))
            revert MissingOracle(token);
        chainlinkOracles[token] = oracle;
        emit ChainlinkOracleSet(token, oracle);
    }

    function setMinimumProfit(uint256 _minimumProfit) external onlyOwner {
        if (_minimumProfit == 0) revert MinimumProfitZero();
        minimumProfit = _minimumProfit;
        emit MinimumProfitUpdated(_minimumProfit);
    }

    function _approveMax(address dex, address token) internal {
        IERC20Upgradeable(token).safeApprove(dex, type(uint256).max);
        emit TokenApproved(token, dex, type(uint256).max);
    }

    function revokeApproval(address dex, address token) external onlyOwner {
        IERC20Upgradeable(token).safeApprove(dex, 0);
        emit TokenApproved(token, dex, 0);
    }
}