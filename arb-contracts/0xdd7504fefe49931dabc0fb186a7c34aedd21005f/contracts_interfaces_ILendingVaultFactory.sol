// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

// Local imports
import {FeeManager} from "./contracts_strategies_credit_FeeManager.sol";
import {IERC7540Factory} from "./contracts_interfaces_IERC7540Factory.sol";

interface ILendingVaultFactory {
    struct DeploymentParams {
        address asset;
        string name;
        string symbol;
        address manager;
        address protocolTreasury;
        uint8 protocolSplit;
        bool whitelistEnabled;
        FeeManager.Fees fees;
        address liquidStrategy;
        address[] pausers;
    }

    event DeployCreditStrategy(
        address indexed creditStrategy,
        address indexed lendingVault,
        address indexed manager,
        address protocolTreasury,
        uint8 protocolSplit,
        bool whitelistEnabled,
        uint16 performanceFee,
        uint16 managementFee
    );

    event UpdateAdmin(address indexed admin);
    event FactoryOperatorSet(address indexed sender, address indexed operator, bool indexed approved);

    error CannotBeZeroAddress();
    error CallerAccessDenied();

    function admin() external view returns (address);
    function factoryOperators(address operator) external view returns (bool);
    function updateAdmin(address newAdmin) external returns (bool);
    function setFactoryOperator(address operator, bool approved) external returns (bool);
    function deployLendingVault(DeploymentParams memory params) external returns (address, address);
}