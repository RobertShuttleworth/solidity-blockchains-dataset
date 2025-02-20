// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.20;

import "./openzeppelin_contracts_token_ERC20_ERC20.sol";
import "./openzeppelin_contracts_token_ERC20_extensions_ERC20Burnable.sol";
import "./openzeppelin_contracts_access_Ownable.sol";
import "./contracts_utils_Registry.sol";

contract Bean is Ownable(msg.sender), ERC20, ERC20Burnable {
    // =============================================================
    //                           VARIABLES
    // =============================================================
    mapping(address => uint256) public totalRewarded;
    mapping(address => bool) public isRegistered;
    mapping(address => uint256) public currentTotalInvested;

    // =============================================================
    //                          CONSTRUCTOR
    // =============================================================

    constructor(uint256 _initSupply) ERC20("BEAN", "BEAN") {
        _mint(msg.sender, _initSupply);
    }

    // =============================================================
    //                          MAIN FUNCTIONS
    // =============================================================
    function mint(address _user, uint256 _amount) public {
        require(isRegistered[msg.sender], "Bean:: Not authorized");
        _mint(_user, _amount);
    }

    function addTotalRewarded(uint256 _amount, address _address) external {
        require(isRegistered[msg.sender], "Bean:: Not authorized");
        totalRewarded[_address] += _amount;
    }

    // =============================================================
    //                            SETTERS
    // =============================================================
    function setRegisteredContracts(address _contract) external onlyOwner {
        isRegistered[_contract] = true;
    }

    // =============================================================
    //                            GETTER
    // =============================================================

    function getTotalRewarded(
        address _address
    ) external view returns (uint256) {
        return totalRewarded[_address];
    }
}