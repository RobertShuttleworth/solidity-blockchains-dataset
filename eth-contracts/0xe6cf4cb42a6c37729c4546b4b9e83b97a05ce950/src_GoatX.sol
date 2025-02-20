// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {GoatXMinting} from "./src_Minting.sol";
import {AuctionBuy} from "./src_AuctionBuy.sol";
import {Constants} from "./src_const_Constants.sol";
import {GoatXBuyAndBurn} from "./src_BuyAndBurn.sol";
import {Math} from "./lib_openzeppelin-contracts_contracts_utils_math_Math.sol";
import {Ownable} from "./lib_openzeppelin-contracts_contracts_access_Ownable.sol";
import {ERC20} from "./lib_openzeppelin-contracts_contracts_token_ERC20_ERC20.sol";
import {FullMath} from "./lib_v3-core_contracts_libraries_FullMath.sol";
import {IQuoter} from "./lib_v3-periphery_contracts_interfaces_IQuoter.sol";
import {IUniswapV3Pool} from "./lib_v3-core_contracts_interfaces_IUniswapV3Pool.sol";
import {ERC20Burnable} from "./lib_openzeppelin-contracts_contracts_token_ERC20_extensions_ERC20Burnable.sol";
import {INonfungiblePositionManager} from "./lib_v3-periphery_contracts_interfaces_INonfungiblePositionManager.sol";

/**
 * @title GoatX
 * @author Decentra
 * @dev ERC20 token contract for GoatX tokens.
 * @notice It can be minted by GoatXMinting during cycles and when forming LP
 */
contract GoatX is ERC20Burnable, Ownable {
    using FullMath for uint256;

    address public immutable titanXGoatXPool;

    bool hasLp;

    GoatXMinting public minting;
    GoatXBuyAndBurn public buyAndBurn;
    address public goatFeed;
    AuctionBuy public auctionBuy;

    error OnlyMinting();
    error OnlyBuyAndBurn();
    error InvalidInput();

    /**
     * @dev Sets the minting and buy and burn contract address.
     * @param _titanX The titanX token
     * @param _v3PositionManager UniswapV3 position manager contract
     * @notice Constructor is payable to save gas
     */
    constructor(address _titanX, address _v3PositionManager) payable ERC20("GOATX", "GOATX") Ownable(msg.sender) {
        titanXGoatXPool = _createTitanXGoatXPool(_titanX, _v3PositionManager);
        _mint(msg.sender, 1_816_000_000_000e18);
        _mint(Constants.LP_WALLET, 288_000_000_000e18);
        _mint(Constants.LIQUIDITY_BONDING, 288_000_000_000e18);
    }

    /// @dev Modifier to ensure the function is called only by the minter contract.
    modifier onlyMinting() {
        _onlyMinting();
        _;
    }

    function setMinting(GoatXMinting _minting) external onlyOwner {
        minting = _minting;
    }

    function setGoatFeed(address _goatFeed) external onlyOwner {
        goatFeed = _goatFeed;
    }

    function setBuyAndBurn(GoatXBuyAndBurn _bnb) external onlyOwner {
        buyAndBurn = _bnb;
    }

    function setAuctionBuy(AuctionBuy _auctionBuy) external onlyOwner {
        auctionBuy = _auctionBuy;
    }

    function toggleLP() external onlyMinting {
        hasLp = true;
    }

    /**
     * @notice Mints GOATX tokens to a specified address.
     * @notice This is only callable by the GoatXMinting contract
     * @param _to The address to mint the tokens to.
     * @param _amount The amount of tokens to mint.
     */
    function mint(address _to, uint256 _amount) external onlyMinting {
        _mint(_to, _amount);
    }

    ///@dev Done to avoid malicious users of doing 0 value swaps to change the price
    function balanceOf(address user) public view override returns (uint256 balance) {
        require(hasLp);
        return super.balanceOf(user);
    }

    /// @dev Private method is used instead of inlining into modifier because modifiers are copied into each method,
    ///     and the use of immutable means the address bytes are copied in every place the modifier is used.
    function _onlyMinting() internal view {
        if (msg.sender != address(minting)) revert OnlyMinting();
    }

    function _createTitanXGoatXPool(address _titanX, address UNISWAP_V3_POSITION_MANAGER)
        internal
        returns (address pool)
    {
        pool = _createPool(
            _titanX,
            address(this),
            Constants.INITIAL_TITAN_X_FOR_TITANX_GOATX,
            Constants.INITIAL_GOATX_FOR_LP,
            UNISWAP_V3_POSITION_MANAGER
        );
    }

    function _createPool(
        address _tokenA,
        address _tokenB,
        uint256 _amountA,
        uint256 _amountB,
        address UNISWAP_V3_POSITION_MANAGER
    ) internal returns (address pool) {
        (address token0, address token1) = _tokenA < _tokenB ? (_tokenA, _tokenB) : (_tokenB, _tokenA);

        (uint256 amount0, uint256 amount1) = token0 == _tokenA ? (_amountA, _amountB) : (_amountB, _amountA);

        uint160 sqrtPriceX96 = uint160((Math.sqrt((amount1 * 1e18) / amount0) * 2 ** 96) / 1e9);

        INonfungiblePositionManager manager = INonfungiblePositionManager(UNISWAP_V3_POSITION_MANAGER);

        pool = manager.createAndInitializePoolIfNecessary(token0, token1, Constants.POOL_FEE, sqrtPriceX96);

        IUniswapV3Pool(pool).increaseObservationCardinalityNext(uint16(100));
    }
}