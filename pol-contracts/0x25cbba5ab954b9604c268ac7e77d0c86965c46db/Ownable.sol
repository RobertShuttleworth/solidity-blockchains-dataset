// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.7;

import "./Context.sol";

contract Ownable is Context {
    address public _owner;

    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
    }

    function ownerAddress() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _owner = newOwner;
    }
}
