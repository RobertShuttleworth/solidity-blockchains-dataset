// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Initializable } from "./lib_openzeppelin-contracts-upgradeable_contracts_proxy_utils_Initializable.sol";
import { UUPSUpgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_proxy_utils_UUPSUpgradeable.sol";
import { AccessControlUpgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_access_AccessControlUpgradeable.sol";
import { IERC20, SafeERC20 } from "./lib_openzeppelin-contracts-upgradeable_lib_openzeppelin-contracts_contracts_token_ERC20_utils_SafeERC20.sol";
import { EnumerableSet } from "./lib_openzeppelin-contracts-upgradeable_lib_openzeppelin-contracts_contracts_utils_structs_EnumerableSet.sol";
import { ReentrancyGuardUpgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_utils_ReentrancyGuardUpgradeable.sol";
import { IV3SwapRouter } from "./src_interfaces_external_IV3SwapRouter.sol";
import { IAggregatorV3 } from "./src_interfaces_external_IAggregatorV3.sol";
import { IWETH9 } from "./src_interfaces_external_IWETH9.sol";

contract PackagePurchaseHub is Initializable, AccessControlUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    uint24 public constant JPYT_USDT_POOL_FEE = 3000;
    uint24 public constant USDT_WETH_POOL_FEE = 500;
    uint24 public constant WETH_TA_POOL_FEE = 3000;

    uint16 public constant BASIS_POINTS = 10_000;

    IV3SwapRouter public swapRouter;
    IERC20 public jpyt;
    IERC20 public usdt;
    IWETH9 public weth;
    IERC20 public ta;

    bytes public jpytWETHPath;
    bytes public jpytTAPath;

    address public ethStakingPool;
    address public talesStakingPool;

    IAggregatorV3 public jpyUSDPriceAggregator;
    IAggregatorV3 public ethUSDPriceAggregator;

    uint256 public packagePrice;
    uint16 public slippageToleranceBP;

    uint16 public jpytETHPercentBP;
    uint16 public jpytTAPercentBP;
    address[] public recipientAddrs;
    uint16[] public recipientPercentBPs;

    event PackagePriceSet(uint256 indexed _packagePrice);
    event SlippageToleranceBPSet(uint16 indexed _slippageToleranceBP);
    event PercentBPsSet(
        uint16 _jpytETHPercentBP, uint16 _jpytTAPercentBP, address[] _recipientAddrs, uint16[] recipientPercentBPs
    );
    event PackageBought(
        address _buyer,
        uint256 _quantity,
        uint256 _duration,
        bool _ethReward,
        uint256 _totalJPYTAmount,
        uint256 _jpytTAAmountIn,
        uint256 _taAmountOut
    );

    error InvalidPackagePrice();
    error InvalidTreasury();
    error MismatchedLengths();
    error InvalidPercentBPs();
    error TransferETHFailed();
    error InvalidPriceFeedData();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _defaultAdmin,
        address _operator,
        address _upgrader,
        address _swapRouter,
        address _jpyt,
        address _usdt,
        address _weth,
        address _ta,
        address _ethStakingPool,
        address _talesStakingPool,
        address _jpyUSDPriceAggregator,
        address _ethUSDPriceAggregator,
        uint256 _packagePrice,
        uint16 _slippageToleranceBP,
        uint16 _jpytETHPercentBP,
        uint16 _jpytTAPercentBP,
        address[] calldata _recipientAddrs,
        uint16[] calldata _recipientPercentBPs
    )
        public
        initializer
    {
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _defaultAdmin);
        _grantRole(OPERATOR_ROLE, _operator);
        _grantRole(UPGRADER_ROLE, _upgrader);

        swapRouter = IV3SwapRouter(_swapRouter);
        jpyt = IERC20(_jpyt);
        usdt = IERC20(_usdt);
        weth = IWETH9(_weth);
        ta = IERC20(_ta);
        jpytWETHPath =
            abi.encodePacked(address(jpyt), JPYT_USDT_POOL_FEE, address(usdt), USDT_WETH_POOL_FEE, address(weth));
        jpytTAPath = abi.encodePacked(
            address(jpyt),
            JPYT_USDT_POOL_FEE,
            address(usdt),
            USDT_WETH_POOL_FEE,
            address(weth),
            WETH_TA_POOL_FEE,
            address(ta)
        );

        ethStakingPool = _ethStakingPool;
        talesStakingPool = _talesStakingPool;

        jpyUSDPriceAggregator = IAggregatorV3(_jpyUSDPriceAggregator);
        ethUSDPriceAggregator = IAggregatorV3(_ethUSDPriceAggregator);

        packagePrice = _packagePrice;
        slippageToleranceBP = _slippageToleranceBP;

        jpytETHPercentBP = _jpytETHPercentBP;
        jpytTAPercentBP = _jpytTAPercentBP;
        recipientAddrs = _recipientAddrs;
        recipientPercentBPs = _recipientPercentBPs;
    }

    receive() external payable { }

    function setPackagePrice(uint256 _packagePrice) public onlyRole(OPERATOR_ROLE) {
        if (_packagePrice == 0) revert InvalidPackagePrice();

        packagePrice = _packagePrice;

        emit PackagePriceSet(_packagePrice);
    }

    function setSlippageToleranceBP(uint16 _slippageToleranceBP) public onlyRole(OPERATOR_ROLE) {
        slippageToleranceBP = _slippageToleranceBP;

        emit SlippageToleranceBPSet(_slippageToleranceBP);
    }

    function setPercentBPs(
        uint16 _jpytETHPercentBP,
        uint16 _jpytTAPercentBP,
        address[] calldata _recipientAddrs,
        uint16[] calldata _recipientPercentBPs
    )
        public
        onlyRole(OPERATOR_ROLE)
    {
        if (_recipientAddrs.length != _recipientPercentBPs.length) {
            revert MismatchedLengths();
        }

        uint16 sumPercentBPs = _jpytETHPercentBP + _jpytTAPercentBP;
        for (uint256 i = 0; i < _recipientAddrs.length; i++) {
            sumPercentBPs += _recipientPercentBPs[i];
        }
        if (sumPercentBPs != BASIS_POINTS) {
            revert InvalidPercentBPs();
        }

        jpytETHPercentBP = _jpytETHPercentBP;
        jpytTAPercentBP = _jpytTAPercentBP;
        recipientAddrs = _recipientAddrs;
        recipientPercentBPs = _recipientPercentBPs;

        emit PercentBPsSet(_jpytETHPercentBP, _jpytTAPercentBP, _recipientAddrs, _recipientPercentBPs);
    }

    function buyPackage(
        uint256 _quantity,
        uint256 _duration,
        bool _ethReward,
        uint256 _taMinimumOutput
    )
        public
        nonReentrant
    {
        uint256 totalJPYTAmount = _quantity * packagePrice;

        for (uint256 i = 0; i < recipientAddrs.length; i++) {
            uint256 recipientAmount = totalJPYTAmount * recipientPercentBPs[i] / BASIS_POINTS;
            IERC20(jpyt).safeTransferFrom(_msgSender(), recipientAddrs[i], recipientAmount);
        }

        uint256 jpytWETHAmountIn = totalJPYTAmount * jpytETHPercentBP / BASIS_POINTS;
        IERC20(jpyt).safeTransferFrom(_msgSender(), address(this), jpytWETHAmountIn);
        IERC20(jpyt).safeIncreaseAllowance(address(swapRouter), jpytWETHAmountIn);
        uint256 wethMinimumOutput = calculateJPYTWETHMinimumOutput(jpytWETHAmountIn);
        IV3SwapRouter.ExactInputParams memory jpytWETHParams = IV3SwapRouter.ExactInputParams({
            path: jpytWETHPath,
            recipient: address(this),
            amountIn: jpytWETHAmountIn,
            amountOutMinimum: wethMinimumOutput
        });
        uint256 wethAmountOut = swapRouter.exactInput(jpytWETHParams);
        IWETH9(weth).withdraw(wethAmountOut);
        uint256 ethAmount = wethAmountOut;
        (bool sent,) = ethStakingPool.call{ value: ethAmount }("");
        if (!sent) {
            revert TransferETHFailed();
        }

        uint256 jpytTAAmountIn = totalJPYTAmount * jpytTAPercentBP / BASIS_POINTS;
        IERC20(jpyt).safeTransferFrom(_msgSender(), address(this), jpytTAAmountIn);
        IERC20(jpyt).safeIncreaseAllowance(address(swapRouter), jpytTAAmountIn);
        IV3SwapRouter.ExactInputParams memory jpytTAParams = IV3SwapRouter.ExactInputParams({
            path: jpytTAPath,
            recipient: talesStakingPool,
            amountIn: jpytTAAmountIn,
            amountOutMinimum: _taMinimumOutput
        });
        uint256 taAmountOut = swapRouter.exactInput(jpytTAParams);

        emit PackageBought(_msgSender(), _quantity, _duration, _ethReward, totalJPYTAmount, jpytTAAmountIn, taAmountOut);
    }

    function calculateJPYTWETHMinimumOutput(uint256 _amountIn) public view returns (uint256 wethMinimumOutput) {
        (, int256 jpyUSDPrice,,,) = jpyUSDPriceAggregator.latestRoundData();
        if (jpyUSDPrice <= 0) revert InvalidPriceFeedData();

        (, int256 ethUSDPrice,,,) = ethUSDPriceAggregator.latestRoundData();
        if (ethUSDPrice <= 0) revert InvalidPriceFeedData();

        wethMinimumOutput =
            (_amountIn * uint256(jpyUSDPrice) * slippageToleranceBP * 1e12) / (uint256(ethUSDPrice) * BASIS_POINTS);
    }

    function _authorizeUpgrade(address _newImplementation) internal override onlyRole(UPGRADER_ROLE) { }
}