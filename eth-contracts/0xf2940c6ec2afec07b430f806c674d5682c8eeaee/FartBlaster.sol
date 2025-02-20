// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./openzeppelin_contracts_token_ERC20_ERC20.sol";
import "./openzeppelin_contracts_access_Ownable.sol";

interface FartCoin {
    function balanceOf(address owner) external returns (uint256);
    function transfer(address to, uint256 value) external;
    function GetFreeTokens() external;
    function SendFart(string memory message) external;
}

contract TempAddr is Ownable(msg.sender) {
    function burnFarts(FartCoin fc) public onlyOwner {
        fc.GetFreeTokens();
        fc.transfer(0x000000000000000000000000000000000000dEaD, 10);
    }
}

contract FartBlaster {

    FartCoin fc = FartCoin(0x93715112138dD0265a3888eb7458BB7BF3fF7C3e);

    function fartBlast(string memory message) public {
        
        require(fc.balanceOf(msg.sender) >= 10, "You don't have enough farts");
        require(bytes(message).length < 100, "Message too long");

        for (uint256 i = 0; i < 10; i++) {
            fc.SendFart(message);
        }
        address tempAddr = address(new TempAddr());
        TempAddr(tempAddr).burnFarts(fc);
    }
}