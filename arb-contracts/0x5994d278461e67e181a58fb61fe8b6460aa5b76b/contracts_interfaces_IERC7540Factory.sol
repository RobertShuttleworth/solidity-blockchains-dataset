// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface IERC7540Factory {
    event SetLendingVaultFactory(address lendingVaultFactory);
    event DeployLendingVault(address indexed lendingVault, address indexed asset, string name, string symbol);

    error CallerAccessDenied();
    error LendingVaultFactoryAlreadySet();

    function deployLendingVault(
        address asset,
        string memory name,
        string memory symbol,
        address liquidStrategy
    ) external returns (address);
}