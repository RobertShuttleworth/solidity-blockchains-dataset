// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.7.6;
pragma abicoder v2;

import "./contracts_interfaces_IFlashWallet.sol";

/// @title  Flash Wallet
/// @notice Router that aggregates liquidity from different sources and aggregators.
///         The router is the entry point of the swap. All token allowance are given to the router.
/// @author MetaDexa.io
contract FlashWallet is IFlashWallet {

    address public override immutable owner;

    constructor() {
        // The deployer is the owner.
        owner = msg.sender;
    }

    function executeDelegateCall(address payable target, bytes calldata callData) 
     external payable  override onlyOwner returns (bytes memory resultData)
    {
        bool success;
        (success, resultData) = target.delegatecall(callData);
        if (!success) {
            revert(abi.decode(resultData, (string)));
        }
    }

    /// @dev Receives ether from swaps
    receive() external override payable {}

    modifier onlyOwner() virtual {
     require(msg.sender == owner, "FW_NA");
     _;
    }
}