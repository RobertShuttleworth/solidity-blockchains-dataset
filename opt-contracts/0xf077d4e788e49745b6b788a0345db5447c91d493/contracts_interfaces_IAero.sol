// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "./lib_openzeppelin-contracts_contracts_token_ERC20_IERC20.sol";

interface IAero is IERC20 {
    error NotMinter();
    error NotOwner();

    /// @notice Mint an amount of tokens to an account
    ///         Only callable by Minter.sol
    /// @return True if success
    function mint(address account, uint256 amount) external returns (bool);

    /// @notice Address of Minter.sol
    function minter() external view returns (address);
}