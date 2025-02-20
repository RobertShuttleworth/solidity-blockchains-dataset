// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0;
import "./openzeppelin_contracts_token_ERC20_extensions_ERC4626.sol";
import "./openzeppelin_contracts_token_ERC20_ERC20.sol";
import "./openzeppelin_contracts_interfaces_IERC20.sol";

contract ERC4626Test is ERC4626 {
    constructor(
        address _asset,
        string memory _name,
        string memory _symbol
    ) ERC4626(IERC20(_asset)) ERC20(_name, _symbol) {}
}