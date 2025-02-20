// SPDX-License-Identifier: GPL-3.0
// Copyright: https://github.com/credit-cooperative/Line-Of-Credit-v2/blob/master/COPYRIGHT.md

pragma solidity 0.8.25;

import {ILineFactory} from "./lib_Line-Of-Credit-v2_contracts_interfaces_ILineFactory.sol";
import {IEscrowFactory} from "./lib_Line-Of-Credit-v2_contracts_interfaces_IEscrowFactory.sol";
import {ISpigotFactory} from "./lib_Line-Of-Credit-v2_contracts_interfaces_ISpigotFactory.sol";

import {LineFactoryLib} from "./lib_Line-Of-Credit-v2_contracts_utils_LineFactoryLib.sol";
import {SecuredLine} from "./lib_Line-Of-Credit-v2_contracts_modules_credit_SecuredLine.sol";
import {BeneficiaryData} from "./lib_Line-Of-Credit-v2_contracts_utils_DiscreteDistribution.sol";

/**
 * @title   - LineFactory
 * @author  - Credit Cooperative
 * @notice  - Factory contract to deploy SecuredLine, Spigot, and Escrow contracts.
 * @dev     - Have immutable default values for Credit Cooperative system external dependencies.
 */
contract LineFactory is ILineFactory {
    IEscrowFactory immutable escrowFactory;
    ISpigotFactory immutable spigotFactory;
    BeneficiaryData defaultBeneficiary;

    /**
     * Defaults
     */
    uint8 constant MAX_SPLIT = 100; // max % to take
    uint96 constant defaultAllocation = 10000;

    address public admin;
    address public protocolTreasury;

    mapping(address => bool) public factoryOperators;
    mapping(address => bool) public isLine;

    address public immutable networkToken; // on mainnet, this would be weth
    address public immutable oracle;
    address public immutable uniV3Oracle;
    address payable public swapTarget;
    
    address public immutable securedLineTemplate;
    address public immutable creditPositionToken;

    constructor(
        address escrowFactory_,
        address spigotFactory_,
        address admin_,
        address protocolTreasury_,
        address oracle_,
        address payable swapTarget_,
        address networkToken_,
        address creditPositionToken_
    ) {
        if (
            admin_ == address(0) || protocolTreasury_ == address(0) || escrowFactory_ == address(0)
                || spigotFactory_ == address(0) || oracle_ == address(0) || swapTarget_ == address(0)
                || networkToken_ == address(0)
        ) {
            revert CannotBeZeroAddress();
        }

        escrowFactory = IEscrowFactory(escrowFactory_);
        spigotFactory = ISpigotFactory(spigotFactory_);

        admin = admin_;
        factoryOperators[msg.sender] = true; // set the deployer as an operator
        protocolTreasury = protocolTreasury_;

        oracle = oracle_;
        swapTarget = swapTarget_;
        networkToken = networkToken_;

        creditPositionToken = creditPositionToken_;
        securedLineTemplate = address(new SecuredLine(oracle_));
    }

    function _onlyAdmin() internal view {
        if (msg.sender != admin) {
            _unauthorized();
        }
    }

    function _onlyAdminOrOperator() internal view {
        if (msg.sender != admin && factoryOperators[msg.sender] != true) {
            _unauthorized();
        }
    }

    function _unauthorized() private pure {
        revert CallerAccessDenied();
    }

    /**
     * @notice - Deploys an Escrow module that can be used in a LineOfCredit
     * @dev    - Only callable by admin or factory operators.
     * @param minCRatio          - the minimum collateral ratio required for the Escrow
     * @param owner              - owner of the Escrow
     * @param borrower           - borrower of the Escrow
     * @param smartEscrowParams  - parameters for configuring an Escrow or SmartEscrow contract
     * @return module   - the address of the deployed Escrow module
     */
    function deployEscrow(
        uint32 minCRatio,
        address owner,
        address borrower,
        address uniV3Manager,
        SmartEscrowParams memory smartEscrowParams
    ) public returns (address module) {
        _onlyAdminOrOperator();
        module = escrowFactory.deployEscrow(minCRatio, owner, borrower, uniV3Manager, smartEscrowParams);
    }

    /**
     * @notice - Deploys a Spigot module that can be used in a LineOfCredit
     * @dev    - Only callable by admin or factory operators.
     * @param operator  - address of the operator for the Spigot
     * @return module   - address of the deployed Spigot module
     */
    function deploySpigot(address operator) public returns (address) {
        _onlyAdminOrOperator();
        _setDefaultBeneficiaryDataForDeployment();
        return spigotFactory.deploySpigot(networkToken, defaultBeneficiary, operator);
    }

    /**
     * @notice - Deploy a new SecuredLine contract with a given set of parameters.
     * @dev    - Only callable by admin or factory operators.
     * @param coreParams - Core parameters for the new SecuredLine contract.
     * @return line      - The address of the newly deployed SecuredLine.
     */
    function deploySecuredLineWithConfig(CoreLineParams calldata coreParams) external returns (address line) {

        _onlyAdminOrOperator();
        // deploy new modules
        address s = deploySpigot(coreParams.operator);
        
        address e = deployEscrow(
            coreParams.minCratio,
            address(this),
            coreParams.borrower,
            coreParams.uniV3Manager,
            coreParams.smartEscrowParams
        );

        EscrowTypes escrowType = coreParams.smartEscrowParams.escrowType;

        LineFactoryLib.SecuredLineDeploymentParams memory params;
        {
            params.template = securedLineTemplate;
            params.oracle = oracle;
            params.borrower = escrowType == EscrowTypes.ESCROW ? coreParams.borrower : address(e);
            params.uniV3Manager = coreParams.uniV3Manager;
            params.recoveryEnabled = coreParams.recoveryEnabled;
            params.s = s;
            params.e = e;
            params.c = creditPositionToken;
            params.admin = admin;
            params.fees = coreParams.fees;
        }

        line = LineFactoryLib.deploySecuredLine(params);

        // give modules from address(this) to line so we can run line.init()
        LineFactoryLib.transferModulesToLine(address(line), s, e);
        isLine[line] = true;

        emit DeployedSecuredLine(address(line), s, e, creditPositionToken, swapTarget);
    }

    /**
     * @notice - update the admin address
     * @dev    - only the current admin can call this function
     * @param newAdmin - the new admin address
     */
    function updateAdmin(address newAdmin) external returns (bool) {
        _onlyAdmin();
        require(newAdmin != address(0), "admin cannot be zero address");
        admin = newAdmin;
        emit UpdateAdmin(newAdmin);
        return true;
    }

    /**
     * @notice - update the protocol treasury address
     * @dev    - only the current protocol treasury can call this function
     * @param newProtocolTreasury - the new protocol treasury address
     */
    function updateProtocolTreasury(address newProtocolTreasury) external returns (bool) {
        if (msg.sender != protocolTreasury) {
            revert CallerAccessDenied();
        }
        require(newProtocolTreasury != address(0), "treasury cannot be zero address");
        protocolTreasury = newProtocolTreasury;
        emit UpdateProtocolTreasury(newProtocolTreasury);
        return true;
    }

    /**
     * @notice - update the swap target address
     * @dev    - only the current admin can call this function
     * @param newSwapTarget - the new swap target address
     * @return              - true if the swap target was successfully updated
     */

    function updateSwapTarget(address payable newSwapTarget) external returns (bool) {
        _onlyAdmin();
        require(newSwapTarget != address(0), "swap target cannot be zero address");
        swapTarget = newSwapTarget;
        emit UpdateSwapTarget(newSwapTarget);
        return true;
    }

    /**
     * @notice  - Adds or remove operator approval for msg.sender.
     * @param operator - The address of the operator to add or remove.
     * @param approved - True to add operator, false to remove operator.
     * @return         - True if the operator was successfully added or removed.
     */
    function setFactoryOperator(address operator, bool approved) external returns (bool) {
        _onlyAdmin();
        factoryOperators[operator] = approved;
        emit FactoryOperatorSet(msg.sender, operator, approved);
        return true;
    }


    function _setDefaultBeneficiaryDataForDeployment() internal {
        defaultBeneficiary.beneficiary = address(this);
        defaultBeneficiary.allocation = defaultAllocation;
    }

    /**
     * @notice - Get the address of the EscrowFactory.
     * @return - The address of the EscrowFactory.
     */
    function getEscrowFactory() external view returns (address) {
        return address(escrowFactory);
    }

    /**
     * @notice - Get the address of the SpigotFactory.
     * @return - The address of the SpigotFactory.
     */
    function getSpigotFactory() external view returns (address) {
        return address(spigotFactory);
    }
}