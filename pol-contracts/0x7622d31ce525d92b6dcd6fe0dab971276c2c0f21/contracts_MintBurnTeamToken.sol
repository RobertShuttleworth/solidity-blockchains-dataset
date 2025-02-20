// SPDX-License-Identifier: MIT

pragma solidity >=0.6.2 <0.8.0;


import "./contracts_Ownable.sol";
import "./contracts_TeamToken.sol";
import "./contracts_BurnableToken.sol";

contract MintBurnTeamToken is TeamToken, ERC20Burnable, Ownable {
    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals,
        uint256 supply,
        address owner,
        address feeWallet
    ) 
    public
    TeamToken(name, symbol, decimals, supply, owner, feeWallet) 
    {

    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}