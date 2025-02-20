// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./openzeppelin_contracts_token_ERC20_extensions_ERC20Burnable.sol";
import "./openzeppelin_contracts_access_Ownable.sol";

contract Tardigrade is ERC20Burnable, Ownable {
    // -------------------------
    // Constants and State Variables
    // -------------------------
    uint8 private constant _decimals = 12; // Specify token decimals
    bool public tradingActive = false; // Toggle trading status
    address public taxWallet; // Address where taxes are sent
    uint256 public sellTaxPercentage = 0; // Tax percentage (basis points, 10000 = 100%)

    mapping(address => bool) public isLiquidityPool; // Liquidity pool tracking
    mapping(address => bool) public isTaxExempt; // Tracks accounts exempt from taxes

    address[] private liquidityPoolAddresses; // List of liquidity pools
    address[] private taxExemptAddresses; // List of tax-exempt accounts

    // -------------------------
    // Constructor
    // -------------------------
    constructor() ERC20("Tardigrade", "TARDI") {
        uint256 initialSupply = 21_000_000 * 10 ** _decimals; // Setup initial supply considering 12 decimals
        _mint(msg.sender, initialSupply); // Mint initial supply to deployer
    }

    // -------------------------
    // Decimals Override
    // -------------------------
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    // -------------------------
    // Reader Functions
    // -------------------------

    /**
     * @dev Returns whether trading is currently active or not.
     */
    function getTradingStatus() external view returns (bool) {
        return tradingActive;
    }

    /**
     * @dev Returns the sell tax percentage in basis points.
     * Example: 500 represents 5%, 2500 represents 25%.
     */
    function getSellTaxPercentage() external view returns (uint256) {
        return sellTaxPercentage;
    }

    /**
     * @dev Returns the address of the current tax wallet.
     */
    function getTaxWallet() external view returns (address) {
        return taxWallet;
    }

    /**
     * @dev Returns the list of liquidity pool addresses.
     */
    function getLiquidityPoolAddresses()
        external
        view
        returns (address[] memory)
    {
        return liquidityPoolAddresses;
    }

    /**
     * @dev Returns the list of tax-exempt addresses.
     */
    function getTaxExemptAddresses() external view returns (address[] memory) {
        return taxExemptAddresses;
    }

    // -------------------------
    // Public/External Functions
    // -------------------------

    /**
     * @dev Initialize the tax wallet address.
     */
    function initializeTaxWallet(address _taxWallet) external onlyOwner {
        require(_taxWallet != address(0), "Invalid tax wallet");
        taxWallet = _taxWallet;
    }

    /**
     * @dev Set the percentage of tax applied on token sales.
     */
    function setSellTaxPercentage(
        uint256 _sellTaxPercentage
    ) external onlyOwner {
        require(_sellTaxPercentage <= 2500, "Sell tax cannot exceed 25%");
        sellTaxPercentage = _sellTaxPercentage;
    }

    /**
     * @dev Enable trading permanently.
     */
    function enableTrading() external onlyOwner {
        tradingActive = true;
        emit TradingEnabled();
    }

    /**
     * @dev Add a new liquidity pool address.
     */
    function addLiquidityPool(address _lpAddress) external onlyOwner {
        require(_lpAddress != address(0), "Invalid liquidity pool address");
        if (!isLiquidityPool[_lpAddress]) {
            isLiquidityPool[_lpAddress] = true;
            liquidityPoolAddresses.push(_lpAddress);
        }
    }

    /**
     * @dev Remove an existing liquidity pool address.
     */
    function removeLiquidityPool(address _lpAddress) external onlyOwner {
        require(isLiquidityPool[_lpAddress], "Address is not a liquidity pool");
        delete isLiquidityPool[_lpAddress];
        for (uint256 i = 0; i < liquidityPoolAddresses.length; i++) {
            if (liquidityPoolAddresses[i] == _lpAddress) {
                liquidityPoolAddresses[i] = liquidityPoolAddresses[
                    liquidityPoolAddresses.length - 1
                ];
                liquidityPoolAddresses.pop();
                break;
            }
        }
    }

    /**
     * @dev Set tax exemption status for an address.
     */
    function setTaxExemption(
        address _account,
        bool _exempt
    ) external onlyOwner {
        require(_account != address(0), "Invalid address");
        isTaxExempt[_account] = _exempt;

        if (_exempt) {
            taxExemptAddresses.push(_account);
        } else {
            for (uint256 i = 0; i < taxExemptAddresses.length; i++) {
                if (taxExemptAddresses[i] == _account) {
                    taxExemptAddresses[i] = taxExemptAddresses[
                        taxExemptAddresses.length - 1
                    ];
                    taxExemptAddresses.pop();
                    break;
                }
            }
        }
        emit TaxExemptionChanged(_account, _exempt);
    }

    /**
     * @dev Perform batch transfers to multiple recipients.
     */
    function batchTransfer(
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external onlyOwner {
        require(
            recipients.length == amounts.length,
            "Recipients and amounts length mismatch"
        );

        for (uint256 i = 0; i < recipients.length; i++) {
            _transfer(msg.sender, recipients[i], amounts[i]);
        }
    }

    // -------------------------
    // Internal Functions
    // -------------------------

    /**
     * @dev Override the `_transfer` function for tax logic.
     */
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        if (!tradingActive) {
            require(from == owner() || to == owner(), "Trading is not active");
        }

        uint256 taxAmount = 0;

        if (
            tradingActive &&
            taxWallet != address(0) &&
            sellTaxPercentage > 0 &&
            !isTaxExempt[from] &&
            !isTaxExempt[to] &&
            isLiquidityPool[to]
        ) {
            taxAmount = (amount * sellTaxPercentage + 9999) / 10000; // Round up tax amount
            _transfer(from, taxWallet, taxAmount);
            emit TaxApplied(from, to, amount, taxAmount);
            amount -= taxAmount;
        }

        super._transfer(from, to, amount);
    }

    // -------------------------
    // Events
    // -------------------------
    event TaxApplied(
        address indexed from,
        address indexed to,
        uint256 amount,
        uint256 taxAmount
    );
    event TradingEnabled();
    event TaxExemptionChanged(address indexed account, bool isExempt);
}