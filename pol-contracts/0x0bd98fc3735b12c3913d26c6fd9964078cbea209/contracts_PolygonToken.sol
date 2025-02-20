// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./openzeppelin_contracts_token_ERC20_ERC20.sol";
import "./openzeppelin_contracts_access_Ownable.sol";

contract PolygonToken is ERC20, Ownable {
    constructor() ERC20("Polygon", "POL") Ownable(msg.sender) {
        _mint(msg.sender, 100000 * 10 ** decimals());
    }
}