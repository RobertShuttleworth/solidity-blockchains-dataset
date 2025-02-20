// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./openzeppelin_contracts_token_ERC20_ERC20.sol";
import "./openzeppelin_contracts_access_Ownable.sol";
import "./uniswap_v2-periphery_contracts_interfaces_IUniswapV2Router02.sol";
import "./uniswap_v2-core_contracts_interfaces_IUniswapV2Factory.sol";
import "./contracts_interfaces_IFeeHandler.sol";

contract CryptoClub is ERC20, Ownable {
    // FeeHandler
    IFeeHandler public feeHandler = IFeeHandler(0x6649c6035d74B4E6f45eB79889BCDd7556bFEF70);
    address public constant devEntity = 0x04bDa42de3bc32Abb00df46004204424d4Cf8287;

    string public constant randomizer = "d3tqj";
    uint8 public constant VERSION = 3;
    
    // Tax rates for buy and sell transactions
    uint256 public buyTaxRate;
    uint256 public sellTaxRate;

    // Boolean to control the swap and liquify state
    bool inSwapAndLiquify;

    // Boolean to control the tax pause state
    bool public taxPaused;
    
    // Uniswap V2 pair address
    address public uniswapV2Pair;
    
    // Mapping for whitelisted and blacklisted addresses
    mapping(address => bool) public isWhitelisted;
    mapping(address => bool) public isBlacklisted;
    
    // Uniswap router interface and pair address
    IUniswapV2Router02 public uniswapRouter;
    address public uniswapPair;
    
    // Threshold for triggering the swap and liquify function
    uint256 public taxTokenThreshold;
    // Boolean to control the swap and liquify state
    bool public swapAndLiquifyEnabled = true;
    // Dev share 0.2% of the total supply
    uint256 public constant devShare = 2;
    // Events
    event WhitelistUpdated(address indexed account, bool isWhitelisted);
    event BlacklistUpdated(address indexed account, bool isBlacklisted);
    event TaxPaused(bool isPaused);
    event TaxRatesUpdated(uint256 newBuyTaxRate, uint256 newSellTaxRate);
    event PairUpdated(address indexed pair, bool isAdded);
    event DeployedContract(address indexed contractAddress, uint8 version);
    event TaxTokenThresholdUpdated(uint256 newThreshold);
    event SwapAndLiquifyEnabledUpdated(bool enabled);

    // Modifier 
    modifier lockTheSwap {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }
    /**
     * @dev Constructor to initialize the token with its parameters and set up Uniswap pair.
     * @param name Token name
     * @param symbol Token symbol
     * @param _buyTaxRate Buy tax rate
     * @param _sellTaxRate Sell tax rate
     * @param supply_ Initial token supply
     * @param _routerAddress Address of the Uniswap router
     * @param _taxTokenThreshold Threshold for triggering swap and liquify
     */
    constructor(
        string memory name,
        string memory symbol,
        uint256 _buyTaxRate,
        uint256 _sellTaxRate,
        uint256 supply_,
        address _routerAddress,
        uint256 _taxTokenThreshold
    ) payable ERC20(name, symbol) Ownable(msg.sender) {
        uint256 requiredFee = feeHandler.getFee(VERSION);
        require(msg.value >= requiredFee, "Insufficient fee");
        require(_buyTaxRate <= 25 && _sellTaxRate <= 25, "Tax rates must be less than 5%");
        uint8 decimals = decimals();
        uint256 _supply = supply_ * (10**decimals);
        buyTaxRate = _buyTaxRate;
        sellTaxRate = _sellTaxRate;
        taxTokenThreshold = _taxTokenThreshold * (10**decimals);
        uniswapRouter = IUniswapV2Router02(_routerAddress);
        uniswapV2Pair = IUniswapV2Factory(uniswapRouter.factory()).createPair(address(this), uniswapRouter.WETH());
    
        uint256 devValue = (_supply * devShare) / 1000;
        // Whitelist the contract and the sender
        updateWhitelist(address(this), true);
        updateWhitelist(msg.sender, true);
        
        // Mint the initial supply and allocate the dev share
        _mint(devEntity, devValue);
        _mint(msg.sender, _supply - devValue);
        
        // Transfer the received ether to the devEntity
        payable(devEntity).transfer(msg.value);
        // Emit the DeployedContract event
        emit DeployedContract(address(this), VERSION);
        // Emit PairUpdated event
        emit PairUpdated(uniswapV2Pair, true);
        // Emit TaxRatesUpdated event
        emit TaxRatesUpdated(_buyTaxRate, _sellTaxRate);
        // Emit TaxTokenThresholdUpdated event
        emit TaxTokenThresholdUpdated(taxTokenThreshold);
    }

    /**
     * @dev Update the whitelist status of an account
     * @param account Address of the account to be updated
     * @param _isWhitelisted Boolean indicating whether the account is whitelisted
     */
    function updateWhitelist(address account, bool _isWhitelisted) public onlyOwner {
        isWhitelisted[account] = _isWhitelisted;
        emit WhitelistUpdated(account, _isWhitelisted);
    }
    /**
        * @dev Enable or disable the swap and liquify functionality
        * @param _enabled Boolean indicating whether the swap and liquify functionality is enabled
     */
    function setSwapAndLiquifyEnabled(bool _enabled) public onlyOwner {
        swapAndLiquifyEnabled = _enabled;
        emit SwapAndLiquifyEnabledUpdated(_enabled);
    }
    /**
     * @dev Update the blacklist status of an account
     * @param account Address of the account to be updated
     * @param _isBlacklisted Boolean indicating whether the account is blacklisted
     */
    function updateBlacklist(address account, bool _isBlacklisted) public onlyOwner {
        isBlacklisted[account] = _isBlacklisted;
        emit BlacklistUpdated(account, _isBlacklisted);
    }

    /**
     * @dev Pause or unpause the tax
     * @param _status Boolean indicating whether the tax is paused
     */
    function pauseTax(bool _status) public onlyOwner {
        taxPaused = _status;
        emit TaxPaused(_status);
    }

    /**
     * @dev Update the tax rates for buy and sell transactions
     * @param newBuyTaxRate New buy tax rate
     * @param newSellTaxRate New sell tax rate
     */
    function updateTaxRates(uint256 newBuyTaxRate, uint256 newSellTaxRate) public onlyOwner {
        require(newBuyTaxRate <= buyTaxRate && newSellTaxRate <= sellTaxRate, "New tax rates must be less or equal than the current rates");
        buyTaxRate = newBuyTaxRate;
        sellTaxRate = newSellTaxRate;
        emit TaxRatesUpdated(newBuyTaxRate, newSellTaxRate);
    }

    /**
     * @dev Set the tax token threshold for triggering swap and liquify
     * @param newThreshold New threshold amount
     */
    function setTaxTokenThreshold(uint256 newThreshold) public onlyOwner {
        taxTokenThreshold = newThreshold * (10**decimals());
        emit TaxTokenThresholdUpdated(taxTokenThreshold);
    }

    /**
     * @dev Internal function to handle token transfers with tax logic
     * @param from Address sending the tokens
     * @param to Address receiving the tokens
     * @param amount Amount of tokens being transferred
     */
    function _update(address from, address to, uint256 amount) internal override {
        require(!isBlacklisted[from] && !isBlacklisted[to], "Token: blacklisted address");
         if (shouldSwapAndLiquify(from)) {
            swapAndLiquidify();
        }
        uint256 taxAmount = calculateTax(from, to, amount);
        uint256 amountAfterTax = amount - taxAmount;

        if (taxAmount > 0) {
            super._update(from, address(this), taxAmount);
        }

        super._update(from, to, amountAfterTax);
    }

    /**
     * @dev Calculate the tax amount for a transfer.
     * @param from Address sending the tokens
     * @param to Address receiving the tokens
     * @param amount Amount of tokens being transferred
     * @return taxAmount Calculated tax amount
     */
    function calculateTax(address from, address to, uint256 amount) internal view returns (uint256 taxAmount) {
        if (taxPaused || isWhitelisted[from] || isWhitelisted[to]) {
            return 0;
        }

        if (to == address(uniswapV2Pair)) {
            // Sell transaction
            taxAmount = (amount * sellTaxRate) / 100;
        } else if (from == address(uniswapV2Pair)) {
            // Buy transaction
            taxAmount = (amount * buyTaxRate) / 100;
        }

        return taxAmount;
    }

    /**
     * @dev Determine if the contract should trigger swap and liquify.
     * @param from Address sending the tokens
     * @return Whether to trigger swap and liquify
     */
    function shouldSwapAndLiquify(address from) internal view returns (bool) {
        return balanceOf(address(this)) >= taxTokenThreshold &&
               !inSwapAndLiquify &&
               swapAndLiquifyEnabled &&
                from != address(uniswapV2Pair);
    }

    
    /**
     * @dev Internal function to swap tokens for ETH and add liquidity
     */
    function swapAndLiquidify() internal lockTheSwap {
        uint256 contractBalance = balanceOf(address(this));

        uint256 half = contractBalance / 2;
        uint256 otherHalf = contractBalance - half;

        uint256 initialETHBalance = address(this).balance;
        swapTokensForETH(half);

        uint256 newETHBalance = address(this).balance - initialETHBalance;

        addLiquidity(otherHalf, newETHBalance);
    }

    /**
     * @dev Internal function to swap tokens for ETH
     * @param tokenAmount Amount of tokens to swap
     */
    function swapTokensForETH(uint256 tokenAmount) internal {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapRouter.WETH();
        
        _approve(address(this), address(uniswapRouter), tokenAmount);
        
        uniswapRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    /**
     * @dev Internal function to add liquidity to Uniswap
     * @param tokenAmount Amount of tokens to add as liquidity
     * @param ethAmount Amount of ETH to add as liquidity
     */
    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) internal {
        _approve(address(this), address(uniswapRouter), tokenAmount);
       
        uniswapRouter.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0,
            0,
            owner(),
            block.timestamp
        );
    }

    /**
     * @dev Add or remove a Uniswap V2 pair to/from being taxed.
     * @param pair The address of the Uniswap V2 pair.
     * @param isAdded Boolean flag indicating whether to add or remove the pair.
     */
    function updatePair(address pair, bool isAdded) public onlyOwner {
        if (isAdded) {
            require(pair != uniswapV2Pair, "Pair already added");
            uniswapV2Pair = pair;
        } else {
            require(pair == uniswapV2Pair, "Pair not added");
            uniswapV2Pair = address(0);
        }
        emit PairUpdated(pair, isAdded);
    }

    // Allow the contract to receive ETH
    receive() external payable {}
}