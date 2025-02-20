// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./openzeppelin_contracts-upgradeable_token_ERC721_ERC721Upgradeable.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC721_extensions_ERC721URIStorageUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_access_OwnableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_utils_cryptography_draft-EIP712Upgradeable.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC721_extensions_draft-ERC721VotesUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";
import "./openzeppelin_contracts-upgradeable_utils_CountersUpgradeable.sol";

contract HVAXAgentVoterCard is Initializable, ERC721Upgradeable, ERC721URIStorageUpgradeable, OwnableUpgradeable, EIP712Upgradeable, ERC721VotesUpgradeable {
    using CountersUpgradeable for CountersUpgradeable.Counter;

    CountersUpgradeable.Counter private _tokenIdCounter;
    string private baseUri; 

    mapping(address => bool) public minters;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() initializer public {
        __ERC721_init("HVAXAgentVoterCard", "HVAXAVC");
        __ERC721URIStorage_init();
        __Ownable_init();
        __EIP712_init("HVAXAgentVoterCard", "1");
        __ERC721Votes_init();
        baseUri = "";
        minters[msg.sender] = true;
    }

    modifier onlyMinters() {
        require(minters[msg.sender], "Caller is not an admin");
        _;
    }

    function addMinter(address minter) external onlyOwner {
        require(minter != address(0), "Invalid address");
        minters[minter] = true;
    }

    function removeMinter(address minter) external onlyOwner {
        require(minter != address(0), "Invalid address");
        require(minters[minter], "Address is not an admin");
        minters[minter] = false;
    }

    function isMinter(address account) external view returns (bool) {
        return minters[account];
    }

    function safeMint(address to) public onlyMinters() {
        uint256 balanceOfRecipient = balanceOf(to);
        require(balanceOfRecipient == 0, "User already has a balance");

        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, tokenURI(tokenId));
    }
    
    // Overrides IERC6372 functions to make the token & governor timestamp-based

    function clock() public view override returns (uint48) {
        return uint48(block.timestamp);
    }

    // solhint-disable-next-line func-name-mixedcase
    function CLOCK_MODE() public pure override returns (string memory) {
        return "mode=timestamp";
    }

    function setBaseUri(string memory newUri) external onlyOwner {
        baseUri = newUri;
    }

    function _baseURI() internal view override returns(string memory) {
        return baseUri;
    }

    // The following functions are overrides required by Solidity.

    function _afterTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
        internal
        override(ERC721Upgradeable, ERC721VotesUpgradeable)
    {
        super._afterTokenTransfer(from, to, tokenId, batchSize);
    }

    function _burn(uint256 tokenId)
        internal
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
    {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _transfer(address from, address to, uint256 tokenId) internal virtual override {
      revert('Not transferrable');
    }
}