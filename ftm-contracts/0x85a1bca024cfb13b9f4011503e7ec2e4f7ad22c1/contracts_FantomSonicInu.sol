// ███████╗ █████╗ ███╗   ██╗████████╗ ██████╗ ███╗   ███╗███████╗ ██████╗ ███╗   ██╗██╗ ██████╗██╗███╗   ██╗██╗   ██╗
// ██╔════╝██╔══██╗████╗  ██║╚══██╔══╝██╔═══██╗████╗ ████║██╔════╝██╔═══██╗████╗  ██║██║██╔════╝██║████╗  ██║██║   ██║
// █████╗  ███████║██╔██╗ ██║   ██║   ██║   ██║██╔████╔██║███████╗██║   ██║██╔██╗ ██║██║██║     ██║██╔██╗ ██║██║   ██║
// ██╔══╝  ██╔══██║██║╚██╗██║   ██║   ██║   ██║██║╚██╔╝██║╚════██║██║   ██║██║╚██╗██║██║██║     ██║██║╚██╗██║██║   ██║
// ██║     ██║  ██║██║ ╚████║   ██║   ╚██████╔╝██║ ╚═╝ ██║███████║╚██████╔╝██║ ╚████║██║╚██████╗██║██║ ╚████║╚██████╔╝
// ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═══╝   ╚═╝    ╚═════╝ ╚═╝     ╚═╝╚══════╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝ ╚═════╝╚═╝╚═╝  ╚═══╝ ╚═════╝
// Believe in Sonic $S , Believe in $fSONIC.. Gotta go fast !

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./openzeppelin_contracts_token_ERC20_ERC20.sol";
import "./openzeppelin_contracts_access_Ownable.sol";

contract FantomSonicInu is ERC20, Ownable {
    event Burn(address indexed burner, uint256 amount);

    constructor(
        address initialOwner,
        uint256 totalSupply_
    ) ERC20("FantomSonicInu", "fSONIC") Ownable(initialOwner) {
        _mint(initialOwner, totalSupply_);
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
        emit Burn(msg.sender, amount);
    }
}