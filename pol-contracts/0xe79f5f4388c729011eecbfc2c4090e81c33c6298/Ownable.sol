// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0;

contract Ownable {
    address private _owner;

    constructor() {
        _owner = msg.sender;
    }

    function owner() internal view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(msg.sender == _owner, "Ownable: caller is not the owner");
        _;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        if (newOwner != address(0)) {
            _owner = newOwner;
        }
    }

    function _msgSender() internal view returns (address) {
        return msg.sender;
    }
}