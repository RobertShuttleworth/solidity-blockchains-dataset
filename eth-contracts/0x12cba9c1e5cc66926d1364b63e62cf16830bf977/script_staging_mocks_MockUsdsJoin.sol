// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import { IERC20 } from "./lib_forge-std_src_interfaces_IERC20.sol";

import { Ownable } from "./lib_openzeppelin-contracts_contracts_access_Ownable.sol";

contract MockUsdsJoin is Ownable {

    address public immutable vat;
    IERC20  public immutable usds;

    constructor(address owner_, address vat_, address usds_) Ownable(owner_) {
        vat  = vat_;
        usds = IERC20(usds_);
    }

    function join(address, uint256 wad) external onlyOwner {
        usds.transferFrom(msg.sender, address(this), wad);
    }

    function exit(address usr, uint256 wad) external onlyOwner {
        usds.transfer(usr, wad);
    }

    // To fully cover daiJoin abi
    function dai() external view returns (address) {
        return address(usds);
    }

}