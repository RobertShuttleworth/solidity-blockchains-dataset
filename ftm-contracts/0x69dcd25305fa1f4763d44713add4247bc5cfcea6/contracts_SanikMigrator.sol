// SPDX-License-Identifier: MIT
pragma solidity ^0.8.x;
import "./openzeppelin_contracts_interfaces_IERC20.sol";

contract SanikMigrator{
    address public owner;
    IERC20 public constant SANIK = IERC20(0x73E30eb2e469cc542d86397bECA97Ea6547e1cA7);

    mapping(address => uint256) migratedAmount;

    event SanikMigrated(address,uint256);

    function migrate() external{
        uint256 amount = SANIK.balanceOf(msg.sender);
        require(amount != 0, "Poor");
        SANIK.transferFrom(msg.sender, address(this), amount);
        migratedAmount[msg.sender] += amount;
        emit SanikMigrated(msg.sender,amount);
    }

    function extract() external{
        require(msg.sender == owner, "!retarded");
        SANIK.transfer(owner,SANIK.balanceOf(address(this)));
    }
}