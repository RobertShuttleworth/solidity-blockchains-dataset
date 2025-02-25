// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./0x51B902f19a56F0c8E409a34a215AD2673EDF3284-NFTEarthOFT_Merkly_ERC20.sol";
import "./0x51B902f19a56F0c8E409a34a215AD2673EDF3284-NFTEarthOFT_Merkly_IERC165.sol";
import "./0x51B902f19a56F0c8E409a34a215AD2673EDF3284-NFTEarthOFT_Merkly_IOFT.sol";
import "./0x51B902f19a56F0c8E409a34a215AD2673EDF3284-NFTEarthOFT_Merkly_OFTCore.sol";

// override decimal() function is needed
contract OFT is OFTCore, ERC20, IOFT {
    constructor(string memory _name, string memory _symbol, address _lzEndpoint) ERC20(_name, _symbol) OFTCore(_lzEndpoint) {}

    function supportsInterface(bytes4 interfaceId) public view virtual override(OFTCore, IERC165) returns (bool) {
        return interfaceId == type(IOFT).interfaceId || interfaceId == type(IERC20).interfaceId || super.supportsInterface(interfaceId);
    }

    function token() public view virtual override returns (address) {
        return address(this);
    }

    function circulatingSupply() public view virtual override returns (uint) {
        return totalSupply();
    }

    function _debitFrom(address _from, uint16, bytes memory, uint _amount) internal virtual override returns(uint) {
        address spender = _msgSender();
        if (_from != spender) _spendAllowance(_from, spender, _amount);
        _burn(_from, _amount);
        return _amount;
    }

    function _creditTo(uint16, address _toAddress, uint _amount) internal virtual override returns(uint) {
        _mint(_toAddress, _amount);
        return _amount;
    }
}