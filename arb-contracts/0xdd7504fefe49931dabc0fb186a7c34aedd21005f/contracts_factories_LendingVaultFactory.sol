// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {LendingVault} from "./contracts_LendingVault.sol";
import {CreditStrategy} from "./contracts_strategies_credit_CreditStrategy.sol";
import {ERC7540Factory} from "./contracts_factories_ERC7540Factory.sol";
import {ILendingVaultFactory} from "./contracts_interfaces_ILendingVaultFactory.sol";
import {ILendingVault} from "./contracts_interfaces_ILendingVault.sol";

/**
 * @title  - LendingVaultFactory
 * @author - Credit Cooperative
 * @notice - LendingVaultFactory deploys LendingVault contracts and their associated CreditStrategy contracts.
 * @dev    - Only an admin and approved operators can deploy LendingVault contracts and their associated Credit Strategy contracts.
 * @dev    - LiquidStrategy contracts are not deployed with a factory contract.
 */
contract LendingVaultFactory is ILendingVaultFactory {
    address public admin;
    mapping(address => bool) public factoryOperators;
    address public immutable factory;

    constructor(address _factory, address _admin) {
        factory = _factory;
        admin = _admin;
        factoryOperators[msg.sender] = true; // set the deployer as an operator
    }

    /**
     * @notice - Checks `msg.sender` is `admin`.
     */
    function _onlyAdmin() internal view {
        if (msg.sender != admin) {
            _unauthorized();
        }
    }

    /**
     * @notice - Checks `msg.sender` is `admin` or `msg.sender` is a factory operator.
     */
    function _onlyAdminOrOperator() internal view {
        if (msg.sender != admin && factoryOperators[msg.sender] != true) {
            _unauthorized();
        }
    }

    /**
     * @notice - Checks `msg.sender` is `admin`.
     */
    function _unauthorized() private pure {
        revert CallerAccessDenied();
    }

    /**
     * @notice  - update the admin address
     * @dev     - Only callable by `admin`.
     * @param newAdmin - Address of the new `admin`.
     * @return - True if the admin address was successfully updated
     */
    function updateAdmin(address newAdmin) external returns (bool) {
        _onlyAdmin();
        if (newAdmin == address(0)) {
            revert CannotBeZeroAddress();
        }
        admin = newAdmin;
        emit UpdateAdmin(newAdmin);
        return true;
    }

    /**
     * @notice  - Adds or remove operator approval for msg.sender.
     * @param operator - Address of the operator to add or remove.
     * @param approved - True to add operator, false to remove operator.
     * @return         - True if the operator was successfully added or removed.
     */
    function setFactoryOperator(address operator, bool approved) public returns (bool) {
        _onlyAdmin();
        factoryOperators[operator] = approved;
        emit FactoryOperatorSet(msg.sender, operator, approved);
        return true;
    }

    /**
     * @notice  - Deploys a new LendingVault and CreditStrategy contract.
     * @param params          - The deployment parameters for the LendingVault and CreditStrategy. See ILendingVaultFactory.
     * @return creditStrategy - Address of the newly deployed CreditStrategy contract.
     * @return lendingVault   - Address of the newly deployed LendingVault contract.
     */
    function deployLendingVault(DeploymentParams memory params) external returns (address, address) {
        _onlyAdminOrOperator();
        address lendingVault = ERC7540Factory(factory).deployLendingVault(
            params.asset, params.name, params.symbol, params.liquidStrategy
        );
        address creditStrategy = address(
            new CreditStrategy(
                params.asset,
                params.manager,
                params.protocolTreasury,
                params.protocolSplit,
                params.fees,
                params.whitelistEnabled,
                lendingVault
            )
        );

        LendingVault(lendingVault).setCreditStrategy(creditStrategy, params.pausers);

        emit DeployCreditStrategy(
            creditStrategy,
            lendingVault,
            params.manager,
            params.protocolTreasury,
            params.protocolSplit,
            params.whitelistEnabled,
            params.fees.performance,
            params.fees.management
        );
        return (creditStrategy, lendingVault);
    }
}