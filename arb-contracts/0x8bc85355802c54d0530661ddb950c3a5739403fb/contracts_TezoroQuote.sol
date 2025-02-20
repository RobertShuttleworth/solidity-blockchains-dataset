// SPDX-License-Identifier: UNLICENCED

pragma solidity =0.7.6;
pragma abicoder v2;

import "./uniswap_v3-core_contracts_interfaces_IUniswapV3Factory.sol";
import "./uniswap_v3-core_contracts_interfaces_IUniswapV3Pool.sol";
import "./uniswap_v3-core_contracts_libraries_SqrtPriceMath.sol";
import "./uniswap_v3-core_contracts_libraries_FullMath.sol";
import "./uniswap_v3-core_contracts_libraries_TickMath.sol";
import "./openzeppelin_contracts_token_ERC20_IERC20.sol";

interface IERC20Extented is IERC20 {
    function decimals() external view returns (uint8);
}

interface ITezoroPortfolio {
    function owner() external view returns (address);

    function tokensLength() external view returns (uint256);

    function tokens(uint256 index) external view returns (address);

    function shares(uint256 index) external view returns (uint256);

    function poolFee() external view returns (uint24);

    function commonQuoteToken() external view returns (address);

    function sharesThreshold() external view returns (uint256);

    function lastPortfolioObservation(address) external view returns (uint256);
}

interface ITezoroQuote {
    function getQuote(
        uint256 quoteInd,
        address portfolio
    ) external view returns (Quote memory);
}

struct Leg {
    address token;
    uint256 balance;
    uint256 amount;
    uint256 price;
    int256 disbalance;
    int256 disbalanceAmount;
}

struct Quote {
    uint256 quoteInd;
    address quoteAddress;
    uint256 totalBalance;
    uint256 virtualBalance;
    Leg[] legs;
}

contract TezoroQuote {
    uint8 public constant VERSION = 2;
    uint256 public constant TOTAL_SHARES = 1000000;

    IUniswapV3Factory public immutable swapFactory;
    uint32 public twapInterval;

    event TwapIntervalSet(uint32 twapInterval);

    constructor(IUniswapV3Factory _swapFactory, uint32 _twapInterval) {
        swapFactory = _swapFactory;
        require(_twapInterval > 0, "TWAP interval must be greater than 0");
        twapInterval = _twapInterval;
        emit TwapIntervalSet(twapInterval);
    }

    function getPoolAddress(
        address baseToken,
        address quoteToken,
        uint24 poolFee
    ) internal view returns (address) {
        return swapFactory.getPool(baseToken, quoteToken, poolFee);
    }

    function getTwapPrice(IUniswapV3Pool pool) internal view returns (uint160) {
        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = twapInterval;
        secondsAgos[1] = uint32(0);
        (int56[] memory tickCumulatives, ) = pool.observe(secondsAgos);

        int56 tickDifference = tickCumulatives[1] - tickCumulatives[0];
        int24 averageTick = int24(tickDifference / int56(int256(twapInterval)));
        return TickMath.getSqrtRatioAtTick(averageTick);
    }

    function getPoolTokenPrice(
        address baseToken,
        address commonQuoteToken,
        uint24 poolFee
    ) internal view returns (uint256) {
        if (baseToken == commonQuoteToken) {
            return 10 ** IERC20Extented(commonQuoteToken).decimals();
        }

        address poolAddress = swapFactory.getPool(
            baseToken,
            commonQuoteToken,
            poolFee
        );
        require(poolAddress != address(0), "Pool does not exist");
        IUniswapV3Pool pool = IUniswapV3Pool(poolAddress);

        address token0 = pool.token0();
        address token1 = pool.token1();
        uint8 decimals0 = IERC20Extented(token0).decimals();
        uint8 decimals1 = IERC20Extented(token1).decimals();

        uint160 sqrtPriceX96 = getTwapPrice(pool);
        uint256 price = (uint256(sqrtPriceX96) *
            uint256(sqrtPriceX96) *
            (10 ** uint256(decimals0))) >> 192;

        if (baseToken == token0 && commonQuoteToken == token1) {
            return price;
        } else if (baseToken == token1 && commonQuoteToken == token0) {
            return 10 ** (decimals0 + decimals1) / price;
        } else {
            revert("Unsupported token combination");
        }
    }

    function getTokenPrice(
        address baseToken,
        address quoteToken,
        address commonQuoteToken,
        uint24 poolFee
    ) internal view returns (uint256) {
        uint256 basePrice = getPoolTokenPrice(
            baseToken,
            commonQuoteToken,
            poolFee
        );
        uint256 quotePrice = getPoolTokenPrice(
            quoteToken,
            commonQuoteToken,
            poolFee
        );
        uint256 quoteDecimals = IERC20Extented(quoteToken).decimals();
        return (basePrice * 10 ** quoteDecimals) / quotePrice;
    }

    function getTokenAmount(
        address token,
        address owner,
        address portfolio
    ) internal view returns (uint256) {
        uint256 allowance = IERC20(token).allowance(owner, portfolio);
        uint256 tokenBalance = IERC20(token).balanceOf(owner);
        return tokenBalance > allowance ? allowance : tokenBalance;
    }

    function getTokenBalance(
        address baseToken,
        address quoteToken,
        address commonQuoteToken,
        address owner,
        address portfolio,
        uint24 poolFee
    ) internal view returns (uint256) {
        uint256 amount = getTokenAmount(baseToken, owner, portfolio);
        uint256 price = getTokenPrice(
            baseToken,
            quoteToken,
            commonQuoteToken,
            poolFee
        );
        uint256 baseDecimals = IERC20Extented(baseToken).decimals();
        return (amount * price) / 10 ** baseDecimals;
    }

    function getQuote(
        uint256 quoteInd,
        ITezoroPortfolio portfolio
    ) external view returns (Quote memory) {
        uint256 length = portfolio.tokensLength();
        address quoteToken = quoteInd < length
            ? portfolio.tokens(quoteInd)
            : portfolio.commonQuoteToken();
        address owner = portfolio.owner();
        uint24 poolFee = portfolio.poolFee();
        uint256 sharesThreshold = portfolio.sharesThreshold();
        address commonQuoteToken = portfolio.commonQuoteToken();

        Leg[] memory legs = new Leg[](length);
        uint256 totalBalance = 0;
        uint256 virtualBalance = 0;
        uint256 tokenInd = 0;
        while (tokenInd < length) {
            legs[tokenInd].token = portfolio.tokens(tokenInd);
            legs[tokenInd].price = getTokenPrice(
                legs[tokenInd].token,
                quoteToken,
                commonQuoteToken,
                poolFee
            );
            legs[tokenInd].amount = getTokenAmount(
                legs[tokenInd].token,
                owner,
                address(portfolio)
            );
            uint256 decimals = IERC20Extented(legs[tokenInd].token).decimals();
            legs[tokenInd].balance =
                (legs[tokenInd].amount * legs[tokenInd].price) /
                10 ** decimals;
            totalBalance += legs[tokenInd].balance;
            virtualBalance +=
                (portfolio.lastPortfolioObservation(legs[tokenInd].token) *
                    legs[tokenInd].price) /
                10 ** decimals;
            tokenInd += 1;
        }

        if (totalBalance > 0) {
            tokenInd = 0;
        }
        while (tokenInd < length) {
            uint256 shares = portfolio.shares(tokenInd);
            uint256 actualShares = (legs[tokenInd].balance * TOTAL_SHARES) /
                totalBalance;
            uint256 sharesDiff = actualShares > shares
                ? actualShares - shares
                : shares - actualShares;
            if (sharesDiff > sharesThreshold) {
                uint256 tokenPortfolioBalance = (totalBalance * shares) /
                    TOTAL_SHARES;
                legs[tokenInd].disbalance = int256(
                    tokenPortfolioBalance - legs[tokenInd].balance
                );
            } else {
                legs[tokenInd].disbalance = 0;
            }

            uint256 decimals = IERC20Extented(legs[tokenInd].token).decimals();
            if (legs[tokenInd].disbalance >= 0) {
                legs[tokenInd].disbalanceAmount = int256(
                    (uint256(legs[tokenInd].disbalance) * (10 ** decimals)) /
                        legs[tokenInd].price
                );
            } else {
                legs[tokenInd].disbalanceAmount = int256(
                    -((uint256(-legs[tokenInd].disbalance) * (10 ** decimals)) /
                        legs[tokenInd].price)
                );
            }
            tokenInd += 1;
        }

        Quote memory _quote;
        _quote.quoteInd = quoteInd;
        _quote.quoteAddress = quoteToken;
        _quote.totalBalance = totalBalance;
        _quote.virtualBalance = virtualBalance;
        _quote.legs = legs;
        return _quote;
    }
}