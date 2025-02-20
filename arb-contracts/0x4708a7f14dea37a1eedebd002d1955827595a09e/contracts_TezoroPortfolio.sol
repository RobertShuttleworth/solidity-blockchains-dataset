// SPDX-License-Identifier: UNLICENCED

pragma solidity =0.7.6;
pragma abicoder v2;

import "./uniswap_v3-periphery_contracts_interfaces_ISwapRouter.sol";
import "./uniswap_v3-periphery_contracts_libraries_TransferHelper.sol";
import "./openzeppelin_contracts_token_ERC20_IERC20.sol";

import "./contracts_TezoroQuote.sol";

contract TezoroPortfolio {
    uint8 public constant VERSION = 6;
    uint256 public constant TOTAL_SHARES = 1000000;
    uint256 public constant MAX_TOLERANCE = 10000;
    uint256 public constant MONTH = 2592000;

    ISwapRouter public immutable swapRouter;
    ITezoroQuote public immutable tezoroQuote;
    address public immutable owner;
    address public immutable operator;
    uint256 public immutable feeRate;

    uint256 public slippageTolerance;
    uint24 public poolFee;
    uint256 public sharesThreshold;
    address public commonQuoteToken;
    address[] public tokens;
    uint256[] public shares;

    uint256 public lastFeePaymentTimestamp;
    uint256 public lastBalanceObservation;
    mapping (address => uint256) public lastPortfolioObservation;

    modifier onlyThisContract() {
        if (msg.sender != address(this)) revert("External call");
        _;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert("Not owner");
        _;
    }

    modifier onlyOwnerOrOperator() {
        if (msg.sender != operator && msg.sender != owner)
            revert("Not owner or operator");
        _;
    }

    modifier onlyOwnerOperatorOrThisContract() {
        if (msg.sender != operator && msg.sender != owner && msg.sender != address(this))
            revert("Not owner, operator or this contract");
        _;
    }

    event PortfolioSet(address[] _tokens, uint256[] _shares);
    event PoolFeeSet(uint24 _poolFee);
    event SlippageToleranceSet(uint256 _slippageTolerance);
    event SharesThresholdSet(uint256 _sharesThreshold);
    event QuoteTokenSet(address _commonQuoteToken);
    event Swapped(
        address base,
        address commonQuoteToken,
        uint256 amountIn,
        uint256 amountOut
    );
    event SwapFailed(address baseToken, address quoteToken, uint256 amount, bool isSell);
    event BalanceObservation(uint256 balance);
    event FeePaid(address token, uint256 amount);

    constructor(
        ISwapRouter _swapRouter,
        ITezoroQuote _tezoroQuote,
        address[] memory _tokens,
        uint256[] memory _shares,
        address _commonQuoteToken,
        uint256 _slippageTolerance,
        uint256 _sharesThreshold,
        uint24 _poolFee,
        address _owner,
        address _operator,
        uint256 _feeRate
    ) {
        swapRouter = _swapRouter;
        tezoroQuote = _tezoroQuote;
        owner = _owner;
        operator = _operator;

        require(
            _tokens.length == _shares.length,
            "Tokens list does not match shares"
        );
        uint256 ind = 0;
        uint256 total_shares = 0;
        while (ind < _tokens.length) {
            require(_tokens[ind] != address(0), "Zero token address");
            total_shares += _shares[ind];
            ind += 1;
        }
        require(total_shares == TOTAL_SHARES, "Incorrect total shares sum");
        tokens = _tokens;
        shares = _shares;
        emit PortfolioSet(tokens, shares);

        require(_sharesThreshold > 0, "Zero shares threshold");
        require(
            _sharesThreshold <= TOTAL_SHARES,
            "Shares threshold is too big"
        );
        sharesThreshold = _sharesThreshold;
        emit SharesThresholdSet(sharesThreshold);

        require(_slippageTolerance > 0, "Zero slippage tolerance");
        require(
            _slippageTolerance <= MAX_TOLERANCE,
            "Slippage tolerance is too big"
        );
        slippageTolerance = _slippageTolerance;
        emit SlippageToleranceSet(slippageTolerance);

        require(_poolFee > 0, "Zero pool fee");
        poolFee = _poolFee;
        emit PoolFeeSet(poolFee);

        require(_commonQuoteToken != address(0), "Zero common quote token address");
        commonQuoteToken = _commonQuoteToken;
        emit QuoteTokenSet(_commonQuoteToken);

        require (_feeRate != 0, "Zero fee");
        feeRate = _feeRate;

        lastFeePaymentTimestamp = block.timestamp;
        // Quote memory quote = tezoroQuote.getQuote(tokens.length, address(this));
        // lastBalanceObservation = quote.totalBalance;
        // emit BalanceObservation(lastBalanceObservation);
        resetPortfolioObservation();
        // ind = 0;
        // while (ind < quote.legs.length) {
        //     lastPortfolioObservation[quote.legs[ind].token] = quote.legs[ind].amount;
        // }
    }

    function setQuoteToken(address _commonQuoteToken) external onlyOwner {
        require(_commonQuoteToken != address(0), "Zero quote token address");
        feePayment();
        commonQuoteToken = _commonQuoteToken;
        emit QuoteTokenSet(_commonQuoteToken);
    }

    function setPoolFee(uint24 _poolFee) external onlyOwner {
        require(_poolFee > 0, "Zero pool fee");
        poolFee = _poolFee;
        emit PoolFeeSet(_poolFee);
    }

    function setSlippageTolerance(
        uint256 _slippageTolerance
    ) external onlyOwner {
        require(_slippageTolerance > 0, "Zero slippage tolerance");
        require(
            _slippageTolerance <= MAX_TOLERANCE,
            "Slippage tolerance is too big"
        );
        slippageTolerance = _slippageTolerance;
        emit SlippageToleranceSet(slippageTolerance);
    }

    function setSharesThreshold(uint256 _sharesThreshold) external onlyOwner {
        require(_sharesThreshold > 0, "Zero shares threshold");
        require(
            _sharesThreshold <= TOTAL_SHARES,
            "Shares threshold is too big"
        );
        feePayment();
        sharesThreshold = _sharesThreshold;
        emit SharesThresholdSet(sharesThreshold);
    }

    function setPortfolio(
        address[] memory _tokens,
        uint256[] memory _shares
    ) external onlyOwner {
        require(_tokens.length > 0, "Empty tokens list");
        require(
            _tokens.length == _shares.length,
            "Tokens list does not match shares"
        );
        feePayment();
        uint256 ind = 0;
        uint256 total_shares = 0;
        while (ind < _tokens.length) {
            require(_tokens[ind] != address(0), "Zero token address");
            total_shares += _shares[ind];
            ind += 1;
        }
        require(total_shares == TOTAL_SHARES, "Incorrect total shares sum");
        tokens = _tokens;
        shares = _shares;
        emit PortfolioSet(tokens, shares);
    }

    function tokensLength() external view returns (uint256) {
        return tokens.length;
    }

    function resetPortfolioObservation() private {
        uint256 ind = 0;
        while (ind < tokens.length) {
            lastPortfolioObservation[tokens[ind]] = 0;
            ind += 1;
        }
    }

    function getBalanceChange() public view returns (uint256) {
        Quote memory quote = tezoroQuote.getQuote(tokens.length, address(this));
        uint256 balanceChange = quote.virtualBalance > lastBalanceObservation ? quote.virtualBalance - lastBalanceObservation : 0;
        return balanceChange;
    }

    function getFeeBase() public view returns (uint256) {
        Quote memory quote = tezoroQuote.getQuote(tokens.length, address(this));
        uint256 feeBase = 0;
        if (quote.totalBalance > 0) {
            uint256 balanceChange = quote.virtualBalance > lastBalanceObservation ? quote.virtualBalance - lastBalanceObservation : 0;
            feeBase = feeRate * (block.timestamp - lastFeePaymentTimestamp) * balanceChange / (MONTH * quote.totalBalance);
        } 
        return feeBase;
    }

    function feePayment() public onlyOwnerOperatorOrThisContract {
        Quote memory quote = tezoroQuote.getQuote(tokens.length, address(this));
        uint256 ind = 0;
        if (quote.totalBalance > 0) {
            uint256 balanceChange = quote.virtualBalance > lastBalanceObservation ? quote.virtualBalance - lastBalanceObservation : 0;
            uint256 feeBase = feeRate * (block.timestamp - lastFeePaymentTimestamp) * balanceChange / (MONTH * quote.totalBalance);
            if (feeBase > 0) {
                while (ind < quote.legs.length) {
                    uint256 amount = quote.legs[ind].amount * feeBase / TOTAL_SHARES;
                    TransferHelper.safeTransferFrom(
                        quote.legs[ind].token,
                        owner,
                        operator,
                        amount
                    );
                    emit FeePaid(quote.legs[ind].token, amount);
                    ind += 1;
                }
                lastFeePaymentTimestamp = block.timestamp;
            }
        }
        lastBalanceObservation = quote.totalBalance;
        emit BalanceObservation(lastBalanceObservation);
        resetPortfolioObservation();
        ind = 0;
        while (ind < quote.legs.length) {
            lastPortfolioObservation[quote.legs[ind].token] = quote.legs[ind].amount;
            ind += 1;
        }
    }

    function balance() external onlyOwnerOrOperator {
        uint256 quoteInd = 0;
        while (quoteInd < tokens.length) {
            balanceQuote(quoteInd);
            quoteInd += 1;
        }
    }

    function getSingleQuote(uint256 baseInd, uint256 quoteInd) external view returns (Leg memory) {
        Quote memory quote = tezoroQuote.getQuote(quoteInd, address(this));
        return quote.legs[baseInd];
    }

    function balanceQuote(uint256 quoteInd) private {
        uint256 amountOut = 0;
        uint256 baseInd = 0;
        Quote memory quote = tezoroQuote.getQuote(quoteInd, address(this));

        while (baseInd < tokens.length) {
            if (baseInd != quoteInd) {
                int256 disbalanceAmount = quote
                    .legs[baseInd]
                    .disbalanceAmount;
                int256 disbalance = quote
                    .legs[baseInd]
                    .disbalance;
                if (disbalanceAmount < 0) {
                    try
                        this.swapExactInputSingle(
                            tokens[baseInd],
                            tokens[quoteInd],
                            uint256(-disbalanceAmount),
                            (uint256(-disbalance) *
                                (MAX_TOLERANCE - slippageTolerance)) /
                                MAX_TOLERANCE
                        )
                    returns (uint256 _amountOut) {
                        amountOut = _amountOut;
                        emit Swapped(
                            tokens[baseInd],
                            tokens[quoteInd],
                            uint256(-disbalanceAmount),
                            _amountOut
                        );
                    } catch {
                        amountOut = 0;
                        emit SwapFailed(
                            tokens[baseInd],
                            tokens[quoteInd],
                            uint256(-disbalanceAmount),
                            true
                        );
                    }
                }
            }
            baseInd += 1;
        }
        baseInd = 0;
        while (baseInd < tokens.length) {
            if (baseInd != quoteInd) {
                int256 disbalanceAmount = quote
                    .legs[baseInd]
                    .disbalanceAmount;
                int256 disbalance = quote
                    .legs[baseInd]
                    .disbalance;
                if (disbalanceAmount > 0) {
                    try
                        this.swapExactInputSingle(
                            tokens[quoteInd],
                            tokens[baseInd],
                            uint256(disbalance),
                            (uint256(disbalanceAmount) *
                                (MAX_TOLERANCE - slippageTolerance)) /
                                MAX_TOLERANCE
                        )
                    returns (uint256 _amountOut) {
                        amountOut = _amountOut;
                        emit Swapped(
                            tokens[quoteInd],
                            tokens[baseInd],
                            uint256(disbalance),
                            _amountOut
                        );
                    } catch {
                        amountOut = 0;
                        emit SwapFailed(
                            tokens[quoteInd],
                            tokens[baseInd],
                            uint256(disbalance),
                            false
                        );
                    }
                }
            }
            baseInd += 1;
        }
    }

    /// @notice swapExactInputSingle swaps a fixed amount of tokenIn for a maximum possible amount of tokenOut
    /// @param amountIn The exact amount of tokenIn that will be swapped for tokenOut.
    /// @return amountOut The amount of tokenOut received.
    function swapExactInputSingle(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut
    ) external onlyThisContract returns (uint256 amountOut) {
        TransferHelper.safeTransferFrom(
            tokenIn,
            owner,
            address(this),
            amountIn
        );
        TransferHelper.safeApprove(tokenIn, address(swapRouter), amountIn);
        uint160 priceLimit = 0;
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: poolFee,
                recipient: owner,
                deadline: block.timestamp + 90,
                amountIn: amountIn,
                amountOutMinimum: minAmountOut,
                sqrtPriceLimitX96: priceLimit
            });
        amountOut = swapRouter.exactInputSingle(params);
    }
}