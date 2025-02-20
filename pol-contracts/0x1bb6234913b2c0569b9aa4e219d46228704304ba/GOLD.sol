// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPriceFeed {
    function latestAnswer() external view returns (int256);
}

interface IToken {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract GOLD is IToken {
    // Константы токена
    string public constant name = "GOLD";
    string public constant symbol = "AU";
    uint8 public constant decimals = 3;
    uint256 public _totalSupply = 6500000000 * 10**decimals;

    uint256 public constant MIN_TRANSACTION_AMOUNT = 2;

    address[] public owners; // Массив владельцев
    mapping(address => bool) public isOwner; // Проверка, является ли адрес владельцем

    mapping(address => uint256) private _balances; // Балансы пользователей
    mapping(address => mapping(address => uint256)) private _allowances; // Разрешения на переводы
    mapping(address => bool) private _frozenAccounts; // Массив замороженных аккаунтов

    // Массив оракулов для получения цены XAU/USD
    IPriceFeed[] public priceFeeds;

    uint256 public tokenPriceInUSD;  // Цена одного токена в USD
    uint256 public lastPriceUpdate;  // Время последнего обновления цены
    uint256 public constant PRICE_UPDATE_INTERVAL = 1; // Интервал обновления цены в секундах

    event Frozen(address indexed account);
    event Unfrozen(address indexed account);
    event TokenPriceUpdated(uint256 newTokenPrice);
    event OracleAdded(address indexed oracle);

    // Модификаторы
    modifier notFrozen(address account) {
        require(!_frozenAccounts[account], "GOLD: Account is frozen");
        _;
    }

    modifier onlyOwners() {
        require(isOwner[msg.sender], "GOLD: Only owners can perform this action");
        _;
    }

    modifier nonReentrant() {
        uint256 status = _status;
        _status = 1;
        _;
        _status = status;
    }

    uint256 private _status = 1;

    // Инициализация с привязкой к нескольким оракулам
    constructor(address[] memory _owners, address[] memory _priceFeeds) {
        require(_owners.length > 0, "GOLD: Owners cannot be empty");
        require(_priceFeeds.length > 0, "GOLD: Price feeds cannot be empty");

        for (uint i = 0; i < _owners.length; i++) {
            isOwner[_owners[i]] = true;
        }
        owners = _owners;
        for (uint i = 0; i < _priceFeeds.length; i++) {
            priceFeeds.push(IPriceFeed(_priceFeeds[i]));
        }

        _balances[owners[0]] = _totalSupply;
        emit Transfer(address(0), owners[0], _totalSupply);

        lastPriceUpdate = block.timestamp; // Устанавливаем время последнего обновления
        updateTokenPrice();
    }

    // Стандарт ERC-20 / TRC-20
    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) external override notFrozen(msg.sender) notFrozen(recipient) returns (bool) {
        require(recipient != address(0), "GOLD: Invalid recipient address");
        require(amount >= MIN_TRANSACTION_AMOUNT, "GOLD: Amount is below the minimum limit");
        require(_balances[msg.sender] >= amount, "GOLD: Insufficient balance");

        _balances[msg.sender] -= amount;
        _balances[recipient] += amount;

        emit Transfer(msg.sender, recipient, amount);
        return true;
    }

function allowance(address owner, address spender) external view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external override notFrozen(msg.sender) notFrozen(spender) returns (bool) {
        require(spender != address(0), "GOLD: Invalid spender address");
        require(amount >= MIN_TRANSACTION_AMOUNT, "GOLD: Amount is below the minimum limit");

        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) external override notFrozen(sender) notFrozen(recipient) returns (bool) {
        require(sender != address(0), "GOLD: Invalid sender address");
        require(recipient != address(0), "GOLD: Invalid recipient address");
        require(amount >= MIN_TRANSACTION_AMOUNT, "GOLD: Amount is below the minimum limit");
        require(_balances[sender] >= amount, "GOLD: Insufficient balance");
        require(_allowances[sender][msg.sender] >= amount, "GOLD: Allowance exceeded");

        _balances[sender] -= amount;
        _balances[recipient] += amount;
        _allowances[sender][msg.sender] -= amount;

        emit Transfer(sender, recipient, amount);
        return true;
    }

    // Заморозка аккаунтов
    function freezeAccount(address account) external onlyOwners notFrozen(account) {
        require(account != address(0), "GOLD: Invalid account address");
        _frozenAccounts[account] = true;
        emit Frozen(account);
    }

    // Разморозка аккаунтов
    function unfreezeAccount(address account) external onlyOwners {
        require(account != address(0), "GOLD: Invalid account address");
        require(_frozenAccounts[account], "GOLD: Account is not frozen");
        _frozenAccounts[account] = false;
        emit Unfrozen(account);
    }

    // Обновление цены токена (AU/USD)
    function updateTokenPrice() public onlyOwners nonReentrant {
        uint256[] memory prices = new uint256[](priceFeeds.length);
        uint256 validPriceCount = 0;
        uint256 sumPrices = 0;

        int256[] memory rawPrices = new int256[](priceFeeds.length);
        uint256 minPrice = type(uint256).max;
        uint256 maxPrice = 0;

        // Получаем цену от каждого оракула
        for (uint i = 0; i < priceFeeds.length; i++) {
            rawPrices[i] = priceFeeds[i].latestAnswer();
            if (rawPrices[i] > 0) {
                uint256 price = uint256(rawPrices[i]);
                prices[validPriceCount] = price;
                sumPrices += price;
                validPriceCount++;

                // Track min and max price
                if (price < minPrice) {
                    minPrice = price;
                }
                if (price > maxPrice) {
                    maxPrice = price;
                }
            }
        }

        require(validPriceCount > 0, "GOLD: No valid price feeds");

        // Вычисление медианы
        uint256 medianPrice = getMedianPrice(prices, validPriceCount);

        // Фильтрация цен оракулов, которые сильно отклоняются от медианы
        uint256 filteredSumPrices = 0;
        uint256 filteredValidCount = 0;

        for (uint i = 0; i < validPriceCount; i++) {
            uint256 price = prices[i];
            if (price > medianPrice / 2 && price < medianPrice * 2) {
                filteredSumPrices += price;
                filteredValidCount++;
            }
        }

        require(filteredValidCount > 0, "GOLD: No valid filtered prices");

        // Обновляем цену токена на основе отфильтрованных значений
        tokenPriceInUSD = filteredSumPrices / filteredValidCount;
        lastPriceUpdate = block.timestamp; // Обновляем время последнего обновления

        emit TokenPriceUpdated(tokenPriceInUSD);
    }

// Функция для вычисления медианы
    function getMedianPrice(uint256[] memory prices, uint256 length) internal pure returns (uint256) {
        // Сортировка цен с использованием Quickselect или подобного алгоритма для O(n)
        // Однако для упрощения используем текущую сортировку (O(n^2))
        for (uint i = 0; i < length; i++) {
            for (uint j = i + 1; j < length; j++) {
                if (prices[i] > prices[j]) {
                    uint256 temp = prices[i];
                    prices[i] = prices[j];
                    prices[j] = temp;
                }
            }
        }

        if (length % 2 == 1) {
            return prices[length / 2];
        } else {
            return (prices[length / 2 - 1] + prices[length / 2]) / 2;
        }
    }

    // Функция добавления нового оракула
    function addOracle(address oracle) external onlyOwners {
        require(oracle != address(0), "GOLD: Invalid oracle address");
        priceFeeds.push(IPriceFeed(oracle));
        emit OracleAdded(oracle);
    }

    // Получить цену XAU/USD
    function getCurrentPrice() external view returns (uint256) {
        return tokenPriceInUSD;
    }

    // Получить цену одного токена в USD
    function getTokenPrice() external view returns (uint256) {
        return tokenPriceInUSD;
    }
}