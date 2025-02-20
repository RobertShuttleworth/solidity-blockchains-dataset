// SPDX-License-Identifier: GPL-3.0
// Copyright: https://github.com/credit-cooperative/Line-Of-Credit-v2/blob/master/COPYRIGHT.md

pragma solidity 0.8.25;

import {ISpigotFactory} from "./lib_Line-Of-Credit-v2_contracts_interfaces_ISpigotFactory.sol";
import {Clones} from "./lib_openzeppelin-contracts_contracts_proxy_Clones.sol";
import {ISpigot} from "./lib_Line-Of-Credit-v2_contracts_interfaces_ISpigot.sol";

import {Spigot} from "./lib_Line-Of-Credit-v2_contracts_modules_spigot_Spigot.sol";
import {BeneficiaryData} from "./lib_Line-Of-Credit-v2_contracts_utils_DiscreteDistribution.sol";

/**
 * @title   - SpigotFactory
 * @author  - Credit Cooperative
 * @notice  - Factory contract to deploy Spigot contracts.
 * @dev     - Only LineFactory can deploy Spigot contracts.
 */

contract SpigotFactory is ISpigotFactory {
    using Clones for address;

    address public deployer;
    address public lineFactory;

    address public immutable spigotTemplate;

    constructor() {
        deployer = msg.sender;

        spigotTemplate = address(new Spigot());
    }

    /**
     * @notice - set the line factory address
     * @dev    - only the contract deployer can call this function
     * @param _lineFactory - the address to set as the line factory
     * @return             - true if the line factory address was successfully set
     */
    function setLineFactory(address _lineFactory) external returns (bool) {
        if (msg.sender != deployer) {
            revert CallerAccessDenied();
        }
        if (lineFactory != address(0)) {
            revert LineFactoryAlreadySet();
        }
        lineFactory = _lineFactory;
        emit SetLineFactory(_lineFactory);
        return true;
    }

    /**
     * @notice - Deploys a Spigot module that can be used in a LineOfCredit
     * @param weth               - address of the WETH contract for the network the contract is being deloyed
     * @param defaultBeneficiary - the default beneficiary data for the Spigot
     * @param operator           - address of the operator for the Spigot
     * @return module            - address of the deployed Spigot  module
     */
    function deploySpigot(address weth, BeneficiaryData memory defaultBeneficiary, address operator)
        external
        returns (address module)
    {
        if (msg.sender != lineFactory) {
            revert CallerAccessDenied();
        }

        // Clone the template
        module = spigotTemplate.clone();

        // Initialize the Iclone since we couldn't call a constructor
        ISpigot(module).initializeFromFactory(operator, defaultBeneficiary, weth);
        emit DeployedSpigot(module, defaultBeneficiary.beneficiary, operator);
    }
}