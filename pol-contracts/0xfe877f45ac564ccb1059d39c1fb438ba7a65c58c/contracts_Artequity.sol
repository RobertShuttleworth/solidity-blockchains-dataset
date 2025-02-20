// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC20_ERC20Upgradeable.sol";
import "./openzeppelin_contracts-upgradeable_access_OwnableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_access_AccessControlUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC20_extensions_ERC20PermitUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC721_utils_ERC721HolderUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_utils_PausableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_utils_ReentrancyGuardUpgradeable.sol";
import "./openzeppelin_contracts_interfaces_IERC20.sol";
import "./openzeppelin_contracts_interfaces_IERC721.sol";

interface IHASHAStableToken is IERC20 {
    function mintTokens(address to, uint256 amount) external;
}

contract UpgradeableFractionalNFTContract is 
    Initializable, 
    ERC20Upgradeable, 
    OwnableUpgradeable, 
    ERC20PermitUpgradeable, 
    ERC721HolderUpgradeable, 
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable 
{
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bool public isPolygonChain;

    struct FractionalizedNFT {
        IERC721 collection;
        uint256 tokenId;
        uint256 tokenAmount;
        address originalFractionalizer;
        bool forSale;
        uint256 pricePerFraction;
    }

    IHASHAStableToken public HASHATOKEN;
    mapping(address => mapping(uint256 => FractionalizedNFT)) public fractionalizedNFTs;
    mapping(address => bool) public supportedTokens;

    // Events
     event NFTFractionalized(
        address indexed collection,
        uint256 indexed tokenId,
        uint256 tokenAmount,
        uint256 fractionAmount,
        uint256 pricePerFraction,
        address indexed fractionalizer
    );

    event NFTFractionalizedWithRole(
        address indexed collection,
        uint256 indexed tokenId,
        uint256 tokenAmount,
        uint256 fractionAmount,
        uint256 pricePerFraction,
        address indexed fractionalizer
    );

    event FractionPurchased(
        address indexed buyer,
        address indexed collection,
        uint256 indexed tokenId,
        uint256 fractionAmount,
        uint256 totalPrice
    );

    event FractionPurchasedWithERC20(
        address indexed buyer,
        address indexed collection,
        uint256 indexed tokenId,
        uint256 fractionAmount,
        address tokenUsed,
        uint256 totalPrice
    );

    event TokenSupportUpdated(address token, bool isSupported);
    event MinterRoleGranted(address indexed account, address indexed grantor);
    event MinterRoleRevoked(address indexed account, address indexed revoker);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _HASHATOKEN) public initializer {
        __ERC20_init("Fractional NFT Token", "FNT");
        __ERC20Permit_init("Fractional NFT Token");
        __Ownable_init(msg.sender);
        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        HASHATOKEN = IHASHAStableToken(_HASHATOKEN);

        // Grant the DEFAULT_ADMIN_ROLE and MINTER_ROLE to the deployer of the contract
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);

        supportedTokens[address(0)] = true; // Using for Polygon or Ethereum
        supportedTokens[0xE410d33FeD4593Aa075974bc4A351aE7215E0C63] = true; // using for polygon mainnet
    }

    // Function to grant the MINTER_ROLE to another account
    function grantMinterRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(MINTER_ROLE, account);
        emit MinterRoleGranted(account, msg.sender);
    }

    // Function to revoke the MINTER_ROLE from an account
    function revokeMinterRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(MINTER_ROLE, account);
        emit MinterRoleRevoked(account, msg.sender);
    }

    function setSupportedTokens(address token, bool isSupported) external onlyOwner {
        supportedTokens[token] = isSupported;
        supportedTokens[address(0)] = true; // Allow payments in native token (e.g., ETH or MATIC)
        emit TokenSupportUpdated(token, isSupported);
    }

    function mintAndFractionalize(
        address _collection,
        uint256 _tokenId,
        uint256 _tokenAmount,     // Pass this as normal number (e.g., 99)
        uint256 _fractionAmount,  // Pass this as normal number (e.g., 99)
        uint256 _pricePerFraction // Pass this in wei
    ) external whenNotPaused nonReentrant {
        require(_tokenAmount > 0, "Token amount must be greater than 0");

        FractionalizedNFT storage fractionalizedNFT = fractionalizedNFTs[_collection][_tokenId];
        require(fractionalizedNFT.tokenAmount == 0, "NFT already fractionalized");

        fractionalizedNFT.collection = IERC721(_collection);
        fractionalizedNFT.collection.safeTransferFrom(
            msg.sender,
            address(this),
            _tokenId
        );
        
        // Store values without wei conversion
        fractionalizedNFT.tokenId = _tokenId;
        fractionalizedNFT.tokenAmount = _tokenAmount;
        fractionalizedNFT.pricePerFraction = _pricePerFraction;
        fractionalizedNFT.forSale = true;
        fractionalizedNFT.originalFractionalizer = msg.sender;

        require(_fractionAmount > 0, "Fraction amount must be greater than 0");
        require(fractionalizedNFT.tokenAmount >= _fractionAmount, "Fraction amount must be less than or equal to NFT token amount");

        // Mint tokens with 18 decimals
        _mint(address(this), _fractionAmount * 10**18);
           emit NFTFractionalizedWithRole(
            _collection,
            _tokenId,
            _tokenAmount,
            _fractionAmount,
            _pricePerFraction,
            msg.sender
        );
    }
    
    function mintAndFractionalizeWithRole(
        address _collection,
        uint256 _tokenId,
        uint256 _tokenAmount,     // Pass this as normal number (e.g., 99)
        uint256 _fractionAmount,  // Pass this as normal number (e.g., 99)
        uint256 _pricePerFraction // Pass this in wei
    ) external whenNotPaused nonReentrant {
        require(!isPolygonChain, "This function is only available on ethereum chain");
        require(hasRole(MINTER_ROLE, msg.sender), "You don't have permission to mint. Kindly request the MINTER_ROLE.");
        require(_tokenAmount > 0, "Token amount must be greater than 0");

        FractionalizedNFT storage fractionalizedNFT = fractionalizedNFTs[_collection][_tokenId];
        require(fractionalizedNFT.tokenAmount == 0, "NFT already fractionalized");

        fractionalizedNFT.collection = IERC721(_collection);
        fractionalizedNFT.collection.safeTransferFrom(
            msg.sender,
            address(this),
            _tokenId
        );
        
        // Store values without wei conversion
        fractionalizedNFT.tokenId = _tokenId;
        fractionalizedNFT.tokenAmount = _tokenAmount;
        fractionalizedNFT.pricePerFraction = _pricePerFraction;
        fractionalizedNFT.forSale = true;
        fractionalizedNFT.originalFractionalizer = msg.sender;

        require(_fractionAmount > 0, "Fraction amount must be greater than 0");
        require(fractionalizedNFT.tokenAmount >= _fractionAmount, "Fraction amount must be less than or equal to NFT token amount");

        // Mint tokens with 18 decimals
        HASHATOKEN.mintTokens(msg.sender, _fractionAmount * 10**18);
          emit NFTFractionalized(
            _collection,
            _tokenId,
            _tokenAmount,
            _fractionAmount,
            _pricePerFraction,
            msg.sender
        );
    }

    function purchaseFraction(
        address _collection,
        uint256 _tokenId,
        uint256 _fractionAmount  // Pass this as normal number (e.g., 5)
    ) external payable whenNotPaused nonReentrant {
        FractionalizedNFT storage fractionalizedNFT = fractionalizedNFTs[_collection][_tokenId];
        require(fractionalizedNFT.forSale == true, "Fraction not for sale");
        require(_fractionAmount >= 5, "Minimum 5 fractions can be purchased");
        
        // Calculate total price in wei
        uint256 totalPrice = _fractionAmount * fractionalizedNFT.pricePerFraction;
        require(msg.value == totalPrice, "Incorrect amount of ether sent");

        // Transfer tokens with 18 decimals
        _transfer(address(this), msg.sender, _fractionAmount * 10**18);

        payable(fractionalizedNFT.originalFractionalizer).transfer(msg.value);
        emit FractionPurchased(
            msg.sender,
            _collection,
            _tokenId,
            _fractionAmount,
            msg.value
        );
    }

    function purchaseFractionWithERC20(
        address _collection,
        uint256 _tokenId,
        uint256 _fractionAmount,  // Pass this as normal number (e.g., 5)
        address _erc20Token
    ) external payable whenNotPaused nonReentrant {
        FractionalizedNFT storage fractionalizedNFT = fractionalizedNFTs[_collection][_tokenId];
        require(supportedTokens[_erc20Token], "Hashs Token is not Supported");
        require(fractionalizedNFT.forSale == true, "Fraction not for sale");
        require(_fractionAmount >= 5, "Minimum 5 fractions can be purchased");

        // Calculate required amount in wei
        uint256 requiredAmount = _fractionAmount * fractionalizedNFT.pricePerFraction;

        IERC20 erc20Token = IERC20(_erc20Token);
        uint256 allowance = erc20Token.allowance(msg.sender, address(this));

        require(erc20Token.balanceOf(msg.sender) >= requiredAmount, "RequiredAmount is not sufficient");
        require(allowance >= requiredAmount, "Allowance not sufficient");

        erc20Token.transferFrom(msg.sender, fractionalizedNFT.originalFractionalizer, requiredAmount);
        
        // Transfer tokens with 18 decimals
        _transfer(address(this), msg.sender, _fractionAmount * 10**18);
             emit FractionPurchasedWithERC20(
            msg.sender,
            _collection,
            _tokenId,
            _fractionAmount,
            _erc20Token,
            requiredAmount
        );
    }

    // Function to pause the contract
    function pause() external onlyOwner {
        _pause();
    }

    // Function to unpause the contract
    function unpause() external onlyOwner {
        _unpause();
    }


    // function redeem(address _collection, uint256 _tokenId) external {
    //     FractionalizedNFT storage fractionalizedNFT = fractionalizedNFTs[_collection][_tokenId];
    //     require(fractionalizedNFT.tokenAmount > 0, "NFT not fractionalized");
    //     require(balanceOf(msg.sender) == totalSupply(), "All fractions must be owned");

    //     uint256 balance = address(this).balance;
    //     uint256 ownerShare = (balance * 95) / 100;
    //     uint256 sellerShare = balance - ownerShare;

    //     payable(owner()).transfer(ownerShare);
    //     fractionalizedNFT.collection.safeTransferFrom(address(this), msg.sender, _tokenId);

    //     _burn(msg.sender, fractionalizedNFT.tokenAmount);
    //     payable(msg.sender).transfer(sellerShare);
    // }
}