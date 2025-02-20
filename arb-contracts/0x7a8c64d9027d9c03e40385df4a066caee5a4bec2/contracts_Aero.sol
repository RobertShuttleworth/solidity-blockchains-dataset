// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {IAero} from "./contracts_interfaces_IAero.sol";
import {ERC20} from "./lib_openzeppelin-contracts_contracts_token_ERC20_ERC20.sol";
import {ERC20Permit} from "./lib_openzeppelin-contracts_contracts_token_ERC20_extensions_ERC20Permit.sol";

/// @title Aero
/// @author velodrome.finance
/// @notice The native token in the Protocol ecosystem
/// @dev Emitted by the Minter
contract Aero is IAero, ERC20Permit {
    address public minter;
    address private owner;

    constructor() ERC20("Aerodrome", "AERO") ERC20Permit("Aerodrome") {
        minter = msg.sender;
        owner = msg.sender;
    }

    /// @dev No checks as its meant to be once off to set minting rights to BaseV1 Minter
    function setMinter(address _minter) external {
        if (msg.sender != minter) revert NotMinter();
        minter = _minter;
    }

    function mint(address account, uint256 amount) external returns (bool) {
        if (msg.sender != minter) revert NotMinter();
        _mint(account, amount);
        return true;
    }
}