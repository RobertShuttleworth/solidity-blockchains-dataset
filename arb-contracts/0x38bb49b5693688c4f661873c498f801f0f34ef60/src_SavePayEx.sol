// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Initializable} from "./lib_openzeppelin-contracts-upgradeable_contracts_proxy_utils_Initializable.sol";
import {AccessControlUpgradeable} from "./lib_openzeppelin-contracts-upgradeable_contracts_access_AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "./lib_openzeppelin-contracts-upgradeable_contracts_proxy_utils_UUPSUpgradeable.sol";
import {IERC721} from "./lib_openzeppelin-contracts-upgradeable_lib_openzeppelin-contracts_contracts_token_ERC721_IERC721.sol";
import {IERC721Receiver} from "./lib_openzeppelin-contracts-upgradeable_lib_openzeppelin-contracts_contracts_token_ERC721_IERC721Receiver.sol";
import {IFiat24Account} from "./src_interfaces_IFiat24Account.sol";
import {IReferralStorage} from "./src_interfaces_IReferralStorage.sol";
import {IF24Sales} from "./src_interfaces_IF24Sales.sol";
import {IERC20} from "./lib_openzeppelin-contracts-upgradeable_lib_openzeppelin-contracts_contracts_token_ERC20_IERC20.sol";
import {IFiat24CryptoDeposit} from "./src_interfaces_IFiat24CryptoDeposit.sol";
//1. deposit F24 token to this contract
//2. transfer Mother NFT to this contract
//3. preconfig holders should approveAll NFT to this contract
contract SavePayEx is Initializable, AccessControlUpgradeable, UUPSUpgradeable, IERC721Receiver {
    IReferralStorage public referralStorage;
    address public f24SalesAddress;
    uint256 public mintFee;

    bytes32 public constant MINT_ROLE = keccak256("MINT_ROLE");
    bytes32 public constant TOKEN_TRANSFER_ROLE = keccak256("TOKEN_TRANSFER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    IFiat24Account public constant FIAT24ACCOUNT = IFiat24Account(0x133CAEecA096cA54889db71956c7f75862Ead7A0);
    IERC20 public constant F24 = IERC20(0x22043fDdF353308B4F2e7dA2e5284E4D087449e1);
    IFiat24CryptoDeposit public constant FIAT24CRYPTODEPOSIT = IFiat24CryptoDeposit(0x4582f67698843Dfb6A9F195C0dDee05B0A8C973F);
    uint256 public constant F24_PRECISION = 10 ** 2;
    uint256 public constant ETH_PRECISION = 10 ** 18;
    IERC20 public constant USDC = IERC20(0xaf88d065e77c8cC2239327C5EDb3A432268e5831);
    uint256 private constant USDC_DIVISOR = 1e4;
    address private constant USD24 = 0xbE00f3db78688d9704BCb4e0a827aea3a9Cc0D62;

    event ETHReceived(address indexed sender, uint256 amount);
    event NFTMinted(address indexed to, uint256 tokenId, uint256 referrerTokenID, uint256 ethPayed);
    event TokenWithdrawn(address indexed token, address indexed to, uint256 amount);
    event NFTMintedByAdmin(address indexed sender, address indexed to, uint256 tokenId);
    event NFTMintedWithPreconfig(address indexed to, address indexed restockingHolder, uint256 tokenId, uint256 referrerTokenID, uint256 restockingID, uint256 ethPayed);

    error TransferFailed();

    function initialize(address _referralStorage, address _f24Sales) public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        
        require(_referralStorage != address(0), "0");
        require(_f24Sales != address(0), "0");
        referralStorage = IReferralStorage(_referralStorage);
        f24SalesAddress = _f24Sales;

        F24.approve(address(FIAT24ACCOUNT), 100000 * F24_PRECISION);
    }

    receive() external payable {
        emit ETHReceived(msg.sender, msg.value);
    }

    fallback() external payable {
        emit ETHReceived(msg.sender, msg.value);
    }

    /**
     * @notice Withdraws ETH or ERC20 tokens from the contract
     * @param token Address of token to withdraw (address(0) for ETH)
     * @param to Recipient address
     * @param amount Amount to withdraw
     */
    function withdraw(
        address token,
        address payable to,
        uint256 amount
    ) external onlyRole(TOKEN_TRANSFER_ROLE) {
        require(to != address(0), "Invalid recipient");
        require(amount > 0, "Invalid amount");

        if (token == address(0)) {
            // Withdraw ETH
            require(amount <= address(this).balance, "Insufficient ETH balance");
            (bool success, ) = to.call{value: amount, gas: 2300}("");
            if (!success) revert TransferFailed();
        } else {
            // Withdraw ERC20
            require(amount <= IERC20(token).balanceOf(address(this)), "Insufficient token balance");
            bool success = IERC20(token).transfer(to, amount);
            if (!success) revert TransferFailed();
        }
        emit TokenWithdrawn(token, to, amount);
    }

    //should only be used for Distributor
    function depositFiat24Crypto(address _client, address _outputToken, uint256 _usdcAmount) external onlyRole(TOKEN_TRANSFER_ROLE) returns(uint256 outputAmount) {
        require(_outputToken == USD24, "ot");
        uint256 usdcBalance = USDC.balanceOf(_client);
        if(usdcBalance > FIAT24CRYPTODEPOSIT.minUsdcDepositAmount()){
            FIAT24CRYPTODEPOSIT.depositByWallet(_client, _outputToken, usdcBalance);
        }
        return _usdcAmount / USDC_DIVISOR;
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function mintNFTWithRef(address to, uint256 _tokenId, uint256 referrerTokenID) external payable {
        //params check
        require(to != address(0), "to 0");
        require(FIAT24ACCOUNT.balanceOf(to) == 0, "to Already has NFT");
        require(_tokenId < 80000 || (_tokenId >= 100000 && _tokenId < 800000), "invalid tokenId");
        require(!FIAT24ACCOUNT.exists(_tokenId), "NFT exists");

        //check F24 balance
        require(F24.balanceOf(address(this)) >= 1 * F24_PRECISION, "Insufficient F24 balance");

        //check mintFee
        require(msg.value >= mintFee, "Insufficient ETH sent");

        //mint NFT
        FIAT24ACCOUNT.mintByWallet(to, _tokenId);

        //set referrer
        uint256 finalReferrerTokenID = 0;
        if(referrerTokenID != 0 && FIAT24ACCOUNT.exists(referrerTokenID) && referrerTokenID != _tokenId) {
            referralStorage.setReferrer(_tokenId, referrerTokenID, msg.value);
            finalReferrerTokenID = referrerTokenID;
        }

        emit NFTMinted(to, _tokenId, finalReferrerTokenID, msg.value);
    }

    /**
     * @param to The user who want a NFT
     * @param _tokenId ID selected by the user
     * @param referrerTokenID The ID of the referrer, set to 0 if there is no referrer
     * @param restockingID The token ID for restocking purposes. Get a random one from the API "https://www.savepay.org/api/gen/tokenid/available/:startid"
     */
    function mintWithPreconfig(address to, uint256 _tokenId, uint256 referrerTokenID, uint256 restockingID) external payable {
        //params check
        require(to != address(0), "to 0");
        require(FIAT24ACCOUNT.balanceOf(to) == 0, "to Already has NFT");

        require(restockingID != 0, "invalid restockingID");
        require(restockingID < 80000 || (restockingID >= 100000 && restockingID < 800000), "invalid restockingID");
        require(!FIAT24ACCOUNT.exists(restockingID), "restockingID exists");
        
        //check F24 balance
        require(F24.balanceOf(address(this)) >= 1 * F24_PRECISION, "Insufficient F24 balance");

        //get F24 price
        uint256 f24QuotePerEther = IF24Sales(f24SalesAddress).quotePerEther();
        require(f24QuotePerEther * msg.value >= 1 * F24_PRECISION * ETH_PRECISION, "Insufficient ETH sent");

        //transfer NFT
        address owner = FIAT24ACCOUNT.ownerOf(_tokenId);
        require(FIAT24ACCOUNT.isApprovedForAll(owner, address(this)), "Not approved NFT");
        FIAT24ACCOUNT.transferFrom(owner, to, _tokenId);

        //restocking NFT
        FIAT24ACCOUNT.mintByWallet(owner, restockingID);

        //set referrer
        uint256 finalReferrerTokenID = 0;
        if(referrerTokenID != 0 && FIAT24ACCOUNT.exists(referrerTokenID) && referrerTokenID != _tokenId) {
            referralStorage.setReferrer(_tokenId, referrerTokenID, msg.value);
            finalReferrerTokenID = referrerTokenID;
        }

        emit NFTMintedWithPreconfig(to, owner, _tokenId, finalReferrerTokenID, restockingID, msg.value);
    }

    function mintNFTByAdmin(address to, uint256 _tokenId) external onlyRole(MINT_ROLE) {
        //check F24 balance
        require(F24.balanceOf(address(this)) >= 1 * F24_PRECISION, "Insufficient F24 balance");
        
        //mint NFT
        FIAT24ACCOUNT.mintByWallet(to, _tokenId);

        emit NFTMintedByAdmin(msg.sender, to, _tokenId);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function transferNFT(
        address nftContract,
        uint256 tokenId,
        address to
    ) external onlyRole(ADMIN_ROLE) {
        IERC721(nftContract).safeTransferFrom(address(this), to, tokenId);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(ADMIN_ROLE){}

    function setF24Sales(address _f24Sales) external onlyRole(ADMIN_ROLE) {
        f24SalesAddress = _f24Sales;
    }

    function setMintFee(uint256 _mintFee) external onlyRole(ADMIN_ROLE) {
        require(_mintFee > 0, "0 fee");
        mintFee = _mintFee;
    }
}