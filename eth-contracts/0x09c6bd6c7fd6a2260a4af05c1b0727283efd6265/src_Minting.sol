// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {GoatX} from "./src_GoatX.sol";
import {wmul, wpow} from "./src_utils_Math.sol";
import {Constants} from "./src_const_Constants.sol";
import {IFluxBuyAndBurn} from "./src_interfaces_IFluxBnB.sol";
import {IGoatXMinting} from "./src_interfaces_IGoatXMinting.sol";
import {IERC20} from "./lib_openzeppelin-contracts_contracts_interfaces_IERC20.sol";
import {SwapActions, SwapActionsState} from "./src_actions_SwapActions.sol";
import {TickMath} from "./lib_v3-core_contracts_libraries_TickMath.sol";
import {INonfungiblePositionManager} from "./lib_v3-periphery_contracts_interfaces_INonfungiblePositionManager.sol";

/**
 * @title GoatXMinting
 * @author Decentra
 */
contract GoatXMinting is SwapActions, IGoatXMinting {
    IERC20 public immutable titanX;
    GoatX immutable goatX;

    address immutable v3PositionManager;
    uint32 public immutable startTimestamp;

    LPPools internal lpPools;
    uint64 public lpSlippage = 0.8e18;

    uint96 depositId;

    uint256 public totalGoatXClaimed;
    uint256 public totalGoatXMinted;
    uint256 public totalSentToLp;

    mapping(uint8 cycle => uint256 goatXMinted) public titanXPerCycle;
    mapping(address user => mapping(uint96 depositId => Deposit)) public deposits;

    constructor(
        address _titanX,
        address _goatX,
        address _v3PositionManager,
        uint32 _startTimestamp,
        SwapActionsState memory _s
    )
        SwapActions(_s)
        notAddress0(_titanX)
        notAddress0(_v3PositionManager)
        notAddress0(_goatX)
        notAmount0(_startTimestamp)
    {
        require((_startTimestamp % 86400) == 50400, "_startTimestamp must be 2PM UTC");
        startTimestamp = _startTimestamp;
        v3PositionManager = _v3PositionManager;
        goatX = GoatX(_goatX);
        titanX = IERC20(_titanX);
    }

    //////////////////////////////
    /// PERMISSIONED FUNCTIONS ///
    //////////////////////////////

    ///@inheritdoc IGoatXMinting
    function changeLpSlippage(uint64 _newSlippage)
        external
        notAmount0(_newSlippage)
        notGt(_newSlippage, Constants.WAD)
        onlySlippageAdminOrOwner
    {
        lpSlippage = _newSlippage;
    }

    function addInitialLiquidity(uint32 _deadline) external onlyOwner notExpired(_deadline) {
        require(!lpPools.goatXTitanX.hasLP, LiquidityAlreadyAdded());
        require(
            titanX.balanceOf(address(this)) >= Constants.INITIAL_TITAN_X_FOR_TITANX_GOATX, NotEnoughTitanXForLiquidity()
        );

        goatX.toggleLP();

        goatX.mint(address(this), Constants.INITIAL_GOATX_FOR_LP);

        _addLiquidityToPool(
            address(goatX),
            address(titanX),
            Constants.INITIAL_GOATX_FOR_LP,
            Constants.INITIAL_TITAN_X_FOR_TITANX_GOATX,
            _deadline
        );

        _transferOwnership(address(0));
    }

    ///@inheritdoc IGoatXMinting
    function collectFees() external returns (uint256 goatXAmountTX, uint256 titanXAmount) {
        // Collect fees from GOATX/TITANX pool
        (goatXAmountTX, titanXAmount) = _collectFeesFromPool(lpPools.goatXTitanX);

        // BURN collected GOATX tokens
        uint256 totalGoatXAmount = goatXAmountTX;

        if (totalGoatXAmount > 0) goatX.burn(totalGoatXAmount);

        // Transfer collected TITANX tokens
        if (titanXAmount > 0) {
            titanX.transfer(Constants.LIQUIDITY_BONDING, titanXAmount);
        }
    }

    ///@inheritdoc IGoatXMinting
    function deposit(uint256 _amount) external {
        require(block.timestamp >= startTimestamp, NotStartedYet());

        titanX.transferFrom(msg.sender, address(this), _amount);

        (uint8 currentCycle,, uint32 endsAt) = getCurrentMintCycle();

        require(titanXPerCycle[currentCycle] + _amount <= Constants.MINTING_CAP_PER_CYCLE, ExceedingCycleCap());
        require(block.timestamp <= endsAt, CycleIsOver());

        _distribute(_amount);

        uint256 goatXAmount = wmul(_amount, getRatioForCycle(currentCycle));

        titanXPerCycle[currentCycle] += _amount;
        totalGoatXMinted += goatXAmount;

        deposits[msg.sender][++depositId] =
            Deposit({depositedAt: uint32(block.timestamp), titanXAmount: uint216(_amount), cycle: currentCycle});

        emit DepositExecuted(msg.sender, goatXAmount, depositId);
    }

    ///@inheritdoc IGoatXMinting
    function claim(uint96 _id) public {
        Deposit memory userDep = deposits[msg.sender][_id];
        require(userDep.depositedAt != 0, NothingToClaim());
        require(userDep.depositedAt + 24 hours < block.timestamp, DepositNotMatureYet());

        uint256 toClaim = claimableAmount(msg.sender, _id);

        delete deposits[msg.sender][_id];

        emit ClaimExecuted(msg.sender, toClaim, _id);

        totalGoatXClaimed += toClaim;

        goatX.mint(msg.sender, toClaim);
    }

    ///@inheritdoc IGoatXMinting
    function batchClaim(uint96[] calldata _ids) external {
        for (uint32 i; i < _ids.length; i++) {
            claim(_ids[i]);
        }
    }

    ///@inheritdoc IGoatXMinting
    function claimableAmount(address _user, uint96 _id) public view returns (uint256 claimable) {
        Deposit memory userDep = deposits[_user][_id];
        uint8 cycleOfDeposit = userDep.cycle;

        claimable = wmul(userDep.titanXAmount, getRatioForCycle(cycleOfDeposit));
    }

    ///@inheritdoc IGoatXMinting
    function getRatioForCycle(uint32 cycleId) public pure returns (uint256 ratio) {
        unchecked {
            ratio = Constants.MINTING_STARTING_RATIO - uint256(cycleId - 1) * 2e16;
        }
    }

    ///@inheritdoc IGoatXMinting
    function getCurrentMintCycle() public view returns (uint8 currentCycle, uint32 startsAt, uint32 endsAt) {
        (currentCycle, startsAt, endsAt) = _getCycleAt(uint32(block.timestamp));
    }

    function _getCycleAt(uint32 t) internal view returns (uint8 currentCycle, uint32 startsAt, uint32 endsAt) {
        uint32 timeElapsedSince = uint32(t - startTimestamp);

        currentCycle = uint8(timeElapsedSince / Constants.MINTING_CYCLE_GAP) + 1;

        if (currentCycle > Constants.MAX_MINT_CYCLE) {
            currentCycle = Constants.MAX_MINT_CYCLE;
        }

        startsAt = startTimestamp + ((currentCycle - 1) * Constants.MINTING_CYCLE_GAP);

        endsAt = startsAt + Constants.MINTING_CYCLE_DURATION;
    }

    //////////////////////////////
    ///// INTERNAL FUNCTIONS /////
    //////////////////////////////

    ///@notice Collects the fees from a pool
    function _collectFeesFromPool(LP memory _lp) internal returns (uint256 goatXAmount, uint256 otherAmount) {
        INonfungiblePositionManager.CollectParams memory params = INonfungiblePositionManager.CollectParams({
            tokenId: _lp.tokenId,
            recipient: address(this),
            amount0Max: type(uint128).max,
            amount1Max: type(uint128).max
        });

        (uint256 amount0, uint256 amount1) = INonfungiblePositionManager(v3PositionManager).collect(params);

        (goatXAmount, otherAmount) = _lp.isGoatXToken0 ? (amount0, amount1) : (amount1, amount0);
    }

    function _addLiquidityToPool(address token0, address token1, uint256 amount0, uint256 amount1, uint32 deadline)
        internal
    {
        (
            uint256 amount0Sorted,
            uint256 amount1Sorted,
            uint256 amount0Min,
            uint256 amount1Min,
            address sortedToken0,
            address sortedToken1
        ) = _sortAmounts(token0, token1, amount0, amount1);

        IERC20(sortedToken0).approve(address(v3PositionManager), amount0Sorted);
        IERC20(sortedToken1).approve(address(v3PositionManager), amount1Sorted);

        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
            token0: sortedToken0,
            token1: sortedToken1,
            fee: Constants.POOL_FEE,
            tickLower: (TickMath.MIN_TICK / Constants.TICK_SPACING) * Constants.TICK_SPACING,
            tickUpper: (TickMath.MAX_TICK / Constants.TICK_SPACING) * Constants.TICK_SPACING,
            amount0Desired: amount0Sorted,
            amount1Desired: amount1Sorted,
            amount0Min: amount0Min,
            amount1Min: amount1Min,
            recipient: address(this),
            deadline: deadline
        });

        (uint256 tokenId,,,) = INonfungiblePositionManager(v3PositionManager).mint(params);

        LP memory newLP = LP({hasLP: true, tokenId: uint240(tokenId), isGoatXToken0: sortedToken0 == address(goatX)});

        lpPools.goatXTitanX = newLP;
    }

    function _distribute(uint256 _amount) internal {
        uint256 titanXBalance = titanX.balanceOf(address(this));
        // @note - If there is no added liquidity, but the balance exceeds the initial for liquidity, we should distribute the difference
        if (!lpPools.goatXTitanX.hasLP) {
            if (titanXBalance <= Constants.INITIAL_TITAN_X_FOR_TITANX_GOATX) {
                return;
            }
            _amount = titanXBalance - Constants.INITIAL_TITAN_X_FOR_TITANX_GOATX;
        }

        if (totalSentToLp < Constants.INITIAL_TITANX_SENT_TO_LP) {
            uint256 amountLeft = Constants.INITIAL_TITANX_SENT_TO_LP - totalSentToLp;
            uint256 amountToAdd = amountLeft >= _amount ? _amount : amountLeft;
            totalSentToLp += amountToAdd;
            _amount -= amountToAdd;

            titanX.transfer(Constants.LP_WALLET, amountToAdd);
        }

        if (_amount == 0) return;

        titanX.transfer(address(goatX.buyAndBurn()), wmul(_amount, uint256(0.38e18)));

        {
            uint256 toAuctionBuy = wmul(_amount, uint256(0.3e18));
            titanX.approve(address(goatX.auctionBuy()), toAuctionBuy);
            goatX.auctionBuy().distribute(toAuctionBuy);
        }

        titanX.transfer(Constants.LIQUIDITY_BONDING, wmul(_amount, uint256(0.08e18)));
        titanX.transfer(Constants.PHOENIX_TITANX_STAKE, wmul(_amount, uint256(0.04e18)));
        titanX.transfer(Constants.POOL_AND_BURN, wmul(_amount, uint256(0.04e18)));
        titanX.transfer(Constants.INFERNO_BNB_V2, wmul(_amount, uint256(0.08e18)));
        titanX.transfer(Constants.GENESIS, wmul(_amount, uint256(0.02e18)));
        titanX.transfer(Constants.GENESIS_2, wmul(_amount, uint256(0.06e18)));
    }

    function _sortAmounts(address _tokenA, address _tokenB, uint256 _amountA, uint256 _amountB)
        internal
        view
        returns (
            uint256 amount0,
            uint256 amount1,
            uint256 amount0Min,
            uint256 amount1Min,
            address token0,
            address token1
        )
    {
        (token0, token1) = _tokenA < _tokenB ? (_tokenA, _tokenB) : (_tokenB, _tokenA);
        (amount0, amount1) = token0 == _tokenA ? (_amountA, _amountB) : (_amountB, _amountA);

        (amount0Min, amount1Min) = (wmul(amount0, lpSlippage), wmul(amount1, lpSlippage));
    }
}