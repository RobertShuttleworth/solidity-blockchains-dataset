// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "./external_openzeppelin_contracts_proxy_transparent_TransparentUpgradeableProxy.sol";
import "./external_openzeppelin_contracts_proxy_transparent_ProxyAdmin.sol";
import "./src_tokens_clToken.sol";

contract TokenFactory {
    // events
    event CLTokenDeployed(address indexed clToken, address indexed proxyAdmin, address indexed clTokenImpl);

    function deployCLToken(
        string memory name,
        string memory symbol,
        address owner,
        address _pauser,
        address _clTokenAdmin
    ) external returns (address) {
        // Deploy the CLToken implementation
        CLToken clTokenImpl = new CLToken();

        // Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(CLToken.initialize.selector, name, symbol, owner, _pauser);

        // Deploy the TransparentUpgradeableProxy which deploys the proxyAdmin as well
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(clTokenImpl),
            _clTokenAdmin, // set the owner of proxyadmin
            initData
        );

        // Emit event
        emit CLTokenDeployed(address(proxy), ERC1967Utils.getAdmin(), address(clTokenImpl));

        // Return the address of the proxy, which is the address users will interact with
        return address(proxy);
    }
}