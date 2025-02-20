// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import {SafeERC20} from "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";

import {IMajoraAccessManager} from "./majora-finance_access-manager_contracts_interfaces_IMajoraAccessManager.sol";
import {IMajoraAddressesProvider} from "./majora-finance_access-manager_contracts_interfaces_IMajoraAddressesProvider.sol";
import {IMajoraPortal} from "./majora-finance_portal_contracts_interfaces_IMajoraPortal.sol";
import {DataTypes} from "./majora-finance_libraries_contracts_DataTypes.sol";
import {LibOracleState} from "./majora-finance_libraries_contracts_LibOracleState.sol";

import {IPool} from "./aave_core-v3_contracts_interfaces_IPool.sol";
import {IAaveOracle} from "./aave_core-v3_contracts_interfaces_IAaveOracle.sol";
import {DataTypes as AaveDataType} from "./aave_core-v3_contracts_protocol_libraries_types_DataTypes.sol";
import {ReserveConfiguration} from "./aave_core-v3_contracts_protocol_libraries_configuration_ReserveConfiguration.sol";

import {IMajoraAaveV3PositionManager} from "./contracts_aave_interfaces_IMajoraAaveV3PositionManager.sol";

/**
 * @title Majora Aave V3 Position Manager commons
 * @author Majora Development Association
 * @notice This contract manages positions within the Aave V3 protocol, 
 * enabling Majoraies that involve leveraging, unleveraging, and rebalancing of assets. 
 * It interacts with Aave's lending pool to supply collateral, borrow assets, and manage debt positions, 
 * while also utilizing a portal for asset swaps necessary for Majoray execution. 
 * The contract supports operations such as initializing a position with specific parameters, 
 * leveraging up or down a position, and rebalancing based on health factor thresholds.
 * @dev The contract uses the SafeERC20 library for safe token transfers and the WadRayMath library for precise arithmetic operations. 
 * It integrates with Aave's lending pool and oracle for managing and valuing the positions. 
 * The contract is designed to be operated by an owner, who can execute Majoraies, and an operator, who can rebalance positions. 
 * It leverages flash loans for non-custodial leverage operations and integrates with a swap portal for executing asset swaps.
 */
abstract contract MajoraAaveV3PositionManagerCommons is IMajoraAaveV3PositionManager {
    using SafeERC20 for IERC20;
    using ReserveConfiguration for AaveDataType.ReserveConfigurationMap;

    /// @notice The unique identifier for referral purposes.
    uint16 constant REFERAL = 57547;

    /// @notice The Aave protocol's pool contract.
    IPool public immutable pool;

    /// @notice The Aave protocol's oracle contract.
    IAaveOracle public immutable oracle;

    /// @notice The portal contract to execute swap
    IMajoraAddressesProvider public immutable addressProvider;

    /// @notice Indicates whether the contract has been initialized.
    bool public initialized;

    /// @notice The owner of the position.
    bool public ownerIsMajoraVault;

    /// @notice The owner of the position.
    address public owner;

    /// @notice The index of the block at which the position was created.
    uint256 public blockIndex;

    /// @notice The current position managed by this contract.
    Position _position;

    constructor(address _pool, address _oracle, address _addressProvider) {
        pool = IPool(_pool);
        oracle = IAaveOracle(_oracle);
        addressProvider = IMajoraAddressesProvider(_addressProvider);
    }

    modifier onlyOperatorProxy() {
        if (msg.sender != addressProvider.operatorProxy()) revert NotOperator();
        _;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    /**
     * @notice Initializes the position manager with the specified parameters.
     * @dev This function sets the initial state of the position manager, including owner, block index, and position details. It can only be called once.
     * @param _owner The address of the owner of the position.
     * @param _blockIndex The index of the block at which the position is created.
     * @param _params Encoded initialization parameters for the position.
     */
    function initialize(bool _ownerIsMajoraVault, address _owner, uint256 _blockIndex, bytes calldata _params) external {
        if (initialized) revert AlreadyInitialized();
        initialized = true;
        owner = _owner;
        blockIndex = _blockIndex;
        ownerIsMajoraVault = _ownerIsMajoraVault;

        InitializationParams memory initParams = abi.decode(_params, (InitializationParams));

        AaveDataType.ReserveData memory collateralReserveData = _getReserveData(address(initParams.collateral));
        AaveDataType.ReserveData memory debtReserveData = _getReserveData(address(initParams.borrowed));

        uint256 ltv;
        uint256 lts;
        IAaveOracle orc;
        if (initParams.eModeCategoryId == 0) {
            //If eMode is disabled
            ltv = collateralReserveData.configuration.getLtv();
            lts = collateralReserveData.configuration.getLiquidationThreshold();
            orc = oracle;
        } else {
            //If eMode is enabled
            pool.setUserEMode(initParams.eModeCategoryId);
            AaveDataType.EModeCategory memory emode = pool.getEModeCategoryData(initParams.eModeCategoryId);
            ltv = uint256(emode.ltv);
            lts = uint256(emode.liquidationThreshold);
            orc = emode.priceSource != address(0) ? IAaveOracle(emode.priceSource) : oracle;
        }

        _position = Position({
            eModeCategoryId: initParams.eModeCategoryId,
            oracle: orc,
            collateral: Collateral({
                token: initParams.collateral,
                decimals: initParams.collateralDecimals,
                aToken: IERC20(collateralReserveData.aTokenAddress),
                ltv: ltv,
                lts: lts
            }),
            // cap: collateralReserveData.configuration.getSupplyCap() * 10**initParams.collateralDecimals
            debt: Debt({
                token: initParams.borrowed,
                debtToken: initParams.debtType == 1
                    ? IERC20(debtReserveData.stableDebtTokenAddress)
                    : IERC20(debtReserveData.variableDebtTokenAddress),
                debtType: initParams.debtType,
                decimals: initParams.borrowedDecimals
            }),
            // cap: debtReserveData.configuration.getBorrowCap() * 10**initParams.borrowedDecimals
            healthfactor: Healthfactor({min: initParams.hfMin, max: initParams.hfMax, desired: initParams.hfDesired})
        });

        _verifyHealthfactor(initParams.hfMin, initParams.hfDesired, initParams.hfMax);
    }

    /**
     * @notice Updates the Aave data for the current position.
     *
     * @dev This function refreshes the loan-to-value (LTV) and liquidation threshold (LTS) of the collateral
     * based on whether eMode is enabled or disabled for the position. If eMode is enabled, it also updates
     * the oracle address used for price information. This is necessary to keep the position's parameters
     * in sync with the latest data from the Aave protocol.
     */
    function refreshAaveData() external {
        AaveDataType.ReserveConfigurationMap memory collateralReserveConfig = pool.getConfiguration(
            address(_position.collateral.token)
        );
        // AaveDataType.ReserveData memory debtReserveData = pool.getReserveData(address(_position.debt.token));

        if (_position.eModeCategoryId == 0) {
            //If eMode is disabled
            _position.collateral.ltv = collateralReserveConfig.getLtv();
            _position.collateral.lts = collateralReserveConfig.getLiquidationThreshold();
        } else {
            //If eMode is enabled

            AaveDataType.EModeCategory memory emode = pool.getEModeCategoryData(_position.eModeCategoryId);

            _position.collateral.ltv = uint256(emode.ltv);
            _position.collateral.lts = uint256(emode.liquidationThreshold);
            _position.oracle = emode.priceSource != address(0) ? IAaveOracle(emode.priceSource) : oracle;
        }
    }

    /**
     * @notice Returns the current position of the Majoray.
     * @dev This function provides a view into the current state of the Majoray's position, including leverage mode, eMode category, oracle, collateral, debt, and health factor details.
     */
    function changeHealthfactorConfig(
        uint256 _minHf,
        uint256 _desiredHf,
        uint256 _maxHf
    ) external onlyOwner {
        _verifyHealthfactor(_minHf, _desiredHf, _maxHf);
        _position.healthfactor = Healthfactor({min: _minHf, desired: _desiredHf, max: _maxHf});
        emit HealthfactorConfigChanged(_minHf, _desiredHf, _maxHf);
    }

    /**
     * @notice Returns the current position of the Majoray.
     * @dev This function provides a view into the current state of the Majoray's position, including leverage mode, eMode category, oracle, collateral, debt, and health factor details.
     * @return The current position of the Majoray as a `Position` struct.
     */
    function position() external view returns (Position memory) {
        return _position;
    }

    /**
     * portal swap
     */
    function _swap(DataTypes.DynamicSwapData memory params) internal {
        address portal = addressProvider.portal();

        IERC20(params.sourceAsset).safeIncreaseAllowance(portal, params.amount);
        IMajoraPortal(portal).majoraBlockSwap(
            params.route,
            params.approvalAddress,
            params.sourceAsset,
            params.targetAsset,
            params.amount,
            params.data
        );
    }

    /**
     * Aave interactions
     */
    function _getReserveData(address asset) internal view returns (AaveDataType.ReserveData memory) {
        return pool.getReserveData(asset);
    }

    function _getUserAccountData(
        address user
    )
        internal
        view
        returns (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        )
    {
        return pool.getUserAccountData(user);
    }

    function _supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) internal {
        IERC20(asset).safeIncreaseAllowance(address(pool), amount);
        pool.supply(asset, amount, onBehalfOf, referralCode);
    }

    function _withdraw(address asset, uint256 amount, address to) internal returns (uint256) {
        return pool.withdraw(asset, amount, to);
    }

    function _repay(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        address onBehalfOf
    ) internal returns (uint256) {
        _position.debt.token.safeIncreaseAllowance(address(pool), amount);
        return pool.repay(asset, amount, interestRateMode, onBehalfOf);
    }

    function _borrow(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        uint16 referralCode,
        address onBehalfOf
    ) internal {
        pool.borrow(asset, amount, interestRateMode, referralCode, onBehalfOf);
    }

    function _flashloan(
        address receiverAddress,
        address[] memory assets,
        uint256[] memory amounts,
        uint256[] memory interestRateModes,
        address onBehalfOf,
        bytes memory params,
        uint16 referralCode
    ) internal {
        return pool.flashLoan(receiverAddress, assets, amounts, interestRateModes, onBehalfOf, params, referralCode);
    }

    function _getFlashloanData(
        uint256 _percent,
        address _asset,
        uint256 _interestRateMode,
        FlashloanCallbackType _type,
        bytes memory _dynamicParams
    ) internal pure returns (
        address[] memory,
        uint256[] memory,
        uint256[] memory,
        FlashloanData memory
    ) {
        DataTypes.DynamicSwapData memory params = abi.decode(_dynamicParams, (DataTypes.DynamicSwapData));

        address[] memory assets = new address[](1);
        assets[0] = _asset;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = params.amount;

        uint256[] memory interestRateModes = new uint256[](1);
        interestRateModes[0] = _interestRateMode;

        FlashloanData memory leverageParams = FlashloanData({callback: _type, data: _dynamicParams, percent: _percent});

        return (assets, amounts, interestRateModes, leverageParams);
    }

    function _verifyHealthfactor(uint256 _min, uint256 _desired, uint256 _max) internal view {
        if(
            _min <  _position.collateral.lts * 1e18 / _position.collateral.ltv || 
            _max <= _min || 
            _desired <= _min || 
            _desired >= _max
        ) revert BadHealthfactorConfiguration();
    }

    /**
     * @notice Clean the position manager dust
     * @dev This function has to be executed when the position is closed and some dust are remaining on the vault.
     * it send all remaining collateral balance to the owner after it executed the swap if there is remaining debt token
     * @param swapPayload The swap payload to swap remaining debt token to the collateral 
     */
    function cleanDust(bytes memory swapPayload) external {
        if(ownerIsMajoraVault) {
            IMajoraAccessManager _authority = IMajoraAccessManager(addressProvider.accessManager());
            (bool isMember,) = _authority.hasRole(
                _authority.OPERATOR_ROLE(),
                msg.sender
            );

            if(!isMember) revert NotOperator();
        } else {
            if (msg.sender != owner) revert NotOwner();
        }
        
        (,,,,, uint256 healthFactor) = _getUserAccountData(address(this));
        if (healthFactor < type(uint256).max) revert PositionIsNotClosed();

        if(swapPayload.length > 0) {
            DataTypes.DynamicSwapData memory params = abi.decode(swapPayload, (DataTypes.DynamicSwapData));
            _swap(params);
        }
        
        uint256 collateralBal = _position.collateral.token.balanceOf(address(this));
        if(collateralBal > 0) {
            _position.collateral.token.safeTransfer(owner, collateralBal);
        }
    }
}