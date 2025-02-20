// SPDX-License-Identifier: None
pragma solidity ^0.8.18;

// import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

library AddressApprovalUtils {

    function addAddresses(
        mapping(address => bool) storage self,
        address[] memory addressForApprove
    ) internal {
        for (uint256 i = 0; i < addressForApprove.length; i++) {
            require(addressForApprove[i] != address(0), "ZT");
            self[addressForApprove[i]] = true;
        }
    }

    function removeAddresses(
        mapping(address => bool) storage self,
        address[] memory addressForRemove
    ) internal {
        for (uint256 i = 0; i < addressForRemove.length; i++) {
            self[addressForRemove[i]] = false;
        }
    }
}