// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import "./openzeppelin_contracts_token_ERC721_IERC721.sol";
import "./contracts_lib_IIronballLibrary.sol";

interface IIronballNFT is IERC721 {
    // Events
    event Refund(uint256 tokenId, address indexed by, uint256 value);
    event Upgrade(uint256 tokenId, address indexed by, uint256 value);
    event GasFeesClaim(address owner, uint256 minClaimRateBips);
    event PublicMintStateUpdate(address owner, bool active);
    event PrivateMintStateUpdate(address owner, bool active);
    event PublicMintConfigUpdate(address owner, uint256 mintPrice, uint256 lockPeriod, uint256 maxMintsPerTransaction, uint256 maxMintsPerWallet, bool active);
    event PrivateMintConfigUpdate(address owner, uint256 mintPrice, uint256 lockPeriod, uint256 maxMintsPerTransaction, uint256 maxMintsPerWallet, bool active);
    event Mint(uint256 tokenId, address minter, address indexed recipient, uint256 mintPrice, uint256 lockPeriod);
    event YieldClaim(address owner, address protocolFeeCollector, address referrer, uint256 ownerYield, uint256 protocolYield, uint256 referrerYield);

    // Functions
    function initialize(address _ownerAddress, address _storageAddress, address _factoryAddress, 
    string memory name_, string memory symbol_, uint256 _maxSupply, 
    string memory baseURI_, string memory _preRevealImageURI, 
    address _referrer, address _whitelistSigner, IronballLibrary.MintConfig memory _publicMintConfig,
     IronballLibrary.MintConfig memory _privateMintConfig) external;
    function publicMint(uint24 _quantity) external payable;
    function privateMint(uint24 _quantity, bytes memory _signature) external payable;
    function refund(uint256 tokenId_) external;
    function upgrade(uint256 tokenId_) external;
    function claimYield() external;
    function flipPublicMintState() external;
    function flipPrivateMintState() external;
    function setPublicMintConfig(IronballLibrary.MintConfig memory _publicMintConfig) external;
    function setPrivateMintConfig(IronballLibrary.MintConfig memory _privateMintConfig) external;
    function setPreRevealImageURI(string calldata _preRevealImageURI) external;
    function setBaseURI(string calldata baseURI_) external;
    function setWhitelistSigner(address _whitelistSigner) external;
    function claimGasFees(uint256 _minClaimRateBips) external;
    function ownerMint(address _recipient, uint128 _mintPrice, uint64 _lockPeriod, uint24 _quantity) external payable;
    function totalSupply() external view returns (uint256);
    function tokensOwnedBy(address _ownerAddress) external view returns (uint256[] memory);

    // State variable getters
    function tvl() external view returns (uint256);
    function maxSupply() external view returns (uint256);
    function publicMintStartTime() external view returns (uint256);
    function factoryAddress() external view returns (address);
    function referrer() external view returns (address);
    function whitelistSigner() external view returns (address);
    function baseURI() external view returns (string memory);
    function preRevealImageURI() external view returns (string memory);
    function initialized() external view returns (bool);
    function publicMintConfig() external view returns (IronballLibrary.MintConfig memory);
    function privateMintConfig() external view returns (IronballLibrary.MintConfig memory);
    function locks(uint256 tokenId) external view returns (uint256 value, uint256 lockPeriod, uint256 lockedAt);
    function upgradedAt(uint256 tokenId) external view returns (uint256);
}