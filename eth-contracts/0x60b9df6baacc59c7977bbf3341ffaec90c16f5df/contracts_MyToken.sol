// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./openzeppelin_contracts_token_ERC20_ERC20.sol";
import "./chainlink_contracts_src_v0.8_shared_interfaces_AggregatorV3Interface.sol";

contract MyToken is ERC20 {
    address public owner;
    uint256 public tokenPriceInUSD; // Цена токена в USD
    AggregatorV3Interface public ethPriceFeed;

    mapping(address => AggregatorV3Interface) public tokenPriceFeeds; // Фиды цен для токенов
    mapping(address => bool) public stableTokens; // Статус стабильных токенов

    struct Investment {
        address paymentToken; // Токен, которым инвестировали
        uint256 usdValue;     // Сумма в USD
        uint256 tokensOwed;   // Количество токенов, которые должны быть выданы
    }

    mapping(address => Investment[]) public investments; // Маппинг инвесторов на их вложения

    event InvestmentMade(address indexed investor, uint256 usdValue, uint256 tokensOwed, address indexed paymentToken);

    constructor(
        uint256 initialSupply,
        uint256 _tokenPriceInUSD,
        address _ethPriceFeed,
        address[] memory tokens,
        address[] memory priceFeeds,
        address[] memory stableTokensList
    ) ERC20("MyToken", "MTK") {
        _mint(msg.sender, initialSupply * 10 ** decimals());

        owner = msg.sender;
        tokenPriceInUSD = _tokenPriceInUSD;
        ethPriceFeed = AggregatorV3Interface(_ethPriceFeed);

        for (uint256 i = 0; i < tokens.length; i++) {
            tokenPriceFeeds[tokens[i]] = AggregatorV3Interface(priceFeeds[i]);
        }

        for (uint256 i = 0; i < stableTokensList.length; i++) {
            stableTokens[stableTokensList[i]] = true;
        }
    }

    function invest(address paymentToken) external payable {
        uint256 usdValue;

        if (paymentToken == address(0)) {
            // Инвестиция в ETH
            require(msg.value > 0, "No ETH sent");
            usdValue = getUSDValueETH(msg.value);
        } else if (stableTokens[paymentToken]) {
            // Инвестиция в стабильный токен
            uint256 paymentAmount = IERC20(paymentToken).balanceOf(msg.sender);
            require(paymentAmount > 0, "No stable token sent");
            require(IERC20(paymentToken).allowance(msg.sender, address(this)) >= paymentAmount, "Allowance too low");

            usdValue = paymentAmount;
            IERC20(paymentToken).transferFrom(msg.sender, address(this), paymentAmount);
        } else {
            // Инвестиция в другой токен
            uint256 paymentAmount = IERC20(paymentToken).balanceOf(msg.sender);
            require(paymentAmount > 0, "No token sent");

            AggregatorV3Interface priceFeed = tokenPriceFeeds[paymentToken];
            require(address(priceFeed) != address(0), "Token not supported");
            require(IERC20(paymentToken).allowance(msg.sender, address(this)) >= paymentAmount, "Allowance too low");

            usdValue = getUSDValueToken(paymentAmount, priceFeed);
            IERC20(paymentToken).transferFrom(msg.sender, address(this), paymentAmount);
        }

        // Рассчитываем количество токенов, которые должны быть выданы
        uint256 tokensOwed = (usdValue * 10**decimals()) / tokenPriceInUSD;

        // Сохраняем информацию об инвестиции
        investments[msg.sender].push(Investment({paymentToken: paymentToken, usdValue: usdValue, tokensOwed: tokensOwed}));

        emit InvestmentMade(msg.sender, usdValue, tokensOwed, paymentToken);
    }

    function getUSDValueETH(uint256 ethAmount) public view returns (uint256) {
        (, int256 price, , , ) = ethPriceFeed.latestRoundData();
        require(price > 0, "Invalid ETH price");
        uint256 ethPriceInUSD = uint256(price) * 10**10;
        return (ethAmount * ethPriceInUSD) / 10**18;
    }

    function getUSDValueToken(uint256 tokenAmount, AggregatorV3Interface priceFeed) public view returns (uint256) {
        (, int256 price, , , ) = priceFeed.latestRoundData();
        require(price > 0, "Invalid token price");
        uint256 tokenPrice = uint256(price) * 10**10;
        return (tokenAmount * tokenPrice) / 10**18;
    }

    function withdraw(address paymentToken, uint256 amount) external {
        require(msg.sender == owner, "Only owner can withdraw");

        if (paymentToken == address(0)) {
            require(address(this).balance >= amount, "Insufficient ETH balance");
            payable(owner).transfer(amount);
        } else {
            require(IERC20(paymentToken).balanceOf(address(this)) >= amount, "Insufficient token balance");
            IERC20(paymentToken).transfer(owner, amount);
        }
    }

    function getInvestments(address investor) external view returns (Investment[] memory) {
        return investments[investor];
    }
}