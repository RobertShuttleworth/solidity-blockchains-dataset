// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./openzeppelin_contracts-upgradeable_token_ERC721_extensions_ERC721EnumerableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC721_extensions_ERC721URIStorageUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_token_common_ERC2981Upgradeable.sol";
import "./openzeppelin_contracts-upgradeable_access_AccessControlEnumerableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_utils_CountersUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_utils_StringsUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_proxy_utils_UUPSUpgradeable.sol";
import "./openzeppelin_contracts_utils_structs_EnumerableSet.sol";

contract Mold is
    ERC721EnumerableUpgradeable,
    ERC2981Upgradeable,
    AccessControlEnumerableUpgradeable,
    ERC721URIStorageUpgradeable,
    UUPSUpgradeable
{
    using CountersUpgradeable for CountersUpgradeable.Counter;
    using StringsUpgradeable for uint16;
    using EnumerableSet for EnumerableSet.UintSet;
    CountersUpgradeable.Counter internal _tokenIds;

    string internal _baseTokenURI;

    bytes32 public constant LAUNCHPAD_ROLE = keccak256("LAUNCHPAD_ROLE");
    mapping(address => EnumerableSet.UintSet) private userTokens;

    event RoyaltyChanged(address receiver, uint96 royaltyFeesInBips);
    event SetTokenURI(uint256 tokenId, string _tokenURI);
    event SetBaseURI(string baseURI_);

    /// @dev Check if caller is contract owner

    modifier onlyCoinAvatarCore() {
        require(
            hasRole(LAUNCHPAD_ROLE, msg.sender),
            "Caller has no launchpad role."
        );
        _;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @dev Sets main dependencies and constants
    /// @param name 721 nft name
    /// @param symbol 721 nft symbol
    /// @param royaltyFeesInBips fee percent. 1% = 100 bips
    /// @param _launchpad launchpad contract address
    /// @param baseURI baseUri for mint

    function initialize(
        string memory name,
        string memory symbol,
        uint96 royaltyFeesInBips,
        address _launchpad,
        string memory baseURI
    ) public initializer {
        __ERC721_init(name, symbol);
        __UUPSUpgradeable_init();
        __AccessControl_init();
        __ERC721Enumerable_init();
        __ERC721URIStorage_init();
        __ERC2981_init();

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(LAUNCHPAD_ROLE, _msgSender());
        _setRoleAdmin(LAUNCHPAD_ROLE, LAUNCHPAD_ROLE);
        _setupRole(LAUNCHPAD_ROLE, _launchpad);
        setBaseURI(baseURI);
        setRoyaltyInfo(_launchpad, royaltyFeesInBips);
    }

    /// @dev Set the base URI
    /// @param baseURI_ Base path to metadata

    function setBaseURI(string memory baseURI_) public onlyCoinAvatarCore {
        _baseTokenURI = baseURI_;
        emit SetBaseURI(baseURI_);
    }

    /// @dev Get current base uri

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    /// @dev Return the token URI. Included baseUri concatenated with tokenUri
    /// @param tokenId Id of ERC721 token

    function tokenURI(
        uint256 tokenId
    )
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function name()
        public
        pure
        override(ERC721Upgradeable)
        returns (string memory)
    {
        return "CA / Molds";
    }

    /// @dev Set the token URI
    /// @param tokenId Id of ERC721 token
    /// @param _tokenURI token URI without base URI

    function setTokenURI(
        uint256 tokenId,
        string calldata _tokenURI
    ) public onlyCoinAvatarCore {
        super._setTokenURI(tokenId, _tokenURI);
        emit SetTokenURI(tokenId, _tokenURI);
    }

    /// @dev mint a new ERC721 token with incremented id and custom url
    /// @param to token receiver after minting
    /// note Use _setTokenURI for creating cells in memory for further drawing

    function mint(
        address to,
        string calldata uri
    ) external onlyCoinAvatarCore returns (uint256) {
        uint256 tokenId = _tokenIds.current();
        _tokenIds.increment();
        userTokens[to].add(tokenId);
        _safeMint(to, tokenId);
        setTokenURI(tokenId, uri);
        return tokenId;
    }

    function burn(uint256 tokenId) external onlyCoinAvatarCore {
        address userOf = ownerOf(tokenId);
        userTokens[userOf].remove(tokenId);
        _burn(tokenId);
    }

    /// @dev burn a existing ERC721 token
    /// @param tokenId Id of ERC721 token

    function _burn(
        uint256 tokenId
    )
        internal
        virtual
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
    {
        super._burn(tokenId);
    }

    /// @dev Sets the royalty information that all ids in this contract will default to.
    /// @param _receiver royalty receiver. Cannot be the zero address.
    /// @param _royaltyFeesInBips fee percent. 1% = 100 bips

    function setRoyaltyInfo(
        address _receiver,
        uint96 _royaltyFeesInBips
    ) public onlyCoinAvatarCore {
        require(_royaltyFeesInBips <= 1000, "Royalty must be <= 10%");
        _setDefaultRoyalty(_receiver, _royaltyFeesInBips);
        emit RoyaltyChanged(_receiver, _royaltyFeesInBips);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    )
        internal
        virtual
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
    {
        userTokens[from].remove(tokenId);
        userTokens[to].add(tokenId);
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(
            AccessControlEnumerableUpgradeable,
            ERC2981Upgradeable,
            ERC721EnumerableUpgradeable,
            ERC721URIStorageUpgradeable
        )
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function getUserTokens(
        address user
    ) external view returns (uint256[] memory) {
        return userTokens[user].values();
    }

    uint256[100] __gap;
}