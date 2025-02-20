//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
pragma experimental ABIEncoderV2;

import "./opengsn_contracts_src_BasePaymaster.sol";

contract GigabitEscrowPaymaster is BasePaymaster {

    bool public useTargetWhitelist;
    bool public useRejectOnRecipientRevert;    
    mapping(address => bool) public targetWhitelist;
    mapping(address => bool) public managerWhitelist;

    modifier onlyManager() {
        if (managerWhitelist[_msgSender()] == false &&
            managerWhitelist[tx.origin] == false // We have custom logic here to allow for tx.origin to be used, as we instantiate from another contract
        ){
            revert("only manager can call this function");
        }
        _;
    }

    modifier onlyAuthorized() {
        if (tx.origin != owner() // We have custom logic here to allow for tx.origin to be used, as we instantiate from another contract
            && _msgSender() != owner()
        ) {
            revert("Only authorized address can call this function");
        }
        _;
    }

    function addManager(address manager) public onlyAuthorized {
        if (manager == address(0)) {
            revert("manager is not a valid address");
        }

        if (managerWhitelist[manager] == true) {
            revert("manager already whitelisted");
        }

        managerWhitelist[manager] = true;
        targetWhitelist[manager] = true;
    }

    function deleteManager(address manager) public onlyOwner {
        if (manager == address(0)) {
            revert("manager is not a valid address");
        }

        if (managerWhitelist[manager] == false) {
            revert("manager not whitelisted");
        }

        managerWhitelist[manager] = false;
        targetWhitelist[manager] = false;
    }

    function versionPaymaster() external view override virtual returns (string memory){
        return "3.0.0-beta.3+opengsn.whitelist.ipaymaster";
    }

    function whitelistEscrow(address target) public onlyManager {
        if (target == address(0)) {
            revert("target is not a valid escrow");
        }

        if (targetWhitelist[target] == true) {
            revert("target already whitelisted");
        }

        targetWhitelist[target] = true;
    }    

    function _preRelayedCall(
        GsnTypes.RelayRequest calldata relayRequest,
        bytes calldata signature,
        bytes calldata approvalData,
        uint256 maxPossibleGas
    )
    internal
    override
    virtual
    returns (bytes memory context, bool revertOnRecipientRevert) {
        (signature, maxPossibleGas);
        require(approvalData.length == 0, "approvalData: invalid length");
        require(relayRequest.relayData.paymasterData.length == 0, "paymasterData: invalid length");    
        address target = relayRequest.request.to;
        require(targetWhitelist[target], "target not whitelisted");

        return ("", useRejectOnRecipientRevert);
    }

    function _postRelayedCall(
        bytes calldata context,
        bool success,
        uint256 gasUseWithoutPost,
        GsnTypes.RelayData calldata relayData
    )
    internal
    override
    virtual {
        (context, success, gasUseWithoutPost, relayData);
    }
}