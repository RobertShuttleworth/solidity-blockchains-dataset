// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

import "./openzeppelin_contracts_token_ERC721_ERC721.sol";
import "./openzeppelin_contracts_token_ERC721_extensions_ERC721URIStorage.sol";
import "./openzeppelin_contracts_token_ERC721_extensions_ERC721Burnable.sol";
import "./openzeppelin_contracts_access_AccessControl.sol";

/**
 * @title BukRewardNFT
 * @dev ERC721 token contract with open minting (no role checks on mint)
 *      but still inherits AccessControl in case you need admin-only features later.
 */
contract BukRewardNFT is
    ERC721,
    ERC721URIStorage,
    ERC721Burnable,
    AccessControl
{
    uint256 private _nextTokenId;
    string public TOKEN_URI = "";

    // Removed MINTER_ROLE and no longer using it
    // bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    event Minted(address indexed to, uint256 indexed tokenId);
    event SafeMinted(address indexed to, uint256 indexed tokenId, bytes data);
    event BatchSafeMinted(
        address indexed to,
        uint256 indexed tokenIdStart,
        uint256 amount
    );

    /**
     * @dev Constructor sets up default admin, token name, symbol, and base token URI.
     *      - We still keep the admin role in case you need it for other future features.
     */
    constructor(
        address initialAdmin,
        string memory contractName,
        string memory contractSymbol,
        string memory tokenURL
    ) ERC721(contractName, contractSymbol) {
        TOKEN_URI = tokenURL;
        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);
    }

    /**
     * @dev Safely mint a new token with arbitrary `data`. Anyone can call this now (fully open).
     */
    function safeMint(
        address to,
        bytes calldata data
    ) external {
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId, data);
        _setTokenURI(tokenId, TOKEN_URI);

        emit SafeMinted(to, tokenId, data);
    }

    /**
     * @dev Batch mint multiple tokens to the same address with arbitrary `data`. Anyone can call.
     */
    function batchSafeMint(
        address to,
        uint256 amount,
        bytes calldata data
    ) external {
        uint256 startTokenId = _nextTokenId;
        for (uint256 i = 0; i < amount; i++) {
            uint256 tokenId = _nextTokenId++;
            _safeMint(to, tokenId, data);
            _setTokenURI(tokenId, TOKEN_URI);
        }

        emit BatchSafeMinted(to, startTokenId, amount);
    }

    /**
     * @dev Mint `amount` of tokens to `account`. Anyone can call.
     */
    function mint(
        address account,
        uint256 amount,
        bytes memory
    ) public {
        for (uint256 i; i < amount; i++) {
            uint256 tokenId = _nextTokenId++;
            _mint(account, tokenId);
            _setTokenURI(tokenId, TOKEN_URI);

            // If you’d like to emit an event for every mint, uncomment below
            emit Minted(account, tokenId);
        }
    }

    /**
     * @dev Override tokenURI to return the correct URI from ERC721URIStorage.
     */
    function tokenURI(
        uint256 tokenId
    ) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    /**
     * @dev Internal burn function to align with ERC721URIStorage.
     */
    function _burn(
        uint256 tokenId
    ) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    /**
     * @dev Required by Solidity to indicate support for certain interfaces.
     */
    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(ERC721, ERC721URIStorage, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}