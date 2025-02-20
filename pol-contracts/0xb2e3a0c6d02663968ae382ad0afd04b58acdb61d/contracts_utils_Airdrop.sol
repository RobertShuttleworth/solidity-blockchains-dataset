// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./openzeppelin_contracts_utils_cryptography_MerkleProof.sol";
import "./openzeppelin_contracts_access_Ownable.sol";
import "./contracts_token_Bean.sol";
import "./contracts_utils_Registry.sol";

contract Airdrop is Ownable(msg.sender) {
    struct System {
        uint256 totalClaimed;
        uint256 limit; // 4_000 BEAN
        uint256 dropAmt; // 0.1 BEAN
        bool isActive;
        bytes32 merkleRoot;
    }
    System public system;
    Registry public registry;
    mapping(address => bool) public claimed;

    function claim(bytes32[] calldata proof) external {
        Bean token = Bean(registry.getContractAddress("Bean"));
        require(system.isActive, "Airdrop:: Airdrop is not active");
        require(
            system.totalClaimed <= system.limit,
            "Airdrop:: Limit exceeded"
        );
        require(!claimed[msg.sender], "Airdrop:: Already claimed");
        require(
            system.totalClaimed <= system.limit,
            "Airdrop:: Proof limit exceeded"
        );
        require(
            MerkleProof.verify(
                proof,
                system.merkleRoot,
                keccak256(abi.encodePacked(msg.sender))
            ),
            "Airdrop:: Invalid proof"
        );

        claimed[msg.sender] = true;
        token.mint(msg.sender, system.dropAmt);
        system.totalClaimed += system.dropAmt;
    }

    function checkEligibility(
        bytes32[] calldata proof
    ) external view returns (bool, bool) {
        return (
            MerkleProof.verify(
                proof,
                system.merkleRoot,
                keccak256(abi.encodePacked(msg.sender))
            ),
            claimed[msg.sender]
        );
    }

    function changeDropAmt(uint256 _dropAmt) external onlyOwner {
        system.dropAmt = _dropAmt;
    }

    function changeLimit(uint256 _limit) external onlyOwner {
        system.limit = _limit;
    }

    function changeMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        system.merkleRoot = _merkleRoot;
    }

    function changeActiveStatus() external onlyOwner {
        system.isActive = !system.isActive;
    }

    function setRegistry(address _registry) external onlyOwner {
        registry = Registry(_registry);
    }
}