// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {IManagedPool} from "./balancer-labs_v2-interfaces_contracts_pool-utils_IManagedPool.sol";
import {IERC20} from "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import {IVault, IERC20 as BALANCER_ERC20} from "./balancer-labs_v2-interfaces_contracts_vault_IVault.sol";

import {ComposablePoolLib} from "./src_libraries_ComposablePoolLib.sol";
import {IBalancerPoolToken} from "./src_interfaces_balancer_IBalancerPoolToken.sol";
import {BaseGauge} from "./src_gauges_BaseGauge.sol";

contract BalancerGauge is BaseGauge {
    constructor(address _abra, address _token, uint256 _rewardOverlapWindow)
        BaseGauge(_abra, _token, _rewardOverlapWindow)
    {}

    function initialize(string memory name_, string memory symbol_, address authority_) public initializer {
        __BaseGauge_init(name_, symbol_, authority_);
    }

    function yieldSources() external view override returns (address[] memory sources) {
        IVault vault = IVault(IBalancerPoolToken(address(UNDERLYING)).getVault());
        bytes32 poolId = IManagedPool(UNDERLYING).getPoolId();

        (BALANCER_ERC20[] memory tokens,,) = vault.getPoolTokens(poolId);
        IERC20[] memory wrappers = ComposablePoolLib.dropBptFromTokens(tokens); // mutates tokens variable
        assembly {
            sources := wrappers // type casting
        }
    }
}