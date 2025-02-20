// SPDX-License-Identifier: None
pragma solidity ^0.8.18;
import {IBaseComboOption} from "./contracts_interfaces_IBaseComboOption.sol";

abstract contract BaseComboOption is IBaseComboOption {  
    // name of the combo option
    string public comboOptionName;

    bool immutable optionsTypeIsCall;

    mapping(address owner => mapping(bytes32 comboOptionPoolKeyHash => int256))
        public usersBalances;

    bool unlocked;
    modifier lock() {
        if (!unlocked) revert LOK();
        unlocked = false;
        _;
        unlocked = true;
    }

    function checkOptionType(bool isCall) internal view {
        if (isCall != optionsTypeIsCall) revert incorrectOptionType();
    }

    constructor(string memory _comboOptionName, bool _optionsTypeIsCall) {
        unlocked = true;
        comboOptionName = _comboOptionName;
        optionsTypeIsCall = _optionsTypeIsCall;
    }
}