// SPDX-License-Identifier: MIT

// https://www.tokenestate.store

/*
TESTA 🤖🧠 is a new kind of venture firm where customers can own a piece of a luxury apartment in New York or a beachside villa in the Maldives with just a few clicks. Our platform enables you to invest in real estate by buying fractional tokens, backed by blockchain technology for security and transparency. It's real estate reimagined for the digital age.

Socials:
🌐 Website: https://www.tokenestate.store
*/

pragma solidity ^0.8.20;

import "./openzeppelin_contracts_access_Ownable.sol";
import "./openzeppelin_contracts_token_ERC20_ERC20.sol";

interface IDexRouter {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);
}

interface IDexFactory {
    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address pair);
}

contract TESTA is Ownable, ERC20 {
    uint256 private constant TOTAL_SUPPLY = 200 * (1e6) * (1e18); // 200M
    uint256 public constant DENOMINATOR = 10000; // 100%
    uint256 public constant MAX_BUY_FEE_NUMERATOR = 500; // 5%
    uint256 public constant MAX_SELL_FEE_NUMERATOR = 500; // 5%

    uint256 public maxSellNumerator = 8000; // 80%
    uint256 public maxBuyNumerator = 8000; // 80%

    uint256 public constant MAX_HOLD_AMOUNT = 7 * (1e6) * (1e18); // 5M
    uint256 public constant MAX_SELL_AMOUNT = 3 * (1e6) * (1e18); // 2M
    uint256 public maxBuyAmount = 4 * (1e6) * (1e18); // 3M

    IDexRouter public immutable uniswapV2Router;

    struct AccountInfo {
        bool isLPPool;
        bool isLiquidityHolder;
        bool isBlackListed;
    }
    mapping(address => AccountInfo) public accountInfo;
    mapping(address => mapping(address => uint256)) private _allowances;

    // mainnet
    IDexFactory UNISWAP_FACTORY =
        IDexFactory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f); // UNISWAP_FACTORY
    address UNISWAP_V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D; // uniswapRouter
    address WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // wrapped ETH

    address public immutable uniswapV2Pair; // liquidity pool address

    address payable public taxAddress;
    bool public blacklistAddRestrictedForever;

    bool public tradingActive = false;
    bool private inSwap = false;
    bool private swapEnabled = false;

    /// @notice Emitted when a liquidity pool pair is updated.
    event LPPairSet(address indexed pair, bool enabled);

    /// @notice Emitted when an account is marked or unmarked as a liquidity holder (treasury, staking, etc).
    event LiquidityHolderSet(address indexed account, bool flag);

    event BlacklistSet(address indexed account, bool flag);

    /// @notice Emitted (once) when blacklist add is restricted forever.
    event BlacklistAddRestrictedForever();

    event TaxAddressSet(address _taxAddress);
    event BuyFeePaid(address indexed from, address indexed to, uint256 amount);
    event SellFeePaid(address indexed from, address indexed to, uint256 amount);
    event SwapBackResult(uint256 amountIn, uint256 amountOut);
    event EnabledTrading(bool tradingActive);

    modifier lockTheSwap() {
        inSwap = true;
        _;
        inSwap = false;
    }

    constructor(
        address _taxAddress
    ) ERC20("ToEstate", "$TESTA") Ownable(msg.sender) {
        uniswapV2Pair = UNISWAP_FACTORY.createPair(address(this), WETH);
        IDexRouter _uniswapV2Router = IDexRouter(UNISWAP_V2_ROUTER);
        uniswapV2Router = _uniswapV2Router;

        setLiquidityHolder(msg.sender, true);
        setLiquidityHolder(address(this), true);
        setLiquidityHolder(_taxAddress, true);
        setLiquidityHolder(UNISWAP_V2_ROUTER, true);
        setLiquidityHolder(uniswapV2Pair, true);
        setLiquidityHolder(
            address(0xdEAD000000000000000042069420694206942069),
            true
        );
        setLpPair(uniswapV2Pair, true);
        require(_taxAddress != address(0), "Tax address cannot be zero");
        taxAddress = payable(_taxAddress);
        setLiquidityHolder(_taxAddress, true);
        emit TaxAddressSet(_taxAddress);

        _mint(msg.sender, TOTAL_SUPPLY);
    }

    receive() external payable {}

    function restrictBlacklistAddForever() external onlyOwner {
        require(!blacklistAddRestrictedForever, "already set");
        blacklistAddRestrictedForever = true;
        emit BlacklistAddRestrictedForever();
    }

    function setTaxAddress(address newTaxAddress) external {
        require(
            msg.sender == taxAddress,
            "Only taxAddress can update Tax address"
        );
        require(newTaxAddress != address(0), "Tax address cannot be zero");
        taxAddress = payable(newTaxAddress);
        setLiquidityHolder(newTaxAddress, true);
        emit TaxAddressSet(newTaxAddress);
    }

    function swapTokensForEth(uint256 tokenAmount) private lockTheSwap {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();
        _approve(address(this), address(uniswapV2Router), tokenAmount);
        uint ethBalanceBeforeSwap = address(this).balance;
        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );

        emit SwapBackResult(
            tokenAmount,
            address(this).balance - ethBalanceBeforeSwap
        );
    }

    function sendETHToFee(uint256 amount) private {
        taxAddress.transfer(amount);
    }

    // Setters with onlyOwner

    function toggleMaxSellNumerator() public onlyOwner {
        maxSellNumerator = MAX_SELL_FEE_NUMERATOR;
    }
    function toggleMaxBuyNumerator() public onlyOwner {
        maxBuyNumerator = MAX_BUY_FEE_NUMERATOR;
    }

    function setLpPair(address pair, bool enabled) public onlyOwner {
        accountInfo[pair].isLPPool = enabled;
        emit LPPairSet(pair, enabled);
    }

    function setLiquidityHolder(address account, bool flag) public onlyOwner {
        accountInfo[account].isLiquidityHolder = flag;
        emit LiquidityHolderSet(account, flag);
    }

    // enable trading
    function enableTrading() external onlyOwner {
        tradingActive = true;
        swapEnabled = true;
        emit EnabledTrading(true);
    }

    function setBlacklisted(
        address account,
        bool isBlacklisted
    ) external onlyOwner {
        if (isBlacklisted) {
            require(
                !blacklistAddRestrictedForever,
                "Blacklist add restricted forever"
            );
        }
        accountInfo[account].isBlackListed = isBlacklisted;
        emit BlacklistSet(account, isBlacklisted);
    }

    function setMaxBuyAmount(uint256 amount) external onlyOwner {
        maxBuyAmount = amount;
    }

    function _hasLimits(
        AccountInfo memory fromInfo,
        AccountInfo memory toInfo
    ) internal pure returns (bool) {
        return (!fromInfo.isLiquidityHolder || !toInfo.isLiquidityHolder);
    }

    function _update(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        AccountInfo memory fromInfo = accountInfo[from];
        AccountInfo memory toInfo = accountInfo[to];
        // check blacklist
        require(
            !fromInfo.isBlackListed && !toInfo.isBlackListed,
            "Blacklisted"
        );
        super._update(from, to, amount);
        if (
            !_hasLimits(fromInfo, toInfo) ||
            (fromInfo.isLPPool && toInfo.isLPPool)
        ) {
            return;
        }

        uint256 taxFee = 0;

        if (fromInfo.isLPPool) {
            require(tradingActive, "Trading is not enabled!");
            taxFee = (amount * maxBuyNumerator) / DENOMINATOR;
            require(
                amount - taxFee <= maxBuyAmount,
                "Transfer amount exceeds the max buy amount"
            );
            emit BuyFeePaid(from, taxAddress, taxFee);
        } else if (toInfo.isLPPool) {
            require(tradingActive, "Trading is not enabled!");
            taxFee = (amount * maxSellNumerator) / DENOMINATOR;
            require(
                amount - taxFee <= MAX_SELL_AMOUNT,
                "Transfer amount exceeds the max sell amount"
            );
            emit SellFeePaid(from, taxAddress, taxFee);
        }
        if (taxFee > 0) {
            super._update(to, address(this), taxFee);
        }

        // check max holding amount
        if (!toInfo.isLiquidityHolder) {
            require(
                balanceOf(to) <= MAX_HOLD_AMOUNT,
                "Transfer amount exceeds the max holding amount"
            );
        }
    }

    // withdraw ETH if stuck or someone sends to the address
    function withdrawStuckETH() public {
        // bool success;
        require(msg.sender == taxAddress, "only taxAddress can withdraw");
        taxAddress.transfer(address(this).balance);
    }

    function executeManualSwap() external {
        require(
            msg.sender == taxAddress,
            "Only taxAddress can execute manual swap"
        );
        uint256 tokenBalance = balanceOf(address(this));
        if (tokenBalance > 0 && swapEnabled) {
            swapTokensForEth(tokenBalance);
        }
        uint256 ethBalance = address(this).balance;
        if (ethBalance > 0) {
            sendETHToFee(ethBalance);
        }
    }
}