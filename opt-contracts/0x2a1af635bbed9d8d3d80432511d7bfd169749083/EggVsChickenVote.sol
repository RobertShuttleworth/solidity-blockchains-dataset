// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract EggVsChickenVote {
    // Noms des options
    string public optionEgg = "L'oeuf";
    string public optionChicken = "La poule";

    // Nombre de votes pour chaque option
    uint256 public votesForEgg;
    uint256 public votesForChicken;

    // Suivi des adresses qui ont voté
    mapping(address => bool) private hasVoted;

    // Événement émis lorsqu'un utilisateur vote
    event Voted(address indexed voter, string choice);

    // Fonction pour voter
    function vote(string memory choice) public {
        require(!hasVoted[msg.sender], "You have already voted");
        require(
            keccak256(abi.encodePacked(choice)) == keccak256(abi.encodePacked(optionEgg)) ||
            keccak256(abi.encodePacked(choice)) == keccak256(abi.encodePacked(optionChicken)),
            "Invalid choice"
        );

        // Enregistrement du vote
        hasVoted[msg.sender] = true;

        if (keccak256(abi.encodePacked(choice)) == keccak256(abi.encodePacked(optionEgg))) {
            votesForEgg += 1;
        } else {
            votesForChicken += 1;
        }

        emit Voted(msg.sender, choice);
    }

    // Fonction pour consulter les résultats
    function getResults() public view returns (string memory, uint256, string memory, uint256) {
        return (optionEgg, votesForEgg, optionChicken, votesForChicken);
    }
}