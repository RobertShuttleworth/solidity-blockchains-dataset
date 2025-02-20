//SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.20;

import "./contracts_v1-cmtat-tokenization_interfaces_draft-IERC1404_draft-IERC1404.sol";
import "./contracts_v1-cmtat-tokenization_interfaces_draft-IERC1404_draft-IERC1404EnumCode.sol";

interface IERC1404Wrapper is IERC1404, IERC1404EnumCode  {

    /**
     * @dev Returns true if the transfer is valid, and false otherwise.
     */
    function validateTransfer(
        address _from,
        address _to,
        uint256 _amount
    ) external view returns (bool isValid);
}