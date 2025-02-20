// // SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Initializable} from  "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";
import {SafeERC20} from  "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";
import {IERC20} from  "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import {IERC4626} from  "./openzeppelin_contracts_interfaces_IERC4626.sol";
import {ECDSA} from  "./openzeppelin_contracts_utils_cryptography_ECDSA.sol";
import {MessageHashUtils} from  "./openzeppelin_contracts_utils_cryptography_MessageHashUtils.sol";
import {AccessManagedUpgradeable} from  "./openzeppelin_contracts-upgradeable_access_manager_AccessManagedUpgradeable.sol";

import {LibPermit} from "./majora-finance_libraries_contracts_LibPermit.sol";
import {LibBlock} from "./majora-finance_libraries_contracts_LibBlock.sol";
import {LibOracleState} from "./majora-finance_libraries_contracts_LibOracleState.sol";
import {VaultConfiguration} from "./majora-finance_libraries_contracts_VaultConfiguration.sol";
import {DataTypes} from "./majora-finance_libraries_contracts_DataTypes.sol";
import {IMajoraAddressesProvider} from "./majora-finance_access-manager_contracts_interfaces_IMajoraAddressesProvider.sol";
import {IMajoraAccessManager} from "./majora-finance_access-manager_contracts_interfaces_IMajoraAccessManager.sol";
import {IMajoraOperationsPaymentToken} from "./majora-finance_mopt_contracts_interfaces_IMajoraOperationsPaymentToken.sol";
import {IMajoraPortal} from "./majora-finance_portal_contracts_interfaces_IMajoraPortal.sol";

import {IMajoraPositionManager} from "./contracts_interfaces_IMajoraPositionManager.sol";
import {IMajoraVault} from "./contracts_interfaces_IMajoraVault.sol";
import {IMajoraOperatorProxy} from "./contracts_interfaces_IMajoraOperatorProxy.sol";

/**
 * @title MajoraOperatorProxy
 * @author Majora Development Association
 * @notice This contract serves as a proxy for executing operations on Strategy vaults. It requires the OPERATOR_ROLE to perform the operations.
 */
contract MajoraOperatorProxy is Initializable, AccessManagedUpgradeable, IMajoraOperatorProxy {
    using ECDSA for bytes32;
    using SafeERC20 for IERC20;
    using VaultConfiguration for DataTypes.VaultConfigurationMap;
    using LibOracleState for DataTypes.OracleState;

    /// @notice Mapping of vault addresses to their locked status.
    IMajoraAddressesProvider public addressProvider;

    /// @notice Mapping of addresses to their respective withdrawal rebalance nonce.
    mapping(address => uint256) public userWithdrawalRebalancedNonce;

    /// @notice Mapping of vault addresses to their locked status.
    mapping(address => bool) public lockedVault;
    

    modifier isNotLocked(address _vault) {
        if (lockedVault[_vault]) revert VaultIsLocked();
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the contract by granting the DEFAULT_ADMIN_ROLE to the treasury address.
     * @param _authority The address of the access manager.
     */
    function initialize(address _authority, address _addressProvider) public initializer {
        __AccessManaged_init(_authority);
        addressProvider = IMajoraAddressesProvider(_addressProvider);
    }

    /**
     * @notice Executes the rebalance function on the Strategy vault.
     * @param _vault Address of the Strategy vault.
     * @param _payer payer for operation cost
     * @param _gasCost gas cost to pay for operation
     * @param _dynParamsIndex Array of dynamic parameter indexes to rebalance positions.
     * @param _dynParams Array of dynamic parameters to rebalance positions.
     */
    function vaultRebalance(
        address _vault,
        address _payer,
        uint256 _gasCost,
        uint256[] memory _dynParamsIndex,
        bytes[] memory _dynParams
    ) external restricted isNotLocked(_vault) {
        _executePayment(
            false,
            _vault,
            _payer,
            msg.sender,
            _gasCost
        );

        IMajoraVault(_vault).rebalance(_dynParamsIndex, _dynParams);
        emit VaultStrategyRebalanced(_vault, _payer, _gasCost);
    }

    /**
     * @notice Executes the withdrawalRebalance function on the Strategy vault.
     * @param _vault Address of the Strategy vault.
     * @param _amount Amount to be withdrawn.
     * @param _signature Needed if vault need 
     * @param _portalPayload Parameters for executing a swap with returned assets.
     * @param _permitParams Parameters for executing a permit (optional).
     * @param _dynParamsIndexExit Array of dynamic parameter indexes for exiting positions.
     * @param _dynParamsExit Array of dynamic parameters for exiting positions.
     */
    function vaultWithdrawalRebalance(
        address _user,
        address _vault,
        uint256 _deadline,
        uint256 _amount,
        bytes memory _signature,
        bytes memory _portalPayload,
        bytes memory _permitParams,
        uint256[] memory _dynParamsIndexExit,
        bytes[] memory _dynParamsExit
    ) external payable returns (uint256 returnedAssets) {
        if(msg.sender != addressProvider.userInteractions()) revert OnlyUserInteraction(); 
        if(_deadline < block.timestamp) revert DeadlineExceeded();

        bool isProtected = _dynParamsIndexExit.length > 0;
        if(isProtected) {
            bytes32 signedHash = keccak256(
                abi.encode(
                    _vault, 
                    _user,
                    userWithdrawalRebalancedNonce[_user],
                    _deadline,
                    _dynParamsIndexExit, 
                    _dynParamsExit
                )
            );

            bytes32 messageHash = MessageHashUtils.toEthSignedMessageHash(signedHash);
            address signer = messageHash.recover(_signature);

            IMajoraAccessManager _authority = IMajoraAccessManager(authority());
            (bool isMember,) = _authority.hasRole(
                _authority.OPERATOR_ROLE(),
                signer
            );

            if(!isMember) revert AccessManagedUnauthorized(signer);
        }

        userWithdrawalRebalancedNonce[_user] += 1;

        if (_permitParams.length != 0) {    
            LibPermit.executeTransfer(address(0), _vault, _user, address(this), _amount, _permitParams);
        } else {
            IERC20(_vault).safeTransferFrom(_user, address(this), _amount);
        }

        returnedAssets = IMajoraVault(_vault).withdrawalRebalance(
            address(this), _amount, _dynParamsIndexExit, _dynParamsExit
        );

        // --- UNAUDITED: handle vault dust remaining on this contract due to withdrawal rebalance amount computation ---
        uint256 remainingBalance = IERC20(_vault).balanceOf(address(this));
        if(remainingBalance > 0) {
            returnedAssets += IERC4626(_vault).redeem(remainingBalance, address(this), address(this));
        }
        // ---

        IERC20 asset = IERC20(
            IERC4626(_vault).asset()
        );

        if (_portalPayload.length > 0) {
            IMajoraPortal portal = IMajoraPortal(addressProvider.portal());
            IERC20(address(asset)).safeIncreaseAllowance(address(portal), asset.balanceOf(address(this)));
            (bool success, bytes memory _data) = address(portal).call{value: msg.value}(_portalPayload);
            if (!success) revert PortalExecutionFailed(_data);
        } else {
            asset.safeTransfer(_user, asset.balanceOf(address(this)));
        }

        emit VaultStrategyWithdrawalRebalanced(_vault);
    }

    /**
     * @notice Executes the harvest function on the Strategy vault.
     * @param _vault Address of the Strategy vault.
     * @param _payer payer for operation cost
     * @param _gasCost gas cost to pay for operation
     * @param _dynParamsIndex Array of dynamic parameter indexes.
     * @param _dynParams Array of dynamic parameters.
     */
    function vaultHarvest(
        address _vault,
        address _payer,
        uint256 _gasCost,
        uint256[] memory _dynParamsIndex,
        bytes[] memory _dynParams,
        bytes memory _portalPayload
    ) external restricted {
        _executePayment(
            false,
            _vault,
            _payer,
            msg.sender,
            _gasCost
        );

        IMajoraVault(_vault).harvest(_dynParamsIndex, _dynParams);

        if (_portalPayload.length > 0) {
            address portal = addressProvider.portal();

            IERC20 asset = IERC20(
                IERC4626(_vault).asset()
            );
            
            IERC20(address(asset)).safeIncreaseAllowance(address(portal), asset.balanceOf(address(this)));
            (bool success, bytes memory _data) = address(portal).call(_portalPayload);
            if (!success) revert PortalExecutionFailed(_data);
        }

        emit VaultStrategyHarvested(_vault, _payer, _gasCost);
    }

    /**
     * @notice Executes the harvest function on the Strategy vault.
     * @param _vault Address of the Strategy vault.
     * @param _payer payer for operation cost
     * @param _gasCost gas cost to pay for operation
     * @param _dynParamsIndex Array of dynamic parameter indexes.
     * @param _dynParams Array of dynamic parameters.
     */
    function vaultStopStrategy(
        address _vault,
        address _payer,
        uint256 _gasCost,
        uint256[] memory _dynParamsIndex,
        bytes[] memory _dynParams
    ) external restricted {

        _executePayment(
            true,
            _vault,
            _payer,
            msg.sender,
            _gasCost
        );

        IMajoraVault(_vault).stopStrategy(_dynParamsIndex, _dynParams);
        emit VaultStrategyStopped(_vault, _payer, _gasCost);
    }

    /**
     * @notice Executes the rebalance function on the position manager.
     * @param _positionManager Address of the position manager.
     * @param _payer payer for operation cost
     * @param _gasCost gas cost to pay for operation
     * @param _payload Array of dynamic parameter indexes for exiting positions.
     */
    function positionManagerOperation(
        address _positionManager,
        address _payer,
        uint256 _gasCost,
        bytes calldata _payload
    ) external restricted {
        address vault = IMajoraPositionManager(_positionManager).owner();

        _executePayment(
            true,
            vault,
            _payer,
            msg.sender,
            _gasCost
        );

        (bool success, bytes memory _data) = _positionManager.call(_payload);
        if (!success) revert PositionManagerOperationReverted(_data);

        emit PositionManagerRebalanced(_positionManager, _payer, _gasCost);
    }

    /**
     * @notice Executes price updates on portal oracle.
     * @param _addresses Addresses of tokens.
     * @param _prices related prices
     */
    function oracleUpdateOperation(address[] calldata _addresses, uint256[] calldata _prices)
        external
        restricted
    {
        IMajoraPortal portal = IMajoraPortal(addressProvider.portal());
        portal.updateOraclePrice(_addresses, _prices);
    }

    

    /**
     * @notice Withdraws fees from the contract and transfers them to the caller.
     * @param _tokens Array of token addresses to withdraw fees from.
     */
    function withdraw(address[] memory _tokens) external restricted {
        uint256 tLength = _tokens.length;
        for (uint256 i = 0; i < tLength; i++) {
            uint256 bal = IERC20(_tokens[i]).balanceOf(address(this));
            if (bal > 0) IERC20(_tokens[i]).safeTransfer(msg.sender, bal);
        }
    }
    /**
     * @notice Locks the specified vaults, preventing any operations on them.
     * @param _vaults Array of vault addresses to be locked.
     */
    function lockVaults(address[] memory _vaults) public restricted {
        for (uint i = 0; i < _vaults.length; i++) {
            lockedVault[_vaults[i]] = true;
            emit VaultLocked(_vaults[i]);
        }
    }

    /**
     * @notice Unlocks the specified vaults, allowing operations on them.
     * @param _vaults Array of vault addresses to be unlocked.
     */
    function unlockVaults(address[] memory _vaults) public restricted {
        for (uint i = 0; i < _vaults.length; i++) {
            lockedVault[_vaults[i]] = false;
            emit VaultUnlocked(_vaults[i]);
        }
    }


    /**
     * @notice Initializes the contract by granting the DEFAULT_ADMIN_ROLE to the treasury address.
     * @param _force if true, it will not revert if not sufficient MOPT available.
     * @param _payer The address of the payer.
     * @param _receiver The receiver of gas payment.
     * @param _gasCost The gas cost.
     */
    function _executePayment(
        bool _force,
        address _entity,
        address _payer,
        address _receiver,
        uint256 _gasCost
    ) internal {
        if (_gasCost > 0) {
            IMajoraOperationsPaymentToken paymentToken = IMajoraOperationsPaymentToken(addressProvider.mopt());
            if (_payer == address(0)) {
                paymentToken.executePayment(_entity, _receiver, _gasCost);
            } else {
                uint256 allowance = paymentToken.operationAllowances(_payer, _entity);
                if(allowance >= _gasCost) {
                    paymentToken.executePaymentFrom(_payer, _entity, _receiver, _gasCost);
                } else {
                    if(_force)
                        paymentToken.executePaymentFrom(_payer, _entity, _receiver, allowance);
                    else 
                        revert MOPTAllowanceNotSufficient();
                } 
            }
        }
    }
}