// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";
import "./openzeppelin_contracts-upgradeable_access_OwnableUpgradeable.sol";
import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./contracts_BasicMetaTransaction.sol";
import "./openzeppelin_contracts-upgradeable_access_AccessControlUpgradeable.sol";

contract Trade is
    Initializable,
    BasicMetaTransaction,
    AccessControlUpgradeable
{
    bytes32 public constant USDT_SENDER = keccak256("USDT_SENDER");
    IERC20 public usdt;
    IERC20 public token;
    address public adminWallet;
    uint public totalUsdtCollected;
    uint private totalUsdtWithoutCP;
    uint public tokenSold;
    bool public isCustomPrice;
    uint public customPrice;
    uint[] public range;
    uint[] public price;
    uint[] public usdtMaxAmount;
    uint public currentIndex;
    uint constant usdtDecimals = 10 ** 6;
    uint constant tokenDecimals = 10 ** 18;

    event TokensPurchased(
        address indexed buyer,
        uint256 indexed amount,
        uint256 indexed totalPrice
    );
    event TransferUsdt(address _from, address _to, uint256 _amount);
    event PriceSet(uint256 newPrice);
    event USDTUpdated(address newUSDT);

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _usdt,
        address _token,
        address _adminWallet,
        address _usdtSender
    ) public initializer {
        usdt = IERC20(_usdt);
        token = IERC20(_token);
        adminWallet = _adminWallet;
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(USDT_SENDER, _usdtSender);
        __AccessControl_init();
        usdtMaxAmount.push(500000000000);
        for (uint i = 1; i <= 60; i++) {
            range.push(500 * (i * tokenDecimals));
            price.push(500 * ((i + 1) * usdtDecimals));
        }
    }

    function getRange() external view returns (uint[] memory) {
        return range;
    }

    function setUsdtMaxAmount() external onlyRole(DEFAULT_ADMIN_ROLE) {
        for (uint i = 1; i < 60; i++) {
            usdtMaxAmount.push((500 * price[i]) + usdtMaxAmount[i - 1]);
        }
    }

    function resetCustomPrice(
        bool _data
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        isCustomPrice = _data;
    }

    function setCustomPrice(
        uint256 _newPrice
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        customPrice = _newPrice;
        isCustomPrice = true;
        emit PriceSet(_newPrice);
    }

    function getPrice() external view returns (uint[] memory) {
        return price;
    }

    function getUsdtMaxAmount() external view returns (uint[] memory) {
        return usdtMaxAmount;
    }

    function getCurrentIndex() external view returns (uint) {
        return currentIndex;
    }

    function updateUSDT(address _usdt) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_usdt != address(0), "invalid address");
        usdt = IERC20(_usdt);
        emit USDTUpdated(_usdt);
    }

    function buyToken(uint _tokenAmount) external {
        uint totalPriceInUSDC;
        uint usdtWithoutCP;
        uint finalPrice;
        require(_tokenAmount > 20 * usdtDecimals, "Invalid Amount");
        (totalPriceInUSDC, currentIndex, usdtWithoutCP) = calculatePrice(
            _tokenAmount
        );
        tokenSold += _tokenAmount;
        require(tokenSold <= 30000 * tokenDecimals, "max limit reached");
        totalUsdtCollected += totalPriceInUSDC;
        totalUsdtWithoutCP += usdtWithoutCP;

        if (isCustomPrice) {
            finalPrice = totalPriceInUSDC;
            usdt.transferFrom(_msgSender(), adminWallet, totalPriceInUSDC);
        } else {
            finalPrice = usdtWithoutCP;
            usdt.transferFrom(_msgSender(), adminWallet, usdtWithoutCP);
        }
        token.transfer(_msgSender(), _tokenAmount);
        emit TokensPurchased(_msgSender(), _tokenAmount, finalPrice);
    }

    function calculatePrice(
        uint _tokenAmount
    )
        public
        view
        returns (uint totalPrice, uint tempIndex, uint usdtWithoutCP)
    {
        uint currentTokensold = tokenSold;
        uint tempTotalTokenSold = tokenSold + _tokenAmount;
        tempIndex = currentIndex;
        require(
            tempTotalTokenSold <= (30000 * tokenDecimals),
            "max limit reached"
        );

        if (tempTotalTokenSold <= range[currentIndex]) {
            usdtWithoutCP =
                (_tokenAmount * price[currentIndex]) /
                tokenDecimals;
            if (tempTotalTokenSold == range[currentIndex]) {
                tempIndex++;
            }
        } else {
            uint quotient = tempTotalTokenSold / (500 * tokenDecimals);
            for (uint i = currentIndex; i < quotient; i++) {
                uint tokenAmount = range[i] - currentTokensold;
                usdtWithoutCP += ((tokenAmount * price[i]) / tokenDecimals);
                currentTokensold += tokenAmount;
            }
            if (quotient == 60) {
                quotient -= 1;
            }
            uint tempCal = (tempTotalTokenSold - currentTokensold) *
                price[quotient];

            usdtWithoutCP += (tempCal / tokenDecimals);
            tempIndex = quotient;
        }

        if (isCustomPrice) {
            totalPrice = (_tokenAmount * customPrice) / tokenDecimals;
            while (tempTotalTokenSold >= range[tempIndex]) {
                tempIndex++;
            }
        }

        return (totalPrice, tempIndex, usdtWithoutCP);
    }

    function calculatePriceWithUSDT(
        uint _usdtAmount
    ) external view returns (uint) {
        require(tokenSold < (30000 * tokenDecimals), "max limit reached");
        uint tempTotalUsdt = totalUsdtWithoutCP + _usdtAmount;
        if (isCustomPrice) {
            return (_usdtAmount * tokenDecimals) / customPrice;
        }
        if (tempTotalUsdt <= usdtMaxAmount[currentIndex]) {
            return (_usdtAmount * tokenDecimals) / price[currentIndex];
        } else {
            uint tempIndex = currentIndex;
            uint tempUSDTSold = totalUsdtWithoutCP;
            uint totalTokens;
            while (tempUSDTSold < tempTotalUsdt) {
                uint currentIndexUsdt;
                if (usdtMaxAmount[tempIndex] > tempTotalUsdt) {
                    currentIndexUsdt = tempTotalUsdt - tempUSDTSold;
                } else {
                    currentIndexUsdt = usdtMaxAmount[tempIndex] - tempUSDTSold;
                }
                tempUSDTSold += currentIndexUsdt;
                uint tokens = (currentIndexUsdt * tokenDecimals) /
                    price[tempIndex];
                totalTokens += tokens;
                tempIndex++;
            }
            if (tempIndex == 60) {
                require(
                    tempTotalUsdt <= usdtMaxAmount[tempIndex - 1],
                    "max limit reached"
                );
            }
            return totalTokens;
        }
    }

    function transferUSDT(
        address _from,
        address _to,
        uint256 _amount
    ) external onlyRole(USDT_SENDER) {
        require(_amount > (usdtDecimals / 10), "Invalid Amount");
        usdt.transferFrom(_from, _to, _amount);
        emit TransferUsdt(_from, _to, _amount);
    }

    function _msgSender()
        internal
        view
        override(ContextUpgradeable, BasicMetaTransaction)
        returns (address sender)
    {
        if (msg.sender == address(this)) {
            bytes memory array = msg.data;
            uint256 index = msg.data.length;
            assembly {
                // Load the 32 bytes word from memory with the address on the lower 20 bytes, and mask those.
                sender := and(
                    mload(add(array, index)),
                    0xffffffffffffffffffffffffffffffffffffffff
                )
            }
        } else {
            return msg.sender;
        }
    }

    function getCurrentPrice() external view returns (uint) {
        return price[currentIndex];
    }

    function getTotalUSDTSold() external view returns (uint) {
        return totalUsdtWithoutCP;
    }

    function changeAdminWallet(
        address _newWallet
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        adminWallet = _newWallet;
    }
}