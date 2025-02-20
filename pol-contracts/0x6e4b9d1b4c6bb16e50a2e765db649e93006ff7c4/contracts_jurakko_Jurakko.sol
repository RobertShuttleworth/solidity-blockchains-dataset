// SPDX-License-Identifier: MIT
// solhint-disable-next-line compiler-version
pragma solidity ^0.8.0;

import "./openzeppelin_contracts-0.8_token_ERC20_ERC20.sol";
import "./openzeppelin_contracts-0.8_token_ERC20_extensions_ERC20Burnable.sol";
import "./openzeppelin_contracts-0.8_access_Ownable.sol";

/**
 * @title JurakkoToken
 * @dev Jurakko is an ERC20 Token.
 * Based on;
 * https://docs.openzeppelin.com/contracts/2.x/api/token/erc20
 * https://docs.openzeppelin.com/contracts/2.x/api/token/erc20#ERC20Burnable
 */
contract Jurakko is ERC20, ERC20Burnable, Ownable {
    /**
     * @dev Constructor that gives msg.sender all of existing tokens.
     */
    constructor(uint256 amount) ERC20("Jurakko", "JKO") {
        _transferOwnership(_msgSender());
        _mint(_msgSender(), amount * (1 ether));
    }
}