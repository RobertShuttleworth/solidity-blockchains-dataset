pragma solidity ^0.4.24;

contract BatchTransfer {
    function batchTransfer(address[] _recipients, uint256[] _values) public payable {
        require(_recipients.length == _values.length);

        for (uint256 i = 0; i < _recipients.length; i++) {
            _recipients[i].transfer(_values[i]);
        }
    }
}