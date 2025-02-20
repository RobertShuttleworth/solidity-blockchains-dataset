// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

contract MetaData {
	// Sapphire Blue - Professional and vibrant
	string private constant NAME = "Vedant \xF0\x9F\x9A\x80"; // Rocket emoji in UTF-8
	uint8 private immutable r = 15; // Sapphire blue
	uint8 private immutable g = 82; // that looks professional
	uint8 private immutable b = 186; // and vibrant

	function getName() external pure returns (string memory) {
		return NAME;
	}

	function getColor() external pure returns (uint8, uint8, uint8) {
		return (r, g, b);
	}
}