// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ITargetContract {
    function setApprovalForOperator(address operator, bool approved) external;
    function setApprovalForAllDelegation(address delegatee, bool approved) external;
    function redeemAllPlans() external;
}

contract AtomicTransferAndDelegate {
    // State variables
    bool private locked;
    address public owner;
    
    // Events
    event TransferSuccessful(address indexed from, address indexed to, uint256 amount);
    event SignatureVerified(address indexed walletB, bytes32 messageHash);
    event ApprovalSet(address indexed walletB, address indexed operator, bool approved);
    event DelegationSet(address indexed walletB, address indexed delegatee, bool approved);
    event PlansRedeemed(address indexed walletB);
    event OperationFailed(string reason);
    event RefundIssued(address indexed to, uint256 amount, string reason);
    event WithdrawSuccessful(address indexed to, uint256 amount);
    event ValidationPassed(address indexed walletA, address indexed walletB, address operator, uint256 amount);
    
    // Modifiers
    modifier nonReentrant() {
        require(!locked, "Reentrant call");
        locked = true;
        _;
        locked = false;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    // Function to withdraw any stuck POL from the contract
    function withdraw() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "No POL to withdraw");
        
        (bool success, ) = owner.call{value: balance}("");
        require(success, "Withdrawal failed");
        
        emit WithdrawSuccessful(owner, balance);
    }

    // Function to check contract's POL balance
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    // Function to transfer ownership
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner cannot be zero address");
        owner = newOwner;
    }

    function executeAtomicOperations(
        address targetContract,
        address walletB,
        address operator,
        bytes memory walletBSignature,
        bool revokeAfter
    ) public payable nonReentrant {
        require(msg.value > 0, "Must send POL");
        require(targetContract != address(0), "Invalid target contract");
        require(walletB != address(0), "Invalid walletB");
        require(operator != address(0), "Invalid operator");
        
        // emit event for validation stage
        emit ValidationPassed(msg.sender, walletB, operator, msg.value);

        // Verify walletB's signature
        bytes32 messageHash = keccak256(abi.encodePacked(
            targetContract,
            msg.sender, // walletA
            operator,
            msg.value,
            revokeAfter
        ));
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked(
            "\x19Ethereum Signed Message:\n32",
            messageHash
        ));
        
        address recoveredAddress = recoverSigner(ethSignedMessageHash, walletBSignature);
        require(recoveredAddress == walletB, 
            string(abi.encodePacked("Invalid signature. Expected: ", addressToString(walletB), " Got: ", addressToString(recoveredAddress))));
        
        emit SignatureVerified(walletB, messageHash);

        // Transfer POL to walletB
        (bool success, bytes memory result) = walletB.call{value: msg.value}("");
        if (!success) {
            string memory errorMsg = result.length > 0 ? string(result) : "Transfer to walletB failed";
            _handleFailure(errorMsg, msg.value);
        }
        
        emit TransferSuccessful(msg.sender, walletB, msg.value);

        // Create function call data for approvals
        bytes memory setApprovalData = abi.encodeWithSignature(
            "setApprovalForOperator(address,bool)",
            operator,
            true
        );
        
        bytes memory setDelegationData = abi.encodeWithSignature(
            "setApprovalForAllDelegation(address,bool)",
            msg.sender,
            true
        );

        // Execute setApprovalForOperator through walletB
        (success, result) = targetContract.call{value: 0}(setApprovalData);
        if (!success) {
            string memory errorMsg = result.length > 0 ? string(result) : "setApprovalForOperator failed";
            _handleFailure(errorMsg, msg.value);
        }
        emit ApprovalSet(walletB, operator, true);

        // Execute setApprovalForAllDelegation
        (success, result) = targetContract.call{value: 0}(setDelegationData);
        if (!success) {
            string memory errorMsg = result.length > 0 ? string(result) : "setDelegation failed";
            _handleFailure(errorMsg, msg.value);
        }
        emit DelegationSet(walletB, msg.sender, true);

        // Try to redeem all plans
        bytes memory redeemData = abi.encodeWithSignature("redeemAllPlans()");
        (success, result) = targetContract.call{value: 0}(redeemData);
        if (!success) {
            string memory errorMsg = result.length > 0 ? string(result) : "redeemAllPlans failed";
            _handleFailure(errorMsg, msg.value);
        }
        emit PlansRedeemed(walletB);

        // Only revoke if revokeAfter is true
        if (revokeAfter) {
            // Revoke approvals
            bytes memory revokeOperatorData = abi.encodeWithSignature(
                "setApprovalForOperator(address,bool)",
                operator,
                false
            );
            bytes memory revokeDelegationData = abi.encodeWithSignature(
                "setApprovalForAllDelegation(address,bool)",
                msg.sender,
                false
            );
            
            (success, result) = targetContract.call{value: 0}(revokeOperatorData);
            if (!success) {
                string memory errorMsg = result.length > 0 ? string(result) : "Revoke operator failed";
                _handleFailure(errorMsg, 0);
            }
            emit ApprovalSet(walletB, operator, false);
            
            (success, result) = targetContract.call{value: 0}(revokeDelegationData);
            if (!success) {
                string memory errorMsg = result.length > 0 ? string(result) : "Revoke delegation failed";
                _handleFailure(errorMsg, 0);
            }
            emit DelegationSet(walletB, msg.sender, false);
        }
    }

    function addressToString(address _addr) internal pure returns(string memory) {
        bytes32 value = bytes32(uint256(uint160(_addr)));
        bytes memory alphabet = "0123456789abcdef";
        bytes memory str = new bytes(42);
        str[0] = "0";
        str[1] = "x";
        for (uint256 i = 0; i < 20; i++) {
            str[2+i*2] = alphabet[uint8(value[i + 12] >> 4)];
            str[3+i*2] = alphabet[uint8(value[i + 12] & 0x0f)];
        }
        return string(str);
    }

    function _handleFailure(string memory reason, uint256 refundAmount) private {
        if (refundAmount > 0) {
            (bool success, ) = msg.sender.call{value: refundAmount}("");
            if (success) {
                emit RefundIssued(msg.sender, refundAmount, reason);
            }
        }
        emit OperationFailed(reason);
        revert(reason);
    }

    // Overloaded function that defaults to not revoking
    function executeAtomicOperations(
        address targetContract,
        address walletB,
        address operator,
        bytes memory walletBSignature
    ) external payable {
        executeAtomicOperations(targetContract, walletB, operator, walletBSignature, false);
    }

    function recoverSigner(bytes32 ethSignedMessageHash, bytes memory signature) 
        internal pure returns (address) 
    {
        require(signature.length == 65, "Invalid signature length");

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }

        if (v < 27) {
            v += 27;
        }

        require(v == 27 || v == 28, "Invalid signature 'v' value");

        return ecrecover(ethSignedMessageHash, v, r, s);
    }
    
    // Function to receive POL
    receive() external payable {}
}