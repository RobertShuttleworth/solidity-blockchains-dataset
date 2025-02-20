// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title RewardsClaimContract
 * @dev Holds MATIC and allows authorized claims verified by a trusted signer.
 */
contract RewardsClaimContract {
    address public trustedSigner;
    address public owner;

    uint256 public totalRewardsDistributed;

    // Events for better tracking
    event RewardsClaimed(address indexed user, uint256 amount);
    event FundsDeposited(address indexed sender, uint256 amount);
    event FundsWithdrawn(address indexed owner, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // Modifier to restrict access to the owner
    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    // Constructor to initialize the trusted signer and owner
    constructor(address _trustedSigner) {
        require(_trustedSigner != address(0), "Invalid signer address");
        trustedSigner = _trustedSigner;
        owner = msg.sender;
    }

    /**
     * @notice Transfer ownership of the contract to a new address
     * @param newOwner The address of the new owner
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner address cannot be zero");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    /**
     * @notice Claim rewards for a user
     * @param user The address of the user receiving the rewards
     * @param amount The amount of MATIC (in wei) to be claimed
     * @param signature The signature provided by the trustedSigner authorizing this claim
     */
    function claim(address user, uint256 amount, bytes memory signature) external {
        require(user != address(0), "Invalid user address");
        require(amount > 0, "Amount must be greater than zero");
        require(address(this).balance >= amount, "Insufficient contract balance");

        // Reconstruct the message hash
        bytes32 messageHash = keccak256(abi.encodePacked(user, amount));

        // Recover the signer from the signature
        address signer = recoverSigner(messageHash, signature);
        require(signer == trustedSigner, "Invalid signature");

        // Transfer the specified amount of MATIC to the user
        (bool success, ) = user.call{value: amount}("");
        require(success, "Transfer failed");

        // Update total rewards distributed
        totalRewardsDistributed += amount;

        emit RewardsClaimed(user, amount);
    }

    /**
     * @notice Deposit funds into the contract
     */
    function depositFunds() external payable {
        require(msg.value > 0, "Must send MATIC");
        emit FundsDeposited(msg.sender, msg.value);
    }

    /**
     * @notice Withdraw MATIC from the contract
     * @param amount The amount to withdraw in wei
     */
    function withdrawFunds(uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be greater than zero");
        require(address(this).balance >= amount, "Insufficient contract balance");

        (bool success, ) = owner.call{value: amount}("");
        require(success, "Withdrawal failed");

        emit FundsWithdrawn(owner, amount);
    }

    /**
     * @notice Change the trusted signer
     * @param newSigner The new trusted signer address
     */
    function updateTrustedSigner(address newSigner) external onlyOwner {
        require(newSigner != address(0), "Invalid signer address");
        trustedSigner = newSigner;
    }

    /**
     * @dev Recovers the signer from a hashed message and signature
     * @param hash The keccak256 hashed message
     * @param signature The signature over the hashed message
     */
    function recoverSigner(bytes32 hash, bytes memory signature) internal pure returns (address) {
        require(signature.length == 65, "Invalid signature length");

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }

        if (v < 27) {
            v += 27;
        }

        return ecrecover(hash, v, r, s);
    }

    /**
     * @notice Fallback function to receive MATIC
     */
    receive() external payable {
        emit FundsDeposited(msg.sender, msg.value);
    }
}