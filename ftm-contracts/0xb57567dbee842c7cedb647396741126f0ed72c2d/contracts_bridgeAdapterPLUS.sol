// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.22;

import { OFTAdapter } from "./layerzerolabs_oft-evm_contracts_OFTAdapter.sol";
import { Ownable } from "./openzeppelin_contracts_access_Ownable.sol";

/// @notice OFTAdapter uses a deployed ERC-20 token and safeERC20 to interact with the OFTCore contract.
contract PlusOFTAdapter is OFTAdapter {
    constructor(
        address _token,
        address _lzEndpoint,
        address _owner
    ) OFTAdapter(_token, _lzEndpoint, _owner) Ownable(_owner) {}
}