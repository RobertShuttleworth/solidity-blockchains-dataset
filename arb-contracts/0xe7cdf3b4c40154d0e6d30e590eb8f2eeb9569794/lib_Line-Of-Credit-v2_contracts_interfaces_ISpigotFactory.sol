// SPDX-License-Identifier: GPL-3.0
// Copyright: https://github.com/credit-cooperative/Line-Of-Credit-v2/blob/master/COPYRIGHT.md

pragma solidity ^0.8.25;

import {ILineFactory} from "./lib_Line-Of-Credit-v2_contracts_interfaces_ILineFactory.sol";
import {BeneficiaryData} from "./lib_Line-Of-Credit-v2_contracts_utils_DiscreteDistribution.sol";

interface ISpigotFactory {
    event DeployedSpigot(address indexed deployedAt, address indexed owner, address operator);
    event SetLineFactory(address lineFactory);

    error CallerAccessDenied();
    error LineFactoryAlreadySet();

    function spigotTemplate() external view returns (address);

    function deploySpigot(address weth, BeneficiaryData memory defaultBeneficiary, address operator)
        external
        returns (address);
}