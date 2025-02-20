// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;
import {MajoraOracleAdaptersType, LibOracle} from "./majora-finance_portal_contracts_libraries_LibOracle.sol";

interface IMajoraPortal {

    error AccessManagedUnauthorized(address caller);
    error NotWhitelistedAddress();
    error SwapRouterError(bytes _data);
    error UnknownSwapRouterError();
    error NativeAssetTransferError();
    error InvalidRoute();
    error NoAmountOut();

    error UnknownRescueError();
    event SwapRouterTargetConfigured(address target);
    event SwapFeesBpsConfigured(uint256 feesBps);
    event SwapRouterExecutionResult(bool success, bytes returnData);
    event OracleWhitelistChanged(address indexed addr, bool whitelisted);
    event OracleRateChanged(address indexed asset, uint256 price);

    event SwapExecuted(uint8 route, address indexed sender, address fromToken, address toToken, uint256 amount);
    event BridgeExecuted(uint8 route, address indexed sender, address fromToken, uint256 toChain, address toToken, uint256 amount);
    event FeeCollected(address token, uint256 amount);

    event OracleConfigured(
        bool indexed enabled,
        address indexed asset,
        uint8 _assetDecimals,
        MajoraOracleAdaptersType _adapterType,
        address _adapter
    );

    function getOracleRates(
        address[] memory _froms,
        address[] memory _to,
        uint256[] memory _amount
    ) external view returns (uint256[] memory);

    function getOracleRate(
        address _from,
        address _to,
        uint256 _amount
    ) external view returns (uint256);

    function updateOraclePrice(
        address[] memory _addresses,
        uint256[] memory _prices
    ) external;

    function oraclePricesAreEnable(
        address[] calldata _assets
    ) external view returns (bool[] memory);

    function getUSDOraclePrice(address _assets) external view returns (uint256);

    function getUSDOraclePrices(
        address[] memory _assets
    ) external view returns (uint256[] memory);

    function getOracleConfiguration(
        address _asset
    ) external view returns (LibOracle.OracleEntry memory configuration);

    function configureOracle(
        bool _enabled,
        address _asset,
        uint8 _assetDecimals,
        MajoraOracleAdaptersType _adapterType,
        address _adapter
    ) external;

    function batchConfigureOracle(
        bool[] calldata _enabled,
        address[] calldata _asset,
        uint8[] calldata _assetDecimals,
        MajoraOracleAdaptersType[] calldata _adapterType,
        address[] calldata _adapter
    ) external;

    function swap(
        bool sourceIsVault,
        bool targetIsVault,
        uint8 _route,
        address _receiver,
        address _approvalAddress,
        address _sourceAsset,
        address _targetAsset,
        uint256 _amount,
        bytes memory _permitParams,
        bytes calldata _data
    ) external payable;

    function swapAndBridge(
        bool _sourceIsVault,
        uint8 _route,
        address _approvalAddress,
        address _sourceAsset,
        address _targetAsset,
        uint256 _amount,
        uint256 _targetChain,
        bytes memory _permitParams,
        bytes calldata _data
    ) external payable;

    function rescueFunds(
        address _token,
        address _receiver,
        uint256 _value
    ) external;

    function swapForMOPT(
        uint8 _route,
        address _receiver,
        address _approvalAddress,
        address _sourceAsset,
        uint256 _amount,
        bytes memory _permitParams,
        bytes calldata _data
    ) external payable;

    function withdrawMOPTAndSwap(
        uint8 _route,
        address _receiver,
        address _approvalAddress,
        address _targetAsset,
        uint256 _amount,
        bytes memory _permitParams,
        bytes calldata _data
    ) external payable;

    function withdrawMOPTAndBridge(
        uint8 _route,
        address _approvalAddress,
        uint256 _amount,
        bytes memory _permitParams,
        bytes calldata _data
    ) external payable;

    function majoraBlockSwap(
        uint8 _route,
        address _approvalAddress,
        address _sourceAsset,
        address _targetAsset,
        uint256 _amount,
        bytes calldata _data
    ) external payable;

    function swapRouterTarget(uint8 _router) external view returns (address);

    function setSwapRouterTarget(uint8 _router, address _target) external;

    function swapFeesBps() external view returns (uint256);
    
    function setSwapFeesBps(uint256 _feesBps) external;

    function relayer() external view returns (address);

    function setRelayer(address _relayer) external;

    function balancerWeightedMath() external view returns (address);

    function setBalancerWeightedMath(address _balancerWeightedMath) external;

    function remoteCallReceiver(
        address _tokenReceived,
        address _sender,
        address _toVault
    ) external;

    function remoteCallReceiverForMOPT(
        address _tokenReceived,
        address _sender
    ) external payable;

    function balancerWeightedLpPrice(
        address lpTokenPair,
        address denominationToken
    ) external view returns (uint256 lpTokenPrice);

    function balancerComposableLpPrice(
        address lpTokenPair,
        address denominationToken
    ) external view returns (uint256 lpTokenPrice);

    function balancerWeightedCheckPrices(
        address lpTokenPair
    ) external view returns (bool success);
}