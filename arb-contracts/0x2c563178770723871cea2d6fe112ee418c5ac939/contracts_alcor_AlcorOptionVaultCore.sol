// SPDX-License-Identifier: None
pragma solidity ^0.8.18;

import {ISwapRouter} from "./contracts_interfaces_ISwapRouter.sol";
import {IV3Pool} from "./contracts_interfaces_v3-pool_IV3Pool.sol";
import {IBaseAlcorOptionCore} from "./contracts_interfaces_IBaseAlcorOptionCore.sol";
import {EnumerableSet} from "./openzeppelin_contracts_utils_structs_EnumerableSet.sol";

import {LiquidityAmounts} from "./contracts_libraries_LiquidityAmounts.sol";
import {TickMath} from "./contracts_libraries_TickMath.sol";
import {FullMath} from "./contracts_libraries_FullMath.sol";
import {SimpleMath} from "./contracts_libraries_SimpleMath.sol";
import {VaultUtils} from "./contracts_libraries_VaultUtils.sol";

import {VanillaOptionPool} from "./contracts_libraries_combo-pools_VanillaOptionPool.sol";
import {LPPosition} from "./contracts_libraries_LPPosition.sol";
import {OptionBalanceMath} from "./contracts_libraries_OptionBalanceMath.sol";


import {SafeERC20} from "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";
import {ERC20} from "./openzeppelin_contracts_token_ERC20_ERC20.sol";

abstract contract AlcorOptionVaultCore is IBaseAlcorOptionCore {
    using FullMath for uint256;
    using SafeERC20 for ERC20;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    using LPPosition for LPPosition.Key;
    // for getting info of the LP position
    using LPPosition for mapping(bytes32 => LPPosition.Info);
    // for getting the LP positions hashes or adding/removing LP position hash
    using LPPosition for mapping(address owner => mapping(bytes32 optionPoolKeyHash => EnumerableSet.Bytes32Set));
    using LPPosition for mapping(bytes32 lpPositionHash => LPPosition.PositionTicks);
    // for getting and updating options balances
    using VanillaOptionPool for mapping(address owner => mapping(bytes32 optionPoolKeyHash => int256));
    // for getting info of the option pool
    using VanillaOptionPool for VanillaOptionPool.Key;
    //
    using OptionBalanceMath for mapping(address owner => mapping(bytes32 optionPoolKeyHash => int256));

    modifier onlyApprovedManager() {
        if (!v3Pool.approvedManager(msg.sender)) revert notPositionManager();
        _;
    }

    modifier nonEmptyArray(uint256 arrayLength) { 
        if(arrayLength == 0) revert emptyArray();
        _;
    }

    address public protocolOwner;
    address public immutable token;
    IV3Pool public immutable v3Pool;
    ISwapRouter public immutable uniswapRouter;

    uint256 public minAmountForMint;
    uint128 minLiquidationAmount;
    uint256 liquidationFeeShare;


    mapping(address owner => mapping(bytes32 optionPoolKeyHash => EnumerableSet.Bytes32Set))
        internal userLPpositionsKeyHashes;

    mapping(bytes32 lpPositionKeyHash => LPPosition.Key)
        public LPpositionKeys;

    mapping(bytes32 lpPositionKeyHash => LPPosition.Info)
        public LPpositionInfos;

    mapping(bytes32 lpPositionHash => LPPosition.PositionTicks) 
        public lpPositionsTicksInfos;
    
    mapping(bytes32 optionPoolKeyHash => EnumerableSet.Bytes32Set)
        private LPpositionsInPoolHashes;

    constructor(
        address _V3Pool,
        address _uniswapRouter,
        address owner,
        uint256 _minAmountForMint,
        uint128 _minLiquidationAmount,
        uint256 _liquidationFeeShare
    ) {
        v3Pool = IV3Pool(_V3Pool);
        token = v3Pool.token();

        uniswapRouter = ISwapRouter(_uniswapRouter);

        protocolOwner = owner;
        minAmountForMint = _minAmountForMint;
        minLiquidationAmount = _minLiquidationAmount;
        liquidationFeeShare = _liquidationFeeShare;
    }
    
    struct UpdatePosInfo{ 
       address owner;
       int24 tickLower;
       int24 tickUpper;
       uint128 liquidity;
       uint256 deposit_amount0;
       uint256 deposit_amount1;     
    }

    function getAllLPPositionsInPool(
        VanillaOptionPool.Key memory optionPoolKey,
        uint128 n,
        uint128 m
    ) external view returns(UpdatePosInfo[] memory positions) {
        bytes32[] memory lpPositionsHashInPool = LPpositionsInPoolHashes[optionPoolKey.hashOptionPool()].values();

        uint256 length = m > lpPositionsHashInPool.length ? lpPositionsHashInPool.length : m;

        positions = new UpdatePosInfo[](length - n); 
        
        for(uint256 i = n; i < length; i++){
            bytes32 lpPositionHash = lpPositionsHashInPool[i];

            LPPosition.Key memory lpPositionKey = LPpositionKeys[lpPositionHash];
            LPPosition.Info memory lpPositionInfo = LPpositionInfos[lpPositionHash];

            positions[i-n] = UpdatePosInfo({
                owner: lpPositionKey.owner,
                tickLower: lpPositionKey.tickLower,
                tickUpper: lpPositionKey.tickUpper,
                liquidity: lpPositionInfo.liquidity,
                deposit_amount0: lpPositionInfo.deposit_amount0,
                deposit_amount1: lpPositionInfo.deposit_amount1
            });
        }
    }

    struct UserLLPositionInfoExpanded {
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
        uint256 deposit_amount0;
        uint256 deposit_amount1;
    }

    ///// used by front-end
    function getUserLPPositionsInfos(
        address owner,
        VanillaOptionPool.Key memory optionPoolKey
    )
        external
        view
        returns (UserLLPositionInfoExpanded[] memory userLPPositionsExpanded)
    {
        bytes32[] memory positionsKeys = userLPpositionsKeyHashes.getValues(
            owner,
            optionPoolKey
        );
        userLPPositionsExpanded = new UserLLPositionInfoExpanded[](
            positionsKeys.length
        );

        LPPosition.Info memory lpPositionInfo;
        for (uint i = 0; i < positionsKeys.length; i++) {
            lpPositionInfo = LPpositionInfos[positionsKeys[i]];
            userLPPositionsExpanded[i] = UserLLPositionInfoExpanded({
                tickLower: lpPositionsTicksInfos[positionsKeys[i]].tickLower,
                tickUpper: lpPositionsTicksInfos[positionsKeys[i]].tickUpper,
                liquidity: lpPositionInfo.liquidity,
                deposit_amount0: lpPositionInfo.deposit_amount0,
                deposit_amount1: lpPositionInfo.deposit_amount1
            });
        }
        return userLPPositionsExpanded;
    }

    function changeProtocolSettings(ProtocolSettings memory protocolSettings) external onlyApprovedManager { 
        if(protocolSettings.isUpdateMinAmountForMint)
        {
            minAmountForMint = protocolSettings.newMinAmountForMint;
            emit UpdateMinAmountForMint(protocolSettings.newMinAmountForMint);
        }
        if(protocolSettings.isUpdateMinLiquidationAmount)
        {
            minLiquidationAmount = protocolSettings.newMinLiquidationAmount;
            emit UpdateMinLiquidationAmount(protocolSettings.newMinLiquidationAmount);

        }
        if(protocolSettings.isUpdateLiquidationFeeShare)
        {
            liquidationFeeShare = protocolSettings.newLiquidityFeeShare;
            emit UpdateLiquidationFeeShare(protocolSettings.newLiquidityFeeShare);
        }
    }

    // @dev mints or burns user's entire position
    // @dev liquidity > 0 if mint position, liquidity < 0 otherwise
    function _modifyPosition(
        LPPosition.Key memory lpPositionKey,
        int128 liquidity,
        uint256 amount0Delta,
        uint256 amount1Delta
    ) private {
        LPPosition.Info storage _position = LPpositionInfos.get(lpPositionKey);
        if (liquidity < 0 && (_position.liquidity != uint128(-liquidity)))
            revert notEntireBurn();
        if (liquidity > 0 && (_position.liquidity > 0)) revert alreadyMinted();

        // change deposit amounts

        // case of mint
        if (liquidity > 0) {
            LPpositionInfos.create(
                lpPositionKey,
                uint128(liquidity),
                amount0Delta,
                amount1Delta
            );
            userLPpositionsKeyHashes.addPos(lpPositionKey);
            LPpositionsInPoolHashes[lpPositionKey.hashOptionPool()].add(lpPositionKey.hashPositionKey());
            lpPositionsTicksInfos.updateTicksInfos(lpPositionKey);
            LPpositionKeys[lpPositionKey.hashPositionKey()] = lpPositionKey;
        }
        // case of burn
        else {
            // clear the LP position
            LPpositionInfos.clear(lpPositionKey);

            LPpositionsInPoolHashes[lpPositionKey.hashOptionPool()].remove(lpPositionKey.hashPositionKey());
            userLPpositionsKeyHashes.removePos(lpPositionKey);
            lpPositionsTicksInfos.clearTicksInfos(lpPositionKey);
            delete LPpositionKeys[lpPositionKey.hashPositionKey()];
        }
    }

   
    // @dev this function allows to provide liquidity to the option pool
    // @param address of position owner
    // @param tickLower is the lower tick of option price range
    // @param tickUpper is the upper tick of option price range
    // @param amount is amount of liquidity in terms of uniswap v3
    function _mintLP(
        LPPosition.Key memory lpPositionKey,
        uint128 amount
    ) internal returns (uint256 amount0Delta, uint256 amount1Delta) {
        if (amount == 0) revert ZeroLiquidity();

        bytes32 optionPoolKeyHash = lpPositionKey.hashOptionPool();

        if (
            v3Pool.checkPositionLiquidity(
                optionPoolKeyHash,
                lpPositionKey.owner,
                lpPositionKey.tickLower,
                lpPositionKey.tickUpper
            )
        ) revert alreadyMinted();

        // amount0, amount1 are amounts deltas
        (amount0Delta, amount1Delta) = v3Pool.mint(
            lpPositionKey.owner,
            optionPoolKeyHash,
            lpPositionKey.tickLower,
            lpPositionKey.tickUpper,
            amount,
            abi.encode()
        );
       
        // we do not need the return amount of _modifyPosition because it's mintLP
        _modifyPosition(
            lpPositionKey,
            int128(amount),
            amount0Delta,
            amount1Delta
        );
        
        v3Pool.updatePoolBalances(
            lpPositionKey.hashOptionPool(),
            int256(amount0Delta),
            int256(amount1Delta)
        );

        emit AlcorMint(
            lpPositionKey.owner,
            amount0Delta,
            amount1Delta
        );
    }

    struct BurnInfo {
        uint256 amount0ToTransfer;
        uint256 amount1ToTransfer;
        uint256 amount1Burned;
        uint256 amount1Minted;
    }
    // @dev this function burns the option LP position
    // @dev we don't need whenNotExpired modifier here as user should be able to burn at any time
    // @param address of position owner
    // @param tickLower is the lower tick of option price range
    // @param tickUpper is the upper tick of option price range
    // @param amount is amount of liquidity in terms of uniswap v3
    function _burnLP(
        mapping(address => mapping(bytes32 => int256)) storage usersBalances,
        LPPosition.Key memory lpPositionKey,
        bool isUpdateLPPos
    ) internal returns (uint256, uint256) {
        BurnInfo memory burnInfo;

        LPPosition.Info memory _position = LPpositionInfos.get(lpPositionKey);
        if (_position.liquidity == 0) revert ZeroLiquidity();

        burnInfo.amount1Minted = _position.deposit_amount1;
        (uint128 numberOfPool, bytes32[] memory optionPoolHashes) = v3Pool
            .getOptionPoolHashes(lpPositionKey.hashOptionPool());

        for (
            uint128 i = numberOfPool;
            i <
            uint128(
                isUpdateLPPos
                    ? optionPoolHashes.length - 1
                    : optionPoolHashes.length
            );
            i++
        ) {
            (uint160 sqrtPriceX96, , ) = v3Pool.slots0(
                optionPoolHashes[i]
            );

            if (i == uint128(isUpdateLPPos ? optionPoolHashes.length - 1: optionPoolHashes.length) -1) 
            {
                (burnInfo.amount0ToTransfer, burnInfo.amount1Burned) = v3Pool
                    .burn(
                        lpPositionKey.owner,
                        optionPoolHashes[i],
                        lpPositionKey.tickLower,
                        lpPositionKey.tickUpper,
                        _position.liquidity
                    );

                burnInfo.amount1ToTransfer += SimpleMath.min(
                    burnInfo.amount1Minted,
                    burnInfo.amount1Burned
                );
            } else {
                (, burnInfo.amount1Burned) = LiquidityAmounts
                    .getAmountsForLiquidity(
                        sqrtPriceX96,
                        TickMath.getSqrtRatioAtTick(lpPositionKey.tickLower),
                        TickMath.getSqrtRatioAtTick(lpPositionKey.tickUpper),
                        _position.liquidity
                    );
            }
            if (int256(burnInfo.amount1Minted) - int256(burnInfo.amount1Burned) !=0 ) 
            {
                burnInfo.amount1ToTransfer += VaultUtils
                    .getCollateralAfterUpdateUserOptionBalance(
                        usersBalances.getOptionBalance(
                            lpPositionKey.owner,
                            optionPoolHashes[i]
                        ),
                        int256(burnInfo.amount1Minted) -
                            int256(burnInfo.amount1Burned)
                    );

                usersBalances.updateOptionBalance(
                    lpPositionKey.owner,
                    optionPoolHashes[i],
                    int256(burnInfo.amount1Burned) -
                        int256(burnInfo.amount1Minted)
                );
            }
            burnInfo.amount1Minted = SimpleMath.min(
                burnInfo.amount1Minted,
                burnInfo.amount1Burned
            );
        }

        v3Pool.collect(
            lpPositionKey.owner,
            lpPositionKey.hashOptionPool(),
            lpPositionKey.tickLower,
            lpPositionKey.tickUpper,
            uint128(burnInfo.amount0ToTransfer)+uint128(burnInfo.amount1Burned)
        );

        _modifyPosition(lpPositionKey, -int128(_position.liquidity), 0, 0);

        v3Pool.updatePoolBalances(
            lpPositionKey.hashOptionPool(),
            -int256(burnInfo.amount0ToTransfer),
            -int256(burnInfo.amount1ToTransfer)
        );

        emit AlcorBurn(
            lpPositionKey.owner,
            burnInfo.amount0ToTransfer,
            burnInfo.amount1ToTransfer
        );

        return (burnInfo.amount0ToTransfer, burnInfo.amount1ToTransfer);
    }

    // @dev this function collect fee for LP
    // @param address of position owner
    // @param tickLower is the lower tick of option price range
    // @param tickUpper is the upper tick of option price range
    function _collectFeesLP(
        LPPosition.Key memory lpPositionKey
    ) internal returns (uint128 amountToTransfer) {
        LPPosition.Info memory _position = LPpositionInfos.get(lpPositionKey);

        if (_position.liquidity > 0) {
            // update fees growth inside the position
            v3Pool.burn(
                lpPositionKey.owner,
                lpPositionKey.hashOptionPool(),
                lpPositionKey.tickLower,
                lpPositionKey.tickUpper,
                0
            );
        }

        // collect fees
        amountToTransfer = v3Pool.collect(
            lpPositionKey.owner,
            lpPositionKey.hashOptionPool(),
            lpPositionKey.tickLower,
            lpPositionKey.tickUpper,
            type(uint128).max
        );

        v3Pool.updatePoolBalances(
            lpPositionKey.hashOptionPool(),
            -int128(amountToTransfer/2),
            -int128(amountToTransfer/2)
        );

        emit AlcorCollect(
            lpPositionKey.owner,
            amountToTransfer
        );
    }
    
    function _withdraw(
        mapping(address => mapping(bytes32 => int256)) storage usersBalances,
        VanillaOptionPool.Key memory optionPoolKey,
        address owner
    ) internal returns (uint256 amount) {
        (uint128 numberOfPool, bytes32[] memory optionPoolHashes) = v3Pool
            .getOptionPoolHashes(optionPoolKey.hashOptionPool());
        for (uint128 i = numberOfPool; i < optionPoolHashes.length; i++) {
            bytes32 optionPoolKeyHash = optionPoolHashes[i];
            int256 userOptionBalance = usersBalances.getOptionBalance(
                owner,
                optionPoolKeyHash
            );

            if (userOptionBalance == 0) continue;

            optionPoolKey = v3Pool.getOptionPoolKeyStructs(optionPoolKeyHash);

            uint256 priceAtExpiry = v3Pool.pricesAtExpiries(
                optionPoolKey.expiry
            );
            if (priceAtExpiry == 0) continue;

            amount += VaultUtils.calculatePayoffAmount(
                userOptionBalance,
                optionPoolKey.strike,
                priceAtExpiry,
                ERC20(token).decimals()
            );
            usersBalances.updateOptionBalance(
                owner,
                optionPoolKeyHash,
                -userOptionBalance
            );
        }
        
        v3Pool.updatePoolBalances(
            optionPoolKey.hashOptionPool(),
            0,
            -int256(amount)
        );
        emit AlcorWithdraw(amount);
    }

    function _updateLPPosition(
        mapping(address => mapping(bytes32 => int256)) storage usersBalances,
        LPPosition.Key memory lpPositionKey,
        VanillaOptionPool.Key memory newOptionPoolKey
    ) internal returns(bool isUpdated){
        uint256 amount0Burned;
        uint256 amount1Burned;
        VanillaOptionPool.Key memory optionPoolKey = VanillaOptionPool.Key({
            expiry: lpPositionKey.expiry,
            strike: lpPositionKey.strike,
            isCall: lpPositionKey.isCall
        });

        (amount0Burned, amount1Burned) = _burnLP(
            usersBalances,
            lpPositionKey,
            true
        );

        amount1Burned += _withdraw(
            usersBalances,
            optionPoolKey,
            lpPositionKey.owner
        );

        (uint160 sqrtPriceX96, , ) = v3Pool.slots0(newOptionPoolKey.hashOptionPool());

        (uint128 liquidityToMint, uint256 totalAmountToMint) = VaultUtils.calculateLiquidityAmount(
                    TickMath.getSqrtRatioAtTick(lpPositionKey.tickLower),
                    TickMath.getSqrtRatioAtTick(lpPositionKey.tickUpper),
                    sqrtPriceX96,
                    amount0Burned + amount1Burned);


        if(totalAmountToMint < minAmountForMint){
            v3Pool.transferFromPool(
                token,
                lpPositionKey.owner,
                amount0Burned + amount1Burned
            );
        }
        else{
            (lpPositionKey.expiry, lpPositionKey.strike) = (
                newOptionPoolKey.expiry,
                newOptionPoolKey.strike
            );
            _mintLP(
                lpPositionKey,
                liquidityToMint
            );
            isUpdated = true;
        }
    }
}