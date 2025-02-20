// SPDX-License-Identifier: FRAKTAL-PROTOCOL
pragma solidity ^0.8.4;


import { LibDiamond } from "./contracts_shared_libraries_LibDiamond.sol";
import { IERC173 } from "./contracts_shared_interfaces_IERC173.sol";

contract OwnershipFacet is IERC173 {
    function transferOwnership(address _newOwner) external override {
        LibDiamond.enforceIsContractOwner();
        LibDiamond.setContractOwner(_newOwner);
    }

    function owner() external override view returns (address owner_) {
        owner_ = LibDiamond.contractOwner();
    }
}