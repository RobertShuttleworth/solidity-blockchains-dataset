// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import "./openzeppelin_contracts-upgradeable_token_ERC20_ERC20Upgradeable.sol";

contract CollateralPoolToken is ERC20Upgradeable {
    bytes32 private _reserved1;

    bytes32[50] private _gaps;

    function __CollateralPoolToken_init(string memory name_, string memory symbol_) internal onlyInitializing {
        __ERC20_init(name_, symbol_);
    }
}