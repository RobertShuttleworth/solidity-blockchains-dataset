// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// openzeppelin
import {IERC20} from "./lib_openzeppelin-contracts-upgradeable_lib_openzeppelin-contracts_contracts_token_ERC20_IERC20.sol";
import {IERC20Metadata} from "./lib_openzeppelin-contracts-upgradeable_lib_openzeppelin-contracts_contracts_token_ERC20_extensions_IERC20Metadata.sol";
import {IERC721Receiver} from "./lib_openzeppelin-contracts-upgradeable_lib_openzeppelin-contracts_contracts_token_ERC721_IERC721Receiver.sol";
import {IERC721} from "./lib_openzeppelin-contracts-upgradeable_lib_openzeppelin-contracts_contracts_token_ERC721_IERC721.sol";
import {IERC721Enumerable} from "./lib_openzeppelin-contracts-upgradeable_lib_openzeppelin-contracts_contracts_token_ERC721_extensions_IERC721Enumerable.sol";
import {UUPSUpgradeable} from "./lib_openzeppelin-contracts-upgradeable_contracts_proxy_utils_UUPSUpgradeable.sol";
import {AccessControl} from './src_utils_AccessControl.sol';
import {IUniswapV3PoolState} from './src_interfaces_IUniswapV3PoolState.sol';
import {IEACAggregatorProxy} from './src_interfaces_IEACAggregatorProxy.sol';
import {ISwapRouter} from './lib_uniswap_v3-periphery_contracts_interfaces_ISwapRouter.sol';
import {INonfungiblePositionManager} from './lib_uniswap_v3-periphery_contracts_interfaces_INonfungiblePositionManager.sol';
// src
import {TokenTransfer} from './src_utils_TokenTransfer.sol';
import {UniswapV3PositionHelper} from './src_libraries_UniswapV3PositionHelper.sol';
import {LiqAmountCalculator} from './src_libraries_LiqAmountCalculator.sol';
import {IFluxFarmV2} from './src_interfaces_IFluxFarmV2.sol';
import {AutomationCompatibleInterface} from './src_interfaces_AutomationCompatibleInterface.sol';


contract FluxFarmV2 is AutomationCompatibleInterface, UUPSUpgradeable, AccessControl, TokenTransfer, IERC721Receiver, IFluxFarmV2 {
    event Invest(address token_, uint256 amount_, uint256 value_, uint256 newTotalInvest_);
    event Withdraw(address token_, uint256 amount_, uint256 value_, uint256 newTotalWithdraw_);
    event Harvest(uint256 totalAmount0_, uint256 totalAmount1_, uint256 totalFees0_, uint256 totalFees1_);
    event Reinvest(uint256 tokenId_, uint256 liquidity_, uint256 amount0_, uint256 amount1_);
    event UpdateFarm(address msgSender_, uint256 timestamp_, uint256 blockNumber_);
    event ReBalanceToken(uint256 amount0_, uint256 amount1_);
    event CutServiceFee(uint256 serviceFee0_, uint256 serviceFee1_);
    event SwapExactInputSingle(
        address tokenIn_,
        address tokenOut_,
        uint256 amountIn_,
        uint256 amountOutMin_,
        address recipient_,
        uint256 amountOut_
    );
    event InitialPosition(uint256 positionCount_);
    event CloseAllPosition(
        uint256 totalAmount0_,
        uint256 totalAmount1_,
        uint256 totalFees0_,
        uint256 totalFees1_,
        uint256 nowBalanceToken0_,
        uint256 nowBalanceToken1_
    );

    struct FarmingInfo {
        bool hasOutOfAllTicks;
        uint256 tokenId;
        int24 tickLower;
        int24 tickUpper;
    }

    struct TokenInfo {
        uint256 decimals;
        uint256 price;
        address oracle;
        uint256 oracleDecimals;
    }

    struct HarvestInfo {
        uint256 investID;
        uint256 startTimestamp;
        uint256 endTimestamp;
        uint256 tokenId;
        uint256 liquidity;
        uint256 totalFees0;
        uint256 totalFees1;
    }

    // initialize
    INonfungiblePositionManager public positionManager;
    IUniswapV3PoolState public poolState;
    ISwapRouter public swapRouter;
    address public this_;
    address public receiver;
    address public token0;
    address public token1;
    uint24 public fee;
    mapping(address => TokenInfo) public tokenInfo;

    // state
    FarmingInfo public farmingInfo;
    IUniswapV3PoolState.Slot0 public farmingSlot0;
    uint256 public totalInvest;
    uint256 public totalWithdraw;
    uint256 public updateInterval;
    uint256 public lastUpdateTimestamp;
    uint256 public token1PriceInToken0;
    mapping(address => uint256) public tokenInvest;
    mapping(address => uint256) public tokenWithdraw;

    uint256 public latestInvestID;
    mapping(uint256 => HarvestInfo) public harvestInfo;
    
    // config
    uint256 public slippage;
    uint256 public serviceFeeFactor;

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyRole(DEFAULT_ADMIN_ROLE)
        override
    {}

    // Implement onERC721Received to accept NFT
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    modifier renewFarm(bool checkTrigger_) {
        if (checkTrigger_) {
            require(updateFarmTrigger(), "No need to update");
        }

        _updatePrice();
        _updatePoolState();
        _updateFarmingInfo();
        _harvest();
        _;
        _reinvest();
        _updateTimeLabel();
    }

    function initialize(
        address uniswapV3Pool_,
        address positionManager_,
        address swapRouterAddress_,
        address token0_,
        address token1_,
        address token0Oracle_,
        address token1Oracle_
    ) public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MANAGER, msg.sender);
        _grantRole(SAFE_ADMIN, msg.sender);
        
        receiver = msg.sender;
        this_ = address(this);
        positionManager = INonfungiblePositionManager(positionManager_);
        swapRouter = ISwapRouter(swapRouterAddress_);
        poolState = IUniswapV3PoolState(uniswapV3Pool_);
        fee = poolState.fee();
        token0 = token0_;
        token1 = token1_;
        uint256 _token0Decimals = IERC20Metadata(token0_).decimals();
        uint256 _token1Decimals = IERC20Metadata(token1_).decimals();
        uint256 _token0OracleDeimals = uint256(IEACAggregatorProxy(token0Oracle_).decimals());
        uint256 _token1OracleDeimals = uint256(IEACAggregatorProxy(token1Oracle_).decimals());

        require(_token0Decimals > 0 && _token1Decimals > 0, "INVALID_TOKEN_DECIMALS");
        require(_token0OracleDeimals > 0 && _token1OracleDeimals > 0, "INVALID_ORACLE_DECIMALS");

        tokenInfo[token0] = TokenInfo({
            decimals: _token0Decimals,
            price: 0,
            oracle: token0Oracle_,
            oracleDecimals: _token0OracleDeimals
        });

        tokenInfo[token1] = TokenInfo({
            decimals: _token1Decimals,
            price: 0,
            oracle: token1Oracle_,
            oracleDecimals: _token1OracleDeimals
        });

        IERC20(token0).approve(address(positionManager_), type(uint256).max);
        IERC20(token1).approve(address(positionManager_), type(uint256).max);

        IERC20(token0).approve(address(swapRouterAddress_), type(uint256).max);
        IERC20(token1).approve(address(swapRouterAddress_), type(uint256).max);
    }

    /// @inheritdoc IFluxFarmV2
    function getPositionBalance() public view returns (uint256) {
        return IERC721(address(positionManager)).balanceOf(this_);
    }

    /// @inheritdoc IFluxFarmV2
    function outOfRangeTrigger() public view returns (bool) {
        // get tick from slot0
        (,int24 tick,,,,,) = poolState.slot0();

        // check the tick is out of range
        if (tick < farmingInfo.tickLower || tick > farmingInfo.tickUpper) {
            return true;
        }
        return false;
    }

    /// @inheritdoc IFluxFarmV2
    function timeTrigger() public view returns (bool) {
        if (block.timestamp - lastUpdateTimestamp >= updateInterval) {
            return true;
        }
        return false;
    }

    /// @inheritdoc IFluxFarmV2
    function updateFarmTrigger() public view returns (bool) {
        if (outOfRangeTrigger() || timeTrigger()) {
            return true;
        }
        return false;
    }

    /// @inheritdoc IFluxFarmV2
    function getFarmingInfo() public view returns (uint256, int24, int24) {
        return (farmingInfo.tokenId, farmingInfo.tickLower, farmingInfo.tickUpper);
    }

    /// @inheritdoc IFluxFarmV2
    function getPositionFee(uint256 tokenId_) public view returns (uint256, uint256) {
        (
            ,,,,,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        ) = positionManager.positions(tokenId_);
        
        (uint256 fees0, uint256 fees1) = UniswapV3PositionHelper.getPositionFees(
            address(poolState),
            farmingSlot0.tick,
            tickLower,
            tickUpper,
            liquidity,
            feeGrowthInside0LastX128,
            feeGrowthInside1LastX128,
            tokensOwed0,
            tokensOwed1
        );
       
        return (fees0, fees1);
    }

    /// @inheritdoc IFluxFarmV2
    function getPriceIn1e18(address token_) public view returns (uint256) {
        (, int price, , , ) = IEACAggregatorProxy(tokenInfo[token_].oracle).latestRoundData();  // price is in 1e8
        require(price > 0, "Invalid price data");
        return uint256(price) * 1e18 / (10 ** tokenInfo[token_].oracleDecimals);
    }

    /// @inheritdoc IFluxFarmV2
    function getTokenValue(address token_, uint256 amount_) public view returns (uint256) {
        uint256 _price = getPriceIn1e18(token_);
        return amount_ * _price / (10 ** tokenInfo[token_].decimals);
    }

    /// @inheritdoc IFluxFarmV2
    function getAmountAfterSlippage(uint256 amount_, uint256 slippage_) public pure returns (uint256) {
        return amount_ * (1e18 - slippage_) / 1e18;
    }

    /// @inheritdoc IFluxFarmV2
    function getAmountOutMin(address tokenIn_, address tokenOut_, uint256 amountIn_) public view returns (uint256) {
        if (tokenIn_ == token0 && tokenOut_ == token1) {
            uint256 amountIn_1e18 = amountIn_ * 1e18 / (10 ** tokenInfo[token0].decimals);
            uint256 tokenInPrice = getPriceIn1e18(token0);
            uint256 tokenOutPrice = getPriceIn1e18(token1);
            uint256 amountOutMin = getAmountAfterSlippage(amountIn_1e18 * tokenInPrice / tokenOutPrice, slippage);
            return amountOutMin * (10 ** tokenInfo[token1].decimals) / 1e18;
        }

        if (tokenIn_ == token1 && tokenOut_ == token0) {
            uint256 amountIn_1e18 = amountIn_ * 1e18 / (10 ** tokenInfo[token1].decimals);
            uint256 tokenInPrice = getPriceIn1e18(token1);
            uint256 tokenOutPrice = getPriceIn1e18(token0);
            uint256 amountOutMin = getAmountAfterSlippage(amountIn_1e18 * tokenInPrice / tokenOutPrice, slippage);
            return amountOutMin * (10 ** tokenInfo[token0].decimals) / 1e18;
        }
        revert("INVALID_TOKEN");
    }

    /// @inheritdoc IFluxFarmV2
    function getAllPositionFees() public view returns (uint256 totalFees0, uint256 totalFees1) {
        uint256 balance = getPositionBalance();
        for (uint256 i = 0; i < balance; i++) {
            uint256 tokenId = IERC721Enumerable(address(positionManager)).tokenOfOwnerByIndex(this_, i);
            (uint256 fees0, uint256 fees1) = getPositionFee(tokenId);
            totalFees0 += fees0;
            totalFees1 += fees1;
        }
        return (totalFees0, totalFees1);        
    }

    /// @inheritdoc IFluxFarmV2
    function getAmountByBestLiquidity(
        uint256 positionValueInToken0_,
        int24 tickCurrent_,
        int24 tickLower_,
        int24 tickUpper_
    ) public view returns (uint256, uint256) {
        (uint256 token0_factor, uint256 token1_factor) = LiqAmountCalculator.getFactor(
            tickCurrent_,
            tickLower_,
            tickUpper_,
            tokenInfo[token0].decimals,
            tokenInfo[token1].decimals
        );

        return LiqAmountCalculator.getAmountByBestLiquidity(
            token0_factor,
            token1_factor,
            positionValueInToken0_,
            tokenInfo[token0].decimals,
            tokenInfo[token1].decimals,
            token1PriceInToken0
        );
    }

    /**
    * @notice swap token with exact input single
    */
    function _swapExactInputSingle(
        address tokenIn_,
        address tokenOut_,
        uint256 amountIn_,
        address recipient_
    ) internal returns (uint256) {
        IERC20(tokenIn_).approve(address(swapRouter), amountIn_);
        uint256 amountOutMin = getAmountOutMin(tokenIn_, tokenOut_, amountIn_);
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: tokenIn_,
            tokenOut: tokenOut_,
            fee: fee,
            recipient: recipient_,
            deadline: block.timestamp + 1000,
            amountIn: amountIn_,
            amountOutMinimum: amountOutMin,
            sqrtPriceLimitX96: 0
        });
        uint256 amountOut = swapRouter.exactInputSingle(params);
        emit SwapExactInputSingle(tokenIn_, tokenOut_, amountIn_, amountOutMin, recipient_, amountOut);
        return amountOut;
    }

    /**
    * @notice get the value of position in token0.
    * @param token0Amount_ uint256
    * @param token1Amount_ uint256
    * @return valueInToken0
    */
    function _getValueInToken0(uint256 token0Amount_, uint256 token1Amount_) internal view returns (uint256) {
        // trans amonut to 1e18
        uint256 token0Amount = token0Amount_ * 1e18 / (10 ** tokenInfo[token0].decimals);
        uint256 token1Amount = token1Amount_ * 1e18 / (10 ** tokenInfo[token1].decimals);

        uint256 token0Value = token0Amount * 1;  // just for explain, token0 per token0
        uint256 token1ValueInToken0 = token1Amount * token1PriceInToken0 / 1e18;  // token0 per token1
        return token0Value + token1ValueInToken0;
    }

    function _updateTimeLabel() internal {
        lastUpdateTimestamp = block.timestamp;
    }

    /**
    * @notice update the token0 and token1 price, transfer the price from oracle(1e8) to 1e18
    */
    function _updatePrice() internal {
        uint256 _token0Price = getPriceIn1e18(token0);
        uint256 _token1Price = getPriceIn1e18(token1);

        tokenInfo[token0].price = _token0Price;
        tokenInfo[token1].price = _token1Price;
        token1PriceInToken0 = _token1Price * 1e18 / _token0Price;
    }

    /**
    * @notice update the pool slot0 before update the farming info
    */
    function _updateFarmingInfo() internal {
        uint256 balance = getPositionBalance();
        for (uint256 i = 0; i < balance; i++) {
            uint256 tokenId = IERC721Enumerable(address(positionManager)).tokenOfOwnerByIndex(this_, i);
            (,,,,,int24 tickLower,int24 tickUpper,,,,,) = positionManager.positions(tokenId);
            if (farmingSlot0.tick >= tickLower && farmingSlot0.tick <= tickUpper) {
                farmingInfo.hasOutOfAllTicks = false;
                farmingInfo.tokenId = tokenId;
                farmingInfo.tickLower = tickLower;
                farmingInfo.tickUpper = tickUpper;
                return;
            }
        }
        farmingInfo.hasOutOfAllTicks = true;
    }

    /**
    * @notice update the pool state
    */
    function _updatePoolState() internal {
        (
            farmingSlot0.sqrtPriceX96,
            farmingSlot0.tick,
            farmingSlot0.observationIndex,
            farmingSlot0.observationCardinality,
            farmingSlot0.observationCardinalityNext,
            farmingSlot0.feeProtocol,
            farmingSlot0.unlocked
        ) = poolState.slot0();
    }

    /**
    * @notice update the harvest info when harvest
    * @param totalFees0_ uint256
    * @param totalFees1_ uint256
    */
    function _updateHarvestInfoWhenHarvest(uint256 totalFees0_, uint256 totalFees1_) internal {
        harvestInfo[latestInvestID].endTimestamp = block.timestamp;
        harvestInfo[latestInvestID].totalFees0 = totalFees0_;
        harvestInfo[latestInvestID].totalFees1 = totalFees1_;
    }

    /**
    * @notice update the harvest info when reinvest
    * @param tokenId_ uint256
    */
    function _updateHarvestInfoWhenInvest(uint256 tokenId_) internal {
        // get liquidity
        (,,,,,,,uint128 liquidity_,,,,) = positionManager.positions(tokenId_);

        latestInvestID++;
        harvestInfo[latestInvestID].investID = latestInvestID;
        harvestInfo[latestInvestID].startTimestamp = block.timestamp;
        harvestInfo[latestInvestID].tokenId = tokenId_;
        harvestInfo[latestInvestID].liquidity = liquidity_;
    }

    /**
    * @notice swap token if the amount of token0 or token1 is not enough
    * @param amount0_ uint256
    * @param amount1_ uint256
    * @param amount0Target_ uint256
    * @param amount1Target_ uint256
    * @return amount0Out, amount1Out
    */
    function _swapToken(
        uint256 amount0_,
        uint256 amount1_,
        uint256 amount0Target_,
        uint256 amount1Target_
    ) internal returns (uint256, uint256) {
        if (amount0_ > amount0Target_) {
            // swap token0 to token1
            uint256 amount0Swap = amount0_ - amount0Target_;
            uint256 amount1Result = _swapExactInputSingle(
                token0,
                token1,
                amount0Swap,
                this_
            );
            uint256 amount1Out = amount1_ + amount1Result;
            return (amount0Target_, amount1Out);
        }

        if (amount1_ > amount1Target_) {
            // swap token1 to token0
            uint256 amount1Swap = amount1_ - amount1Target_;
            uint256 amount0Result = _swapExactInputSingle(
                token1,
                token0,
                amount1Swap,
                this_
            );
            uint256 amount0Out = amount0_ + amount0Result;
            return (amount0Out, amount1Target_);
        }

        // no need to swap
        return (amount0_, amount1_);
    }

    /**
    * @notice close the position, decrease liquidity if has liquidity and collect the fee
    * @param tokenId_ uint256
    * @param liquidity_ uint128
    */
    function _closePosition(uint256 tokenId_, uint128 liquidity_) internal returns (
        uint256 amount0,
        uint256 amount1,
        uint256 fee0,
        uint256 fee1
    ) {
        if (liquidity_ > 0) {
            // decrease liquidity if has liquidity
            (amount0, amount1) = positionManager.decreaseLiquidity(
            INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: tokenId_,
                liquidity: liquidity_,
                amount0Min: 0,
                amount1Min: 0,
                    deadline: block.timestamp + 15 minutes
                })
            );

            // after decrease liquidity, collect the amount + fee
            (uint256 amount0WithFee0, uint256 amount1WithFee1) = positionManager.collect(
                INonfungiblePositionManager.CollectParams({
                    tokenId: tokenId_,
                    recipient: this_,
                    amount0Max: type(uint128).max,
                    amount1Max: type(uint128).max
            }));
            fee0 = amount0WithFee0 - amount0;
            fee1 = amount1WithFee1 - amount1;
        }
    }

    /**
    * @notice harvest the position, close position if out of range, collect the fee if has liquidity and position in range
    * @param tokenId_ uint256
    */
    function _harvestPosition(uint256 tokenId_) internal returns (
        uint256 amount0,
        uint256 amount1,
        uint256 fee0,
        uint256 fee1
    ) {
        (,,,,,,,uint128 liquidity,,,,) = positionManager.positions(tokenId_);

        // out of range
        if (tokenId_ != farmingInfo.tokenId) {
            return _closePosition(tokenId_, liquidity);
        }

        // in range and has liquidity
        if (liquidity > 0) {
            // collect fee
            (fee0, fee1) = positionManager.collect(
                INonfungiblePositionManager.CollectParams({
                    tokenId: tokenId_,
                    recipient: this_,
                    amount0Max: type(uint128).max,
                    amount1Max: type(uint128).max
            }));
            return (amount0, amount1, fee0, fee1);
        } 
        // no liquidity, no need to harvest
        return (0, 0, 0, 0);
    }

    function _cutServiceFee(uint256 totalFees0_, uint256 totalFees1_) internal {
        uint256 serviceFee0 = totalFees0_ * serviceFeeFactor / 1e18;
        uint256 serviceFee1 = totalFees1_ * serviceFeeFactor / 1e18;

        if (serviceFee0 > 0) {
            doTransferOut(token0, receiver, serviceFee0);
        }

        if (serviceFee1 > 0) {
            doTransferOut(token1, receiver, serviceFee1);
        }

        emit CutServiceFee(serviceFee0, serviceFee1);
    }

    /**
    * @notice harvest all positions
    */
    function _harvest() internal {
        uint256 totalAmount0;
        uint256 totalAmount1;
        uint256 totalFees0;
        uint256 totalFees1;

        uint256 balance = getPositionBalance();
        for (uint256 i = 0; i < balance; i++) {
            uint256 tokenId = IERC721Enumerable(address(positionManager)).tokenOfOwnerByIndex(this_, i);
            // harvest
            (
                uint256 amount0,
                uint256 amount1,
                uint256 fee0,
                uint256 fee1
            ) = _harvestPosition(tokenId);

            totalAmount0 += amount0;
            totalAmount1 += amount1;
            totalFees0 += fee0;
            totalFees1 += fee1;
        }

        _updateHarvestInfoWhenHarvest(totalFees0, totalFees1);
        _cutServiceFee(totalFees0, totalFees1);
        emit Harvest(totalAmount0, totalAmount1, totalFees0, totalFees1);
    }

    /**
    * @notice rebalance the token0 and token1 balance
    * @return token0Balance, token1Balance
    */
    function _rebalanceToken() internal returns (uint256, uint256) {
        uint256 token0Balance = IERC20(token0).balanceOf(this_);
        uint256 token1Balance = IERC20(token1).balanceOf(this_);
        
        uint256 positionValueInToken0 = _getValueInToken0(token0Balance, token1Balance);  // 1e18
        (uint256 amount0Target, uint256 amount1Target) = getAmountByBestLiquidity(
            positionValueInToken0,
            farmingSlot0.tick,
            farmingInfo.tickLower,
            farmingInfo.tickUpper
        );
      
        (uint256 amount0Out, uint256 amount1Out) = _swapToken(token0Balance, token1Balance, amount0Target, amount1Target);
        emit ReBalanceToken(amount0Out, amount1Out);
        
        return (IERC20(token0).balanceOf(this_), IERC20(token1).balanceOf(this_));
    }

    /**
    * @notice reinvest the token, rebalance the token0 and token1 balance, increase liquidity if has position, snapshot the position info
    * @return liquidity, amount0, amount1
    */
    function _reinvest() internal returns (uint128, uint256, uint256) {
        if (farmingInfo.hasOutOfAllTicks) {
            return (0, 0, 0);
        }

        (uint256 nowToken0Balance, uint256 nowToken1Balance) = _rebalanceToken();

        // increase liquidity
        (uint128 liquidity, uint256 amount0, uint256 amount1) = positionManager.increaseLiquidity(
            INonfungiblePositionManager.IncreaseLiquidityParams({
                tokenId: farmingInfo.tokenId,
                amount0Desired: nowToken0Balance,
                amount1Desired: nowToken1Balance,
                amount0Min: getAmountAfterSlippage(nowToken0Balance, slippage),
                amount1Min: getAmountAfterSlippage(nowToken1Balance, slippage),
                deadline: block.timestamp + 15 minutes
            })
        );
       
        _updateHarvestInfoWhenInvest(farmingInfo.tokenId);
        emit Reinvest(farmingInfo.tokenId, liquidity, amount0, amount1);
        return (liquidity, amount0, amount1);
    }

    /// @inheritdoc IFluxFarmV2
    function setSlippage(uint256 slippage_) external onlyRole(MANAGER) {
        require(slippage_ <= 1e18, "INVALID_SLIPPAGE");
        slippage = slippage_;
    }

    /// @inheritdoc IFluxFarmV2
    function setserviceFeeFactor(uint256 serviceFeeFactor_) external onlyRole(MANAGER) {
        require(serviceFeeFactor_ <= 1e18, "INVALID_SERVICE_FEE_SLIPPAGE");
        serviceFeeFactor = serviceFeeFactor_;
    }

    /// @inheritdoc IFluxFarmV2
    function setReceiver(address receiver_) external onlyRole(SAFE_ADMIN) {
        receiver = receiver_;
    }

    /// @inheritdoc IFluxFarmV2
    function setUpdateInterval(uint256 updateInterval_) external onlyRole(MANAGER) {
        require(updateInterval_ >= 15 minutes, "INVALID_INTERVAL");
        updateInterval = updateInterval_;
    }

    /// @inheritdoc IFluxFarmV2
    function reinvestFromBalance() external onlyRole(MANAGER) returns (uint128, uint256, uint256) {
        if (farmingInfo.hasOutOfAllTicks) {
            return (0, 0, 0);
        }

        (uint256 nowToken0Balance, uint256 nowToken1Balance) = _rebalanceToken();

        // increase liquidity
        (uint128 liquidity, uint256 amount0, uint256 amount1) = positionManager.increaseLiquidity(
            INonfungiblePositionManager.IncreaseLiquidityParams({
                tokenId: farmingInfo.tokenId,
                amount0Desired: nowToken0Balance,
                amount1Desired: nowToken1Balance,
                amount0Min: getAmountAfterSlippage(nowToken0Balance, slippage),
                amount1Min: getAmountAfterSlippage(nowToken1Balance, slippage),
                deadline: block.timestamp + 15 minutes
            })
        );
       
       (,,,,,,,uint128 _liquidity,,,,) = positionManager.positions(farmingInfo.tokenId);
        harvestInfo[latestInvestID].liquidity = _liquidity;
        emit Reinvest(farmingInfo.tokenId, liquidity, amount0, amount1);
        return (liquidity, amount0, amount1);
    }

    /// @inheritdoc IFluxFarmV2
    function claimTokens(address token_, address to_, uint256 amount_) external onlyRole(SAFE_ADMIN) {
        require(to_ == receiver, "INVALID_RECEIVER");
        if (token_ == address(0)) {
            safeTransferETH(receiver, amount_);
        } else {
            doTransferOut(token_, receiver, amount_);
        }
    }

    /// @inheritdoc IFluxFarmV2
    function initialPosition(
        int24[][] memory ticks_,
        uint256 onePositionValueInToken0_
    ) external onlyRole(MANAGER) returns (uint256) {
        _updatePoolState();
        _updatePrice();

        // trans to 1e18
        uint256 _onePositionValueInToken0 = onePositionValueInToken0_ * 1e18 / (10 ** tokenInfo[token0].decimals);

        uint256 balanceBefore = getPositionBalance();
        require(balanceBefore == 0, "ALREADY_INITIAL_POSITION");

        for (uint256 i = 0; i < ticks_.length; i++) {
            int24 tickLower = ticks_[i][0];
            int24 tickUpper = ticks_[i][1];
            (uint256 token0Amount, uint256 token1Amount) = getAmountByBestLiquidity(
                _onePositionValueInToken0,
                farmingSlot0.tick,
                tickLower,
                tickUpper
            );

            positionManager.mint(INonfungiblePositionManager.MintParams({
                token0: token0,
                token1: token1,
                fee: fee,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: token0Amount,
                amount1Desired: token1Amount,
                amount0Min: getAmountAfterSlippage(token0Amount, slippage),
                amount1Min: getAmountAfterSlippage(token1Amount, slippage),
                recipient: this_,
                deadline: block.timestamp + 15 minutes
            }));            
        }

        // check balances
        uint256 balanceAfter = getPositionBalance();
        require(balanceAfter - balanceBefore == ticks_.length, "INVALID_POSITION_COUNT");

        emit InitialPosition(ticks_.length);
        return ticks_.length;
    }

    /// @inheritdoc IFluxFarmV2
    function closeAllPosition(bool isBurn_) external onlyRole(MANAGER) returns (
        uint256 burnCount,
        uint256 totalAmount0,
        uint256 totalAmount1,
        uint256 totalFees0,
        uint256 totalFees1,
        uint256 nowBalanceToken0,
        uint256 nowBalanceToken1
    ) {
        uint256 balance = getPositionBalance();
        uint256[] memory tokenIds = new uint256[](balance);

        for (uint256 i = 0; i < balance; i++) {
            uint256 tokenId = IERC721Enumerable(address(positionManager)).tokenOfOwnerByIndex(this_, i);
            (,,,,,,,uint128 liquidity,,,,) = positionManager.positions(tokenId);
            (uint256 amount0, uint256 amount1, uint256 fee0, uint256 fee1) = _closePosition(tokenId, liquidity);
            totalAmount0 += amount0;
            totalAmount1 += amount1;
            totalFees0 += fee0;
            totalFees1 += fee1;
            
            tokenIds[i] = tokenId;  // prepare for burn
        }

        if (isBurn_) {
            for (uint256 i = 0; i < balance; i++) {
                positionManager.burn(tokenIds[i]);
                burnCount++;
            }
        }

        _updateHarvestInfoWhenHarvest(totalFees0, totalFees1);

        nowBalanceToken0 = IERC20(token0).balanceOf(this_);
        nowBalanceToken1 = IERC20(token1).balanceOf(this_);
        
        emit CloseAllPosition(
            totalAmount0,
            totalAmount1,
            totalFees0,
            totalFees1,
            nowBalanceToken0,
            nowBalanceToken1
        );
    }

    /// @inheritdoc IFluxFarmV2
    function invest(address token_, uint256 amount_) external onlyRole(MANAGER) returns (uint256) {
        require(amount_ > 0, "INVALID_AMOUNT");
        require(token_ == token0 || token_ == token1, "INVALID_TOKEN");
        uint256 amountReceived = doTransferIn(token_, msg.sender, amount_);  // transfer in
        uint256 tokenValue = getTokenValue(token_, amountReceived);
        uint256 newtotalInvest = totalInvest + tokenValue;
        require(newtotalInvest > totalInvest, "Amount Overflow");

        totalInvest = newtotalInvest;
        tokenInvest[token_] += amountReceived;
        emit Invest(token_, amountReceived, tokenValue, totalInvest);
        return tokenValue;
    }

    /// @inheritdoc IFluxFarmV2
    function withdraw(address token_, uint256 amount_) external onlyRole(SAFE_ADMIN) returns (uint256) {
        require(amount_ > 0, "INVALID_AMOUNT");
        require(token_ == token0 || token_ == token1, "INVALID_TOKEN");
        uint256 amountWithdraw = doTransferOut(token_, msg.sender, amount_);  // transfer out
        uint256 tokenValue = getTokenValue(token_, amountWithdraw);
        uint256 newtotalWithdraw = totalWithdraw + tokenValue;
        require(newtotalWithdraw > totalWithdraw, "Amount Overflow");

        totalWithdraw = newtotalWithdraw;
        tokenWithdraw[token_] += amountWithdraw;
        emit Withdraw(token_, amountWithdraw, tokenValue, totalWithdraw);
        return tokenValue;
    }

    /// @inheritdoc IFluxFarmV2
    function updateFarm() external renewFarm(false) onlyRole(MANAGER) returns (bool) {
        emit UpdateFarm(msg.sender, block.timestamp, block.number);
        return true;
    }

    /// @inheritdoc IFluxFarmV2
    function AutoUpdateFarm() public renewFarm(true) returns (bool) {
        emit UpdateFarm(msg.sender, block.timestamp, block.number);
        return true;
    }

    /// @inheritdoc AutomationCompatibleInterface
    function checkUpkeep(bytes calldata) external view override returns (
        bool upkeepNeeded,
        bytes memory performData
    ) {
        upkeepNeeded = updateFarmTrigger();
    }

    /// @inheritdoc AutomationCompatibleInterface
    function performUpkeep(bytes calldata performData) external override {
        require(updateFarmTrigger(), "No upkeep needed");
        AutoUpdateFarm();
    }
}