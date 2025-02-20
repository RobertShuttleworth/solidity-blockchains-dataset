// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {LendingVault} from "./contracts_LendingVault.sol";
import {IERC7540Factory} from "./contracts_interfaces_IERC7540Factory.sol";

/**
 * @title  - ERC7540Factory
 * @author - Credit Cooperative
 * @notice - The ERC7540Factory contract the LendingVaultFactory contract to deploy new LendingVault contracts.
 * @dev    - Only the deployer of the ERC7540Factory can set the LendingVaultFactory contract.
 */
contract ERC7540Factory is IERC7540Factory {
    address public deployer;
    address public lendingVaultFactory;

    constructor() {
        deployer = msg.sender;
    }

    /**
     * @notice - set the lending vault factory address
     * @dev    - only callable once by the contract `deployer`
     * @param _lendingVaultFactory - the address to set as the lending vault factory
     * @return - True if the lending vault factory address was successfully set
     */
    function setLendingVaultFactory(address _lendingVaultFactory) external returns (bool) {
        if (msg.sender != deployer) {
            revert CallerAccessDenied();
        }
        if (lendingVaultFactory != address(0)) {
            revert LendingVaultFactoryAlreadySet();
        }
        lendingVaultFactory = _lendingVaultFactory;
        emit SetLendingVaultFactory(_lendingVaultFactory);
        return true;
    }

    /**
     * @notice  - Deploys a new LendingVault contract.
     * @param asset           - Address of the native asset of the LendingVault.
     * @param name            - Name of the LendingVault contract.
     * @param symbol          - Symbol of the LendingVault contract.
     * @param liquidStrategy  - Address of the liquidStrategy contract to be used by the LendingVault.
     * @return lendingVault   - Address of the newly deployed LendingVault contract.
     */
    function deployLendingVault(
        address asset,
        string memory name,
        string memory symbol,
        address liquidStrategy
    ) external returns (address) {
        if (msg.sender != lendingVaultFactory) {
            revert CallerAccessDenied();
        }

        // deploy a new LendingVault contract
        address lendingVault =
            address(new LendingVault(asset, name, symbol, liquidStrategy, msg.sender));
        emit DeployLendingVault(lendingVault, asset, name, symbol);
        return lendingVault;
    }
}