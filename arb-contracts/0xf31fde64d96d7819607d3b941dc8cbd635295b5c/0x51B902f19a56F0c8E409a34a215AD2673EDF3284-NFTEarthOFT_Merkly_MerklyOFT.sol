// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./0x51B902f19a56F0c8E409a34a215AD2673EDF3284-NFTEarthOFT_Merkly_OFT.sol";

contract Merkly is OFT {
    uint public fee = 0.0000025 ether;

    constructor(address _layerZeroEndpoint) OFT("qBit", "qBit", _layerZeroEndpoint) {
    //_mint(_msgSender(), 50000 * 10**18);

     }

    function mint(address _to, uint256 _amount) external payable {
        require(_amount * fee <= msg.value, "Not enough ether");
        _mint(_to, _amount * 10 ** decimals());
    }

    function setFee(uint _fee) external onlyOwner {
        fee = _fee;
    }

    function withdraw() public payable onlyOwner {
        (bool success, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        require(success);
    }
}