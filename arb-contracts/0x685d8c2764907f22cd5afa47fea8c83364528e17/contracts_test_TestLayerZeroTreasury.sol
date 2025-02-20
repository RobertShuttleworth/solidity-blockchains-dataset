// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import {Ownable} from "./openzeppelin_contracts_access_Ownable.sol";

contract LayerZeroTreasuryMock is Ownable {
    function withdraw() external onlyOwner {
        //withdraw
    }

    function withdrawAlt() external onlyOwner {
        //withdraw token
    }
}