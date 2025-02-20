// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./lib_openzeppelin-contracts_contracts_token_ERC721_IERC721Receiver.sol";
import "./lib_openzeppelin-contracts_contracts_token_ERC721_ERC721.sol";
import "./lib_openzeppelin-contracts_contracts_token_ERC721_extensions_IERC721Metadata.sol";
import "./lib_openzeppelin-contracts_contracts_utils_Pausable.sol";
import "./lib_openzeppelin-contracts_contracts_access_Ownable2Step.sol";
import "./lib_openzeppelin-contracts_contracts_token_ERC20_IERC20.sol";

contract StakingToken is ERC721, Pausable, Ownable2Step {
    
    event PriceSet(uint256 newPrice);
    event Purchase(uint256 amount, address receiver, bool stake, bool onChain);

    IERC20 public paymentToken;
    uint256 public price;
    uint256 public currentId;

    address stakingContract;
    address paymentReceiver;
    address minter;
    string URIPrefix;
    string URISuffix;
    mapping(uint256 tokenId => string) overridedTokenURI;

    constructor(
        string memory _name,
        string memory _symbol,
        address initialOwner,
        address _paymentReceiver,
        address _paymentToken,
        uint256 _price
    ) Ownable(initialOwner) ERC721(_name, _symbol) {
        require(
            _paymentReceiver != address(0),
            "E02: Receiver address could not be zero"
        );
        require(
            _paymentToken != address(0),
            "E03: Token address could not be zero"
        );
        stakingContract = msg.sender;
        paymentReceiver = _paymentReceiver;
        paymentToken = IERC20(_paymentToken);
        price = _price;
        emit PriceSet(_price);
    }

    /**
     * Returns token URI
     *
     * @param _tokenId Id of token
     */
    function tokenURI(
        uint256 _tokenId
    ) public view override returns (string memory) {
        _requireOwned(_tokenId);
        string memory uri = overridedTokenURI[_tokenId];
        return
            bytes(uri).length != 0
                ? uri
                : string.concat(
                    URIPrefix,
                    Strings.toString(_tokenId),
                    URISuffix
                );
    }

    /**
     * Set prefix and suffix for default URI generation
     *
     * @param _URIPrefix URI prefix
     * @param _URISuffix URI suffix
     */
    function setTokenURIParts(
        string memory _URIPrefix,
        string memory _URISuffix
    ) public {
        _checkOwner();
        URIPrefix = _URIPrefix;
        URISuffix = _URISuffix;
    }

    /**
     * Set address that alowed to mint tokens
     *
     * @param _minter address that alowed to call mint()
     */

    function setMinter(address _minter) public {
        _checkOwner();
        minter = _minter;
    }

    /**
     * Set payments receiver
     * 
     * @param _paymentReceiver new payment receiver
     */
    function setReceiver(address _paymentReceiver) public {
        _checkOwner();
        require(
            _paymentReceiver != address(0),
            "E02: Receiver address could not be zero"
        );
        paymentReceiver = _paymentReceiver;
    }

    /**
     * Pause contract functionality
     */
    function pause() public{
        _checkOwner();
        _pause();
    }

    /**
     * Unpause contract functionality
     */
    function unpause() public{
        _checkOwner();
        _unpause();
    }

    /**
     * Override URI for list of token IDs. Could be used before mint
     *
     * @param ids Array of token IDs
     * @param URIs Array of exact URIs
     */
    function setTokenURIs(
        uint256[] memory ids,
        string[] memory URIs
    ) public {
        _checkOwner();
        require(
            ids.length == URIs.length,
            "E04: Input arrays has different sizes"
        );
        for (uint8 i = 0; i < ids.length; ++i) {
            overridedTokenURI[ids[i]] = URIs[i];
        }
    }

    /**
     * Set price in token wei for one NFT
     *
     * @param _price Price
     */
    function setPrice(uint256 _price) public {
        _checkOwner();
        price = _price;
        emit PriceSet(_price);
    }

    /**
     * Purchase NFT's. Allowance for this conftract required
     *
     * @param amount amount of NFTs
     * @param stake will NFT be staked
     */
    function purchase(uint256 amount, bool stake) public {
        _requireNotPaused();
        uint256 i = currentId;
        uint256 limit = currentId + amount;
        for (; i < limit; ++i) {
            _mint(msg.sender, i);
            if (stake) {
                safeTransferFrom(msg.sender, stakingContract, i);
            }
        }
        currentId = limit;
        paymentToken.transferFrom(msg.sender, paymentReceiver, amount * price);
        emit Purchase(amount, msg.sender, stake, true);
    }

    /**
     * @param receiver address that receive or stake NFTs
     * @param amount amount of NFTs
     * @param stake will NFT be staked
     */

    function mint(address receiver, uint256 amount, bool stake) public {
        _requireNotPaused();
        require(
            (msg.sender == minter) || (msg.sender == owner()),
            "E05: Caller neither minter not owner"
        );
        require(
            (receiver != stakingContract),
            "E07: Staking contract could not be receiver"
        );
        if (stake) {
            _setApprovalForAll(receiver, _msgSender(), true);
        }
        uint256 i = currentId;
        uint256 limit = currentId + amount;
        for (; i < limit; ++i) {
            _mint(receiver, i);
            if (stake) {
                safeTransferFrom(receiver, stakingContract, i);
            }
        }
        currentId = limit;
        if (stake) {
            _setApprovalForAll(receiver, _msgSender(), false);
        }
        emit Purchase(amount, msg.sender, stake, false);
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override {
        _requireNotPaused();
        require(
            to != stakingContract,
            "E06: Transfer to staking contract require use of safeTransferFrom()"
        );
        if (to == address(0)) {
            revert ERC721InvalidReceiver(address(0));
        }

        address previousOwner = _update(to, tokenId, _msgSender());
        if (previousOwner != from) {
            revert ERC721IncorrectOwner(from, tokenId, previousOwner);
        }
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public override {
        _requireNotPaused();
        if (to == address(0)) {
            revert ERC721InvalidReceiver(address(0));
        }
        if (to.code.length > 0) {
            bytes4 retval = IERC721Receiver(to).onERC721Received(
                _msgSender(),
                from,
                tokenId,
                data
            );
            if (retval != IERC721Receiver.onERC721Received.selector) {
                revert ERC721InvalidReceiver(to);
            }
        }
        address previousOwner = _update(to, tokenId, _msgSender());
        if (previousOwner != from) {
            revert ERC721IncorrectOwner(from, tokenId, previousOwner);
        }
    }
}