// SPDX-License-Identifier: GPL-3.0
// Copyright: https://github.com/credit-cooperative/Line-Of-Credit-v2/blob/master/COPYRIGHT.md

pragma solidity ^0.8.25;

import {IOTC} from "./lib_Line-Of-Credit-v2_contracts_interfaces_IOTC.sol";
import {INonFungiblePositionManager} from "./lib_Line-Of-Credit-v2_contracts_interfaces_INonFungiblePositionManager.sol";

interface IEscrow {
    struct Deposit {
        uint256 amount;
        bool isERC4626;
        address asset; // eip4626 asset else the erc20 token itself
        uint8 assetDecimals;
    }

    event AddCollateral(address indexed token, uint256 indexed amount);
    event RemoveCollateral(address indexed token, uint256 indexed amount);
    event RemovePosition(uint256 tokenId);
    event EnableCollateral(address indexed token);
    event EnablePairAsCollateral(address indexed tokenA, address indexed tokenB);
    event UpdateMinimumCollateralRatio(uint256 indexed ratio);
    event UpdateBorrower(address indexed borrower, address indexed newBorrower);

    error ExpiredOrder();
    error InvalidCollateral();
    error CallerAccessDenied();
    error UnderCollateralized();
    error NotLiquidatable();
    error InvalidFunctionSelector();
    error InvalidRecipient();
    error AlreadyInitialized();
    error CannotModifyWithActivePosition();
    error UnregisteredContract(address _contract);

    // State var getters.
    function owner() external view returns (address);
    function oracle() external view returns (address, address, address);
    function borrower() external view returns (address);
    function minimumCollateralRatio() external view returns (uint32);
    function getCollateralData(address token) external view returns (Deposit memory);

    function getCollateralRatio() external returns (uint256);
    function getCollateralValue() external returns (uint256);

    // Functions

    function initializeFromFactory(
        uint32 _minimumCollateralRatio,
        address _owner,
        address _borrower,
        address _nftPositionManager,
        address _univ3Manager
    ) external;

    function setUniswapV3Manager(address _manager) external;
    function isLiquidatable() external returns (bool);

    function updateOwner(address owner_) external returns (bool);

    function addCollateral(uint256 amount, address token) external payable;
    function enableTokenPairAsCollateral(address token0, address token1, uint24 fee) external;
    function addUniV3Position(uint256 tokenId) external returns (bool);
    function enableCollateral(address token) external returns (bool);
    function isCollateralEnabled(address token) external view returns (bool);
    function enablePosition(uint256 tokenId) external;
    function releaseCollateral(uint256 amount, address token, address to) external;
    function releasePosition(uint256 tokenId, address to) external;
    function otcSwap(IOTC.OTC memory otc) external;
    function updateAllowedOTCPriceImpact(uint128 allowedPriceImpact) external;
    function updateStableCoinWhitelist(address token, bool isAllowed) external;
    function liquidate(uint256 amount, address token, address to) external;
    function liquidateUniV3Position(uint256 tokenId, address to) external;
    function updateBorrower(address newBorrower) external;
    function updateMinimumCollateralRatio(uint32 minimumCollateralRatio) external;
    function registerBorrowerContract(address contractToRegister, bool state) external;

    // Recovery functionality
    function recoverEscrowTokens(address token, address to, uint256 amount) external;
    function recoverUniV3Positions(address to) external;

    // Operation funcs
    function whitelistFunction(bytes4 functionToRegister, bool state) external;
    function operate(address targetContract, bytes calldata data) external;
    function sync() external;

    // Uniswap V3 functions
    function increaseLiquidity(INonFungiblePositionManager.IncreaseLiquidityParams calldata params) external;
    function decreaseLiquidity(INonFungiblePositionManager.DecreaseLiquidityParams calldata params) external;
    function collect(INonFungiblePositionManager.CollectParams calldata params) external;
    function burn(INonFungiblePositionManager.DecreaseLiquidityParams calldata params) external;
    function mint(address pool, INonFungiblePositionManager.MintParams memory params) external;
}