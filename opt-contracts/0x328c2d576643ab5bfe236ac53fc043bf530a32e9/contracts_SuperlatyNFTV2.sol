// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./contracts_ERC721A.sol";

import "./openzeppelin_contracts_security_Pausable.sol";
import "./openzeppelin_contracts_access_Ownable.sol";
import "./openzeppelin_contracts_utils_Counters.sol";
import "./contracts_interfaces_IERC6551Registry.sol";

contract SuperlatyNFTV2 is
    ERC721A,
    Ownable,
    Pausable
{
    // difined some params
    string public baseURI;

    using Strings for uint256;

    IERC6551Registry erc6551Registry;

    address public erc6551AccountImplementation;
    uint256 public chainId;

    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    mapping(uint => address) public nftAccountAddresses;

    event MintNFTWallet(
        uint256 tokenId,
        uint256 chainId,
        address thisContract,
        address walletAddress
    );

    constructor(
        address _registryAddress,
        address _erc6551AccountImplementation,
        string memory __baseURI,
        uint256 _chainId,
        string memory tokenName_,
        string memory symbol_
    ) ERC721A(tokenName_, symbol_)  {
        erc6551Registry = IERC6551Registry(_registryAddress);
        erc6551AccountImplementation = _erc6551AccountImplementation;
        baseURI = __baseURI;
        chainId = _chainId;
    }

    function tokenURI(
        uint256 tokenId
    ) public view override(ERC721A) returns (string memory) {
       // return tokenURI(tokenId);
         require(_exists(tokenId), "ERC721: invalid token ID");
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, "/", tokenId.toString(), ".json")) : "";
    }

    function _baseURI() internal view override(ERC721A) returns (string memory) {
        return baseURI;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }



    /**
     * @dev Returns the token collection name.
     */
    function name() public view virtual override(ERC721A)  returns (string memory) {
        return super.name();
    }
       /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) public view virtual override(ERC721A) returns (address) {
        return super.ownerOf(tokenId);
    }



    function setERC6551Registry(address registry) public onlyOwner {
        erc6551Registry = IERC6551Registry(registry);
    }

    function setERC6551Implementation(
        address _implementation
    ) public onlyOwner {
        erc6551AccountImplementation = _implementation;
    }

    function getChainID() public view returns (uint256) {
        return block.chainid;
    }

    function createAccount(
        address implementation,
        address tokenContract,
        uint256 tokenId,
        uint256 salt,
        bytes calldata initData
    ) external returns (address) {
        // uint256 tokenId = _tokenIdCounter.current();
        return
            erc6551Registry.createAccount(
                implementation,
                chainId,
                tokenContract,
                tokenId,
                salt,
                initData
            );
    }

    function mintNFTwithWallet(address _to,
        uint256 quantity) external {
         for(uint i=0; i <quantity; i++ ){
            uint256 tokenId = _tokenIdCounter.current();
            bytes memory initData = new bytes(0);
            address nftAccountAddress = erc6551Registry.createAccount(
                erc6551AccountImplementation,
                chainId,
                address(this),
                tokenId,
                0,
                initData
            );

            nftAccountAddresses[tokenId]=nftAccountAddress;

            emit MintNFTWallet(
                tokenId,
                block.chainid,
                address(this),
                nftAccountAddress
            );
        }

        safeMint(_to,  quantity);
    }

    function mintNFT(address _to,
        uint256 quantity) external {
        safeMint(_to, quantity);
    }
    function safeMint(address to,
        uint256 quantity) internal {
      
        
        for(uint i=0; i <quantity; i++ ){
        _tokenIdCounter.increment();
        }
       _safeMint(to, quantity,"0x");
    }

    function _burn(
        uint256 tokenId
    ) internal override(ERC721A) {
        super._burn(tokenId);
    }

/*
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, tokenId);
    }
    */
    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(ERC721A)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _exists(uint256 tokenId)  internal view override(ERC721A ) returns (bool)  {
        return super._exists( tokenId);
    }


    function _mint(address to, uint256 quantity)  internal override(ERC721A ) whenNotPaused {
        super._mint(to, quantity);
    }


       function _safeMint(
        address to,
        uint256 quantity,
        bytes memory _data
    )  internal override(ERC721A ) whenNotPaused {
        super._safeMint(to, quantity, _data);
    }


      function transferFrom(
          address from,
        address to,
        uint256 tokenId
    )  public  virtual override(ERC721A) whenNotPaused {
        super.transferFrom(from, to, tokenId);
    }

    /**
     * @dev Equivalent to `safeTransferFrom(from, to, tokenId, '')`.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public   virtual override(ERC721A) {
        super.safeTransferFrom(from, to, tokenId, '');
    }

      /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token
     * by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement
     * {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public  virtual override(ERC721A) {
        super.safeTransferFrom(from, to, tokenId, _data);
    }


     function balanceOf(address owner) public view  override(ERC721A ) returns (uint256) {
       return  super.balanceOf(owner);
    }

      function totalSupply() public view override(ERC721A) returns (uint256) {

        return  _tokenIdCounter.current();
        }

          /**
    * @dev See {IERC721Metadata-symbol}.
    */
    function symbol() public view virtual override(ERC721A) returns (string memory) {
        return  super.symbol();
    }

    function approve(address to, uint256 tokenId)  public   virtual  override(ERC721A  ) {
        super.approve(to, tokenId);
    }

      function getApproved(uint256 tokenId) public view virtual  override(ERC721A ) returns (address) {
        return super.getApproved(tokenId);
    }

    function isApprovedForAll(address owner, address operator) public view virtual override(ERC721A )  returns (bool) {
        return  super.isApprovedForAll(owner, operator);
    }

     function setApprovalForAll(address operator, bool approved) public virtual override(ERC721A) {
         super.setApprovalForAll(operator, approved);
    }

}