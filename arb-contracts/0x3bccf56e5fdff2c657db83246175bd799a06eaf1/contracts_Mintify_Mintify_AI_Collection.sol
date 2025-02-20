// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;
import "./openzeppelin_contracts_utils_Strings.sol";
import "./openzeppelin_contracts_access_Ownable.sol";
import "./erc721a_contracts_ERC721A.sol";
import "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";

/// @title Mintify ERC721A Smart Contract
/// @notice Serves as a fungible token
/// @dev Inherits the ERC721A implentation

contract Mintify_AI_Collection is Ownable, ERC721A {
    using Strings for uint256;
    using SafeERC20 for IERC20;
    address private signer;
    address public token;
    address public MintTreasury;
    address public GenerationTreasury;
    bool public contractPaused;
    uint256 public generationFee;
    uint256 public NFTImageMintPrice;
    uint256 public NFTVideoMintPrice;

    mapping(string => bool) public processedNonces;
    mapping(uint256 => string) private _tokenURIs;

    event Withdraw(uint256 amount, address indexed addr);

    constructor(
        address _token,
        address _signer,
        address _owner,
        address _mintTreasury,
        address _generationTreasury,
        uint256 _NFTImageMintPrice,
        uint256 _NFTVideoMintPrice,
        uint256 _generationFee
    ) ERC721A("Mintify AI Collection", "MNFT") Ownable(_owner) {
        token = _token;
        MintTreasury = _mintTreasury;
        GenerationTreasury=_generationTreasury; 
        signer = _signer;
        NFTImageMintPrice = _NFTImageMintPrice;
        NFTVideoMintPrice = _NFTVideoMintPrice;
        generationFee = _generationFee;
        transferOwnership(_owner);
    }

    modifier whenNotPausedAndValidSupply(
        address _user,
        bool _checkPrice,
        uint256 _tokenAmount
    ) {
        require(!contractPaused, "Sale Paused!");
        if (_checkPrice) {
            require(
                IERC20(token).balanceOf(_user) >= _tokenAmount,
                "Not enough token sent, check price"
            );
        }
        _;
    }

    function mintWithToken(
        address _to,
        string memory _uri,
        bytes memory _signature,
        string memory _message,
        uint256 _tokenAmount
    ) external whenNotPausedAndValidSupply(msg.sender, true, _tokenAmount) {
        require(
            isMessageValid(_signature, _message, _tokenAmount),
            "signature invalid"
        );
        require(processedNonces[_message] == false, "invalid nonce");
        processedNonces[_message] = true;
        IERC20(token).safeTransferFrom(
            msg.sender,
            MintTreasury,
            _tokenAmount
        );
        uint256 startTokenId = _nextTokenId();
        _safeMint(_to, 1);
        _tokenURIs[startTokenId] = _uri;
    }

    function mintWithETH(
        address _to,
        string memory _uri,
        bool isImage
    ) external payable whenNotPausedAndValidSupply(msg.sender, false, 0) {
        uint256 mintPrice;
        if (isImage) {
            mintPrice = NFTImageMintPrice;
        } else {
            mintPrice = NFTVideoMintPrice;
        }

        require(msg.value >= mintPrice, "Insufficient Fees sent for minting");
        (bool success, ) = MintTreasury.call{value: msg.value}("");
        require(success, "ETH transfer to treasury failed");

        uint256 startTokenId = _nextTokenId();
        _safeMint(_to, 1);
        _tokenURIs[startTokenId] = _uri;
    }

    function payForGeneration() external payable {
        require(msg.value >= generationFee, "Insufficient fee");

        (bool success, ) = GenerationTreasury.call{value: msg.value}("");
        require(success, "Fee transfer failed");
    }

    function pauseContract() external onlyOwner {
        contractPaused = true;
    }

    function unpauseContract() external onlyOwner {
        contractPaused = false;
    }

    function setMintTreasuryWallet(address _newMintTreasury)
        external
        onlyOwner
    {
        require(
            _newMintTreasury != address(0),
            "Invalid mint treasury wallet address"
        );
        MintTreasury = _newMintTreasury;
    }

    function setGenerationTreasuryWallet(address _newGenerationTreasury)
        external
        onlyOwner
    {
        require(
            _newGenerationTreasury != address(0),
            "Invalid generation treasury wallet address"
        );
        GenerationTreasury = _newGenerationTreasury;
    }

    function updatesignerWallet(address _signer) external onlyOwner {
        require(_signer != address(0), "Invalid wallet address");
        signer = _signer;
    }

    function updateToken(address _token) external onlyOwner {
        require(_token != address(0), "Invalid _token address");
        token = _token;
    }

    function setNFTImageMintPrice(uint256 _imagePrice) external onlyOwner {
        require(_imagePrice > 0, "Image mint price must be greater than zero");
        NFTImageMintPrice = _imagePrice;
    }

    function setNFTVideoMintPrice(uint256 _videoPrice) external onlyOwner {
        require(_videoPrice > 0, "Video mint price must be greater than zero");
        NFTVideoMintPrice = _videoPrice;
    }

    function withdraw() external payable onlyOwner {
        uint256 amount = address(this).balance;
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Withdraw failed.");

        emit Withdraw(amount, msg.sender);
    }

    function setGenerationFee(uint256 _fee) external onlyOwner {
        require(_fee > 0, "Fee must be greater than zero");
        generationFee = _fee;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        string memory tokenUri = _tokenURIs[tokenId];
        require(bytes(tokenUri).length > 0, "Token URI not set");
        return tokenUri;
    }

    function _startTokenId() internal view virtual override returns (uint256) {
        return 1;
    }

    function walletOfOwner(address owner)
        public
        view
        returns (uint256[] memory)
    {
        unchecked {
            uint256 tokenIdsIdx;
            address currOwnershipAddr;
            uint256 tokenIdsLength = balanceOf(owner);
            uint256[] memory tokenIds = new uint256[](tokenIdsLength);
            TokenOwnership memory ownership;
            for (
                uint256 i = _startTokenId();
                tokenIdsIdx != tokenIdsLength;
                ++i
            ) {
                ownership = _ownershipAt(i);
                if (ownership.burned) {
                    continue;
                }
                if (ownership.addr != address(0)) {
                    currOwnershipAddr = ownership.addr;
                }
                if (currOwnershipAddr == owner) {
                    tokenIds[tokenIdsIdx++] = i;
                }
            }
            return tokenIds;
        }
    }

    function isMessageValid(
        bytes memory _signature,
        string memory _message,
        uint256 _tokenAmount
    ) public view returns (bool) {
        bytes32 messageHash = getMessageHash(_message, _tokenAmount);
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);
        return recoverSigner(ethSignedMessageHash, _signature) == signer;
    }

    function getMessageHash(string memory _message, uint256 _tokenAmount)
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(_message, _tokenAmount));
    }

    function getEthSignedMessageHash(bytes32 _messageHash)
        public
        pure
        returns (bytes32)
    {
        return
            keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n32",
                    _messageHash
                )
            );
    }

    function recoverSigner(
        bytes32 _ethSignedMessageHash,
        bytes memory _signature
    ) public pure returns (address) {
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(_signature);

        return ecrecover(_ethSignedMessageHash, v, r, s);
    }

    function splitSignature(bytes memory sig)
        public
        pure
        returns (
            bytes32 r,
            bytes32 s,
            uint8 v
        )
    {
        require(sig.length == 65, "invalid signature length");

        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
    }
}