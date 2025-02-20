// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./lib_openzeppelin-contracts_contracts_token_ERC20_IERC20.sol";
import "./lib_openzeppelin-contracts_contracts_token_ERC20_utils_SafeERC20.sol";
import "./lib_pancake-v3-contracts_projects_v3-core_contracts_interfaces_IPancakeV3Pool.sol";
import "./src_interfaces_IWalletFactory.sol";
import "./src_interfaces_IERC677Receiver.sol";
import "./lib_openzeppelin-contracts_contracts_interfaces_IERC721.sol";
import "./lib_openzeppelin-contracts_contracts_interfaces_IERC721Receiver.sol";
import "./lib_v3-core_contracts_libraries_FullMath.sol";
import "./lib_utr_contracts_interfaces_IUniversalTokenRouter.sol";
import "./lib_utr_contracts_NotToken.sol";
import "./lib_forge-std_src_console.sol";

interface INonfungiblePositionManager {
    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }

    function mint(MintParams calldata params)
        external
        payable
        returns (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        );
}

/// @dev ISwapRouter for some reason the code on github of pancake is different with the code they're using 
/// the difference is the deadline field
interface ISwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
}
interface IGammaPositionManager {
    struct CreateLoanBorrowAndRebalanceParams {
        /// @dev protocolId of GammaPool (e.g. version of GammaPool)
        uint16 protocolId;
        /// @dev address of CFMM, along with protocolId can be used to calculate GammaPool address
        address cfmm;
        /// @dev owner of NFT created by PositionManager. Owns loan through PositionManager
        address to;
        /// @dev reference id of loan observer to track loan
        uint16 refId;
        /// @dev amounts of requesting to deposit as collateral for a loan or withdraw from a loan's collateral
        uint256[] amounts;
        /// @dev CFMM LP tokens requesting to borrow to short
        uint256 lpTokens;
        /// @dev Ratio to rebalance collateral to
        uint256[] ratio;
        /// @dev minimum amounts of reserve tokens expected to have been withdrawn representing the `lpTokens`. Slippage protection
        uint256[] minBorrowed;
        /// @dev minimum amounts of collateral expected to have after re-balancing collateral. Slippage protection
        uint128[] minCollateral;
        /// @dev timestamp after which the transaction expires. Used to prevent stale transactions from executing
        uint256 deadline;
        /// @dev max borrowed liquidity
        uint256 maxBorrowed;
    }

    struct CreateLoanBorrowAndRebalanceExternallyParams {
        /// @dev protocolId of GammaPool (e.g. version of GammaPool)
        uint16 protocolId;
        /// @dev address of CFMM, along with protocolId can be used to calculate GammaPool address
        address cfmm;
        /// @dev owner of NFT created by PositionManager. Owns loan through PositionManager
        address to;
        /// @dev reference id of loan observer to track loan
        uint16 refId;
        /// @dev amounts of requesting to deposit as collateral for a loan or withdraw from a loan's collateral
        uint256[] amounts;
        /// @dev CFMM LP tokens requesting to borrow to short
        uint256 lpTokens;
        /// @dev address of contract that will rebalance collateral. This address must return collateral back to GammaPool
        address rebalancer;
        /// @dev data - optional bytes parameter to pass data to the rebalancer contract with rebalancing instructions
        bytes data;
        /// @dev minimum amounts of reserve tokens expected to have been withdrawn representing the `lpTokens`. Slippage protection
        uint256[] minBorrowed;
        /// @dev minimum amounts of collateral expected to have after re-balancing collateral. Slippage protection
        uint128[] minCollateral;
        /// @dev timestamp after which the transaction expires. Used to prevent stale transactions from executing
        uint256 deadline;
        /// @dev max borrowed liquidity
        uint256 maxBorrowed;
    }

    function token0() external returns (address);
    function token1() external returns (address);

    /// @dev See {IPositionManager-createLoanBorrowAndRebalance}.
    function createLoanBorrowAndRebalance(CreateLoanBorrowAndRebalanceParams calldata params) external returns(uint256 tokenId, uint128[] memory tokensHeld, uint256 liquidityBorrowed, uint256[] memory amounts) ;
    
    function createLoanBorrowAndRebalanceExternally(CreateLoanBorrowAndRebalanceExternallyParams calldata params) external returns(uint256 tokenId, uint128[] memory tokensHeld, uint256 liquidityBorrowed, uint256[] memory amounts);
}

interface IGammaCFMM {
    function token0() external returns (address);
    function token1() external returns (address);
}
interface IERC20WithDecimals is IERC20{
    function decimals() external view returns (uint8);
}

contract PancakeV3GammaZapper is IERC721Receiver, NotToken {
    using SafeERC20 for IERC20;

    uint256 constant Q96 = 2**96;
    address public immutable VEMO_WALLET_FACTORY;
    
    event GammaZapCreated(
        address indexed creator,
        address indexed tba,
        address v3pool,
        address cfmm,
        uint256 v3NFT,
        uint256[] collaterals,
        INonfungiblePositionManager v3NonfungiblePositionManager
    );
     
    /**
     * Supports only a single asset.
     * token must correspond to either token0 or token1 of the V3 pool and Gamma CFMM.
     */
    struct ZapParams {
        address payer;
        address token;
        uint256 amount;
        address v3pool;
        address gammaCFMM;
        address nftCollectionAddress;
        IGammaPositionManager nonfungiblePositionManagerGamma;
        ISwapRouter v3SwapRouter;
        INonfungiblePositionManager v3NonfungiblePositionManager;
        uint256[] gammaCollateralAmounts;  
        uint256 gammaBorrowedLP;
        int24 tickLower;
        int24 tickUpper;
        uint256 slippage;         // e.g., 50 = 0.5%
        address gammaRebalancer;
        address receiver;
        uint256 deadline;
        bool newTBA;
        bytes gammaRebalanceData;
    }

    struct RebalanceData {
        address[] tokens;
        int256[] deltas;
        uint256[] amountsLimit;
        uint24 poolFee;
        uint160 sqrtPriceLimit;
        uint256 deadline;
        uint256 tokenId;
        bytes path;
    }

    address public token0;
    address public token1;

    error InvalidAddress();
    error InvalidTokenPairs();
    error InvalidAmount();
    error InvalidV3Range();

    constructor(
        address _walletFactory
    ) {
        if (
            _walletFactory == address(0)
        ) revert InvalidAddress();

        VEMO_WALLET_FACTORY = _walletFactory;
    }

    function _getV3Price(address pool) internal returns(uint160 sqrtPriceX96) {
         (bool success, bytes memory data) = pool.staticcall(
            abi.encodeWithSignature("slot0()")
        );
        require(success, "slot0 call failed");
        
        // Parse the first uint160 from the returned data
        assembly {
            sqrtPriceX96 := mload(add(data, 32))
        }

        console.log("sqrtPriceX96 ", sqrtPriceX96);
    }

    /**
     * @dev the swapAmount just works with single asset only
     */
    function _rebalanceTokensForV3(ZapParams calldata params) internal returns (uint256, uint256) {
        /// @notice sqrtPriceX96 is the price of token1 over token0
        /// @param sqrtPriceX96  Get current price from pool token0/token1
        ///  1419758224450087408892346487537664 ~ 321596784 USDC/ETH
        /// ~ 321596784 * 10e6 / 10e18 = 0.000321596784USDC/ETH ~ 1 / 0.000321596784 = 3109 ETH/USDC

        // slot0 may revert in somecase if the v3 vender changes some compare to the original one ie pancake
        (uint160 sqrtPriceX96,,,,,,) = IPancakeV3Pool(params.v3pool).slot0();

        uint256 amount0 = 0;
        uint256 amount1 = 0;
        if (params.token == IPancakeV3Pool(params.v3pool).token0()) {
            amount0 = params.amount;
        } else {
            amount1 = params.amount;
        }
        uint256 priceX96 = FullMath.mulDiv(
            uint256(sqrtPriceX96),
            uint256(sqrtPriceX96),
            1 << 96
        );
        uint256 token1ValueOverToken0 = FullMath.mulDiv(
            amount1,
            Q96,
            priceX96
        );
        uint256 totalInputValueX96 = amount0  + token1ValueOverToken0;
        // v0 is 1/2 total value - slippage
        uint256 v0 = totalInputValueX96 * 10000/ ( 20000 - params.slippage);
        // uint256 v0 = totalInputValueX96 / 2;
        uint256 needSwapAmount;
        uint256 expectedSwapOutputAmount;
        
        // need swap token1 to token0
        if (amount0 == 0) {
            needSwapAmount = FullMath.mulDiv(
                v0,
                priceX96,
                Q96
            );
            expectedSwapOutputAmount = totalInputValueX96 - v0;
            
            if (needSwapAmount > 0){
                _executeSwap(
                    token1,
                    token0,
                    params.v3SwapRouter,
                    IPancakeV3Pool(params.v3pool),
                    needSwapAmount,
                    expectedSwapOutputAmount
                );
            }
            return (IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)));
        }

        // need swap token0 to token1
        // multiply with 10 ** IERC20WithDecimals(params.token0).decimals()
        needSwapAmount = v0;
        expectedSwapOutputAmount = FullMath.mulDiv(
            totalInputValueX96 - v0,
            priceX96,
            Q96
        );

        if (needSwapAmount > 0) {
            _executeSwap(
                token0,
                token1,
                params.v3SwapRouter,
                IPancakeV3Pool(params.v3pool),
                needSwapAmount,
                expectedSwapOutputAmount
            );

            return (IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)));
        }
    }

    function _validateZap(ZapParams calldata params) internal {
        token0 = IPancakeV3Pool(params.v3pool).token0();
        token1 = IPancakeV3Pool(params.v3pool).token1();

        // (,int24 tick,,,,,) = IPancakeV3Pool(params.v3pool).slot0();

        address cfmmToken0 = IGammaCFMM(params.gammaCFMM).token0();
        address cfmmToken1 = IGammaCFMM(params.gammaCFMM).token1();

        {
            if (params.token != token0 && params.token != token1) {
                revert InvalidTokenPairs();
            }

            if (params.amount == 0) {
                revert InvalidAmount();
            }

            // if (params.tickLower > tick || params.tickUpper < tick) {
            //     revert InvalidV3Range();
            // }
        }

        {
            // verify cfmm vs univ3
            if (
                (token0 != cfmmToken0 && token1 != cfmmToken1) &&
                (token0 != cfmmToken1 && token1 != cfmmToken0)
            ) {
                revert InvalidTokenPairs();
            }
        }
    }

    function zap(ZapParams calldata params) external returns (
        uint256 tokenId,
        address tba
    ) {
        _validateZap(params);

        // TODO Transfer all needed tokens to contract 
        if (params.amount > 0) {
            // IERC20(params.token).safeTransferFrom(msg.sender, address(this), params.amount);
            _pay(params.token, params.payer, address(this), params.amount);
        }

        (uint256 amount0, uint256 amount1) = _rebalanceTokensForV3(params);

        if (params.newTBA) {
            (tokenId, tba) = IWalletFactory(VEMO_WALLET_FACTORY).create(params.nftCollectionAddress);
        } else {
            tba = params.receiver;
        }

        (uint256 v3TokenId,,) = _addUniV3Liquidity(params.v3NonfungiblePositionManager, INonfungiblePositionManager.MintParams({
            token0: token0,
            token1: token1,
            fee: IPancakeV3Pool(params.v3pool).fee(),
            tickLower: params.tickLower,
            tickUpper: params.tickUpper,
            amount0Desired: amount0,
            amount1Desired: amount1,
            amount0Min: 0,
            amount1Min: 0,
            recipient: tba,
            deadline: params.deadline
        }));
        _addGammaLongShort(params, tba);

        // transfer vemo tokenId back to receiver if needed
        if (tba != params.receiver) {
            IERC721(params.nftCollectionAddress).safeTransferFrom(address(this), params.receiver, tokenId);
        }

        emit GammaZapCreated({
            creator: msg.sender,
            tba: tba,
            v3pool: params.v3pool,
            cfmm: params.gammaCFMM,
            v3NFT: v3TokenId,
            v3NonfungiblePositionManager: params.v3NonfungiblePositionManager,
            collaterals: params.gammaCollateralAmounts
        });
    }

    function _pay(
        address token,
        address payer,
        address recipient,
        uint256 value
    ) internal {
        bytes memory payload = abi.encode(payer, recipient, 20, token, 0);
        IUniversalTokenRouter(msg.sender).pay(payload, value);
    }

    function _addGammaPerpPosition(ZapParams calldata params, address receiver) internal{
        uint256[] memory ratio;
        uint256[] memory minBorrowed;
        uint128[] memory minCollateral;

        for (uint i = 0; i < params.gammaCollateralAmounts.length; i++) {
            address _token = i == 0 ? IGammaCFMM(params.gammaCFMM).token0() : IGammaCFMM(params.gammaCFMM).token1();
            if (params.gammaCollateralAmounts[i] > 0 ) {
                
                // TODO merge with the transfer amount0 to avoid duplicated transfer 
                IERC20(_token)
                    .safeTransferFrom(msg.sender, address(this), params.gammaCollateralAmounts[i]);
                IERC20(_token)
                    .approve(address(params.nonfungiblePositionManagerGamma), params.gammaCollateralAmounts[i]);
            }
        }

        IGammaPositionManager(params.nonfungiblePositionManagerGamma).createLoanBorrowAndRebalance(
            IGammaPositionManager.CreateLoanBorrowAndRebalanceParams({
                protocolId: 3,
                cfmm: params.gammaCFMM,
                to: receiver,
                refId: 0,
                amounts: params.gammaCollateralAmounts,
                lpTokens: params.gammaBorrowedLP,
                ratio: ratio,
                minBorrowed: minBorrowed,
                minCollateral: minCollateral,
                deadline: params.deadline,
                maxBorrowed: params.gammaBorrowedLP * 120/100 // 1.2 times
            })
        );
    }

    function _addGammaLongShort(ZapParams calldata params, address receiver) internal{
        uint256[] memory minBorrowed;
        uint128[] memory minCollateral;

        for (uint i = 0; i < params.gammaCollateralAmounts.length; i++) {
            address _token = i == 0 ? IGammaCFMM(params.gammaCFMM).token0() : IGammaCFMM(params.gammaCFMM).token1();
            if (params.gammaCollateralAmounts[i] > 0 ) {
                
                // TODO merge with the transfer amount0 to avoid duplicated transfer 
                // IERC20(_token)
                //     .safeTransferFrom(msg.sender, address(this), params.gammaCollateralAmounts[i]);
                _pay(_token, params.payer, address(this), params.gammaCollateralAmounts[i]);
                IERC20(_token)
                    .approve(address(params.nonfungiblePositionManagerGamma), params.gammaCollateralAmounts[i]);
            }
        }

        IGammaPositionManager(params.nonfungiblePositionManagerGamma).createLoanBorrowAndRebalanceExternally(
            IGammaPositionManager.CreateLoanBorrowAndRebalanceExternallyParams({
                protocolId: 3,
                cfmm: params.gammaCFMM,
                to: receiver,
                refId: 0,
                amounts: params.gammaCollateralAmounts,
                lpTokens: params.gammaBorrowedLP,
                data: params.gammaRebalanceData,
                rebalancer: params.gammaRebalancer,
                minBorrowed: minBorrowed,
                minCollateral: minCollateral,
                deadline: params.deadline,
                maxBorrowed: params.gammaBorrowedLP * 120/100 // 1.2 times
            })
        );
    }

    function _addUniV3Liquidity(INonfungiblePositionManager positionManager, INonfungiblePositionManager.MintParams memory params) 
        internal returns(uint256 tokenId, uint256 amount0, uint256 amount1)
    {
        // Approve tokens to position manager
        IERC20(params.token0).approve(address(positionManager), params.amount0Desired);
        IERC20(params.token1).approve(address(positionManager), params.amount1Desired);

        (tokenId,, amount0, amount1) = positionManager.mint(params);
        
        // refund
        if (amount0 < params.amount0Desired) {
            IERC20(params.token0).approve(address(positionManager), 0);
            IERC20(params.token0).transfer(msg.sender, params.amount0Desired - amount0);
        }

        if (amount1 < params.amount1Desired) {
            IERC20(params.token1).approve(address(positionManager), 0);
            IERC20(params.token1).transfer(msg.sender, params.amount1Desired - amount1);
        }
    }

    function _executeSwap(
        address _token0,
        address _token1,
        ISwapRouter v3SwapRouter,
        IPancakeV3Pool v3pool,
        uint256 inputAmount,
        uint256 expectedAmountOutput
    ) internal returns (uint256 amountOut) {
        require(IERC20(_token0).approve(address(v3SwapRouter), inputAmount), "Approve failed");
        
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: address(_token0),
                tokenOut: address(_token1),
                fee: v3pool.fee(),
                recipient: address(this),
                amountIn: inputAmount,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });
        // Record balances before swap for verification
        uint256 balanceBefore = IERC20(_token1).balanceOf(address(this));

        // Execute swap
        try v3SwapRouter.exactInputSingle(params) returns (uint256 amount) {
            amountOut = amount;
        } catch (bytes memory reason) {
            // Extract error message if possible
            revert(string(abi.encodePacked("SWAP_FAILED: ", reason)));
        }

        // Verify swap result
        uint256 balanceAfter = IERC20(_token1).balanceOf(address(this));
        require(
            balanceAfter >= balanceBefore + expectedAmountOutput,
            "INSUFFICIENT_OUTPUT_AMOUNT"
        );
    }

    function onERC721Received(address, address, uint256, bytes calldata) public pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

}