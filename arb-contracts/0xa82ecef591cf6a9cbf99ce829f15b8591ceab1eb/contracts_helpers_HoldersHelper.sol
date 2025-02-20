// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "./contracts_helpers_ERC20Helper.sol";

contract HoldersHelper is ERC20Helper {
    struct Holder {
        address token;
        address holder;
        uint256 balance;
        bool isContract;
    }

    function isContract(address _addr) internal view returns (bool result) {
        uint256 size;
        assembly {
            size := extcodesize(_addr)
        }
        result = size > 0;
    }

    function getSingleTokenHoldersInfo(address _token, address[] calldata _holders)
        public
        view
        returns (uint256, Holder[] memory)
    {
        Holder[] memory holders = new Holder[](_holders.length);
        for (uint256 i = 0; i < _holders.length; i++) {
            bool _isContract = isContract(_holders[i]);
            uint256 _balance = getBalance(_token, _holders[i]);
            holders[i] = Holder(_token, _holders[i], _balance, _isContract);
        }
        return (block.number, holders);
    }

    function pickHolder(address _token, uint256 _sellAmount, address[] calldata _holders)
        public
        view
        returns (address holder)
    {
        for (uint256 i = 0; i < _holders.length; i++) {
            holder = _holders[i];
            uint256 _balance = getBalance(_token, holder);
            if (_balance >= _sellAmount) {
                return holder;
            }
        }
        return address(0);
    }

    function getMultipleTokenHoldersInfo(address[] calldata _tokens, address[][] calldata _holders)
        public
        view
        returns (uint256, Holder[] memory)
    {
        require(_tokens.length == _holders.length, "!length");
        uint256 outLen;
        for (uint256 i = 0; i < _tokens.length; i++) {
            outLen += _holders[i].length;
        }

        Holder[] memory holders = new Holder[](outLen);
        uint256 counter;
        for (uint256 j = 0; j < _tokens.length; j++) {
            for (uint256 i = 0; i < _holders[j].length; i++) {
                bool _isContract = isContract(_holders[j][i]);
                uint256 _balance = getBalance(_tokens[j], _holders[j][i]);
                holders[counter] = Holder(_tokens[j], _holders[j][i], _balance, _isContract);
                counter += 1;
            }
        }
        return (block.number, holders);
    }
}