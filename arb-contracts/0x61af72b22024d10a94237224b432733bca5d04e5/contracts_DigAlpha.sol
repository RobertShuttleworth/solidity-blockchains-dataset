// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./openzeppelin_contracts_token_ERC721_ERC721.sol";
import "./openzeppelin_contracts_utils_cryptography_ECDSA.sol";
import "./openzeppelin_contracts_access_Ownable.sol";
import "./openzeppelin_contracts_utils_cryptography_MessageHashUtils.sol";

contract DigAlpha is ERC721, Ownable(msg.sender) {
    using ECDSA for bytes32;

    address public adminSigner;
    string private _baseTokenURI;
    mapping(address => uint256) public userMintCount;
    mapping(bytes32 => bool) public usedNonces;

    constructor(address _adminSigner) ERC721("DigAlphaNFT", "DIGALPHA") {
        adminSigner = _adminSigner;
    }

    function setAdminSigner(address _newAdminSigner) external onlyOwner {
        adminSigner = _newAdminSigner;
    }

    function setBaseURI(string memory baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    function mint(
        address to,
        uint256 tokenId,
        bytes32 nonce,
        bytes calldata signature
    ) external {
        require(!usedNonces[nonce], "Nonce already used");
        require(userMintCount[to] == 0, "User already has an NFT");
        userMintCount[to] = 1;
        usedNonces[nonce] = true;

        // Hash the structured data (EIP-712 style)
        bytes32 messageHash = keccak256(abi.encodePacked(to, tokenId, nonce));
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        // Verify signature
        require(
            ethSignedMessageHash.recover(signature) == adminSigner,
            "Invalid signature"
        );

        _mint(to, tokenId);
    }
}



