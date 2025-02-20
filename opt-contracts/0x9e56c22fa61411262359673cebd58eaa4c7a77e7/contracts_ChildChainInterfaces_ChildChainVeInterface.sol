// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;
contract ChildChainVeInterface {
    address public token; // Child Chain Solid
    address public voter; // Child Chain Voter contract 
    address public nftBridge; // Parent chain NFT Bridge contract
    uint256 public chainId; // What chain are we on? 
    uint256 public totalSupply; // Total supply on mainnet will be same on child chain

    struct UserInfo { 
        address ownerOf;
        uint256 amount;
    }

    mapping(uint => uint) public attachments; // Is the nft attached to any gauges? 
    mapping (uint256 => UserInfo) public userInfo; // Mapping user tokenId to their ChildChain UserInfo
    mapping (uint256 => bool) internal alreadyMinted; // Maps all NFT mints
    
    /// @dev Mapping from NFT ID to delegated address.
    mapping(uint256 => address) internal idToDelegates;
    
    /// @dev Mapping from NFT ID to the address that owns it.
    mapping(uint256 => address) internal idToOwner;

    /// @dev Mapping from owner address to mapping of delegator addresses.
    mapping(address => mapping(address => bool)) internal ownerToDelegators;
    mapping (bytes32 => bytes) public errors; // Map bridge errors to errorId of error. 
    uint256 public minSigsRequired;

    event Attach(address indexed owner, address indexed gauge, uint256 tokenId);
    event Detach(address indexed owner, address indexed gauge, uint256 tokenId);
    //event SetAnycall(address oldProxy, address newProxy, address oldExec, address newExec);
    event Error(bytes32 indexed errorId);


    /**
     * @dev Emitted when `owner` enables `delegate` to vote with the `tokenId` token.
     */
    event Delegate(
        address indexed owner,
        address indexed delegate,
        uint256 indexed tokenId
    );

    /**
     * @dev Emitted when `owner` enables or disables `delegate` to vote with the all of its assets.
     */
    event DelegateForAll(
        address indexed owner,
        address indexed delegate,
        bool approved
    );

    //event Transfer(
    //    address indexed from,
    //    address indexed to,
    //    uint256 indexed tokenId
    //);

    event MinSignaturesSet(uint256 minSigs);

    function initialize (
        address _axelarGateway,
        address _axelarGasService,
        address _ccipRouter,
        address _lzEndpoint,
        address _voter,
        address _nftBridge,
        address _token,
        uint256 _chainId
    ) external {}

    function voted(uint256 _tokenId) public view returns (bool isVoted) {}

   /// NFT Functions, called by gauges ///
    function balanceOf(address _owner) public view returns (uint256) {}

   /// NFT Functions, called by gauges ///
    function balanceOfNFT(uint256 _tokenId) external view returns (uint256) {}

    function locked(uint256 _tokenId) external view returns (uint128 amount, uint256 end) {}

    /// @dev  Get token by index
    function tokenOfOwnerByIndex(address _owner, uint256 _tokenIndex) external view returns (uint256) {}

    function isApprovedOrOwner(address _user, uint256 _tokenId) external view returns (bool) {}

    function attach(uint256 _tokenId) external {}

    function detach(uint256 _tokenId) external {}

    function burn(uint256 _tokenId, uint256[] calldata _feeInEther, uint256 _providerBitmap) external payable {}

    // If there is an error, hopefully wont/shouldnt happen. We can retry processing the data. 
    function retryError(bytes32 _errorId) external {}

    function setAxelarGateway(address _axelarGateway) external {}
    function setAxelarGasService(address _axelarGasService) external {}
    function setCcipRouter(address _ccipRouter) external {}
    function setLzEndpoint(address _lzEndpoint) external {}
    function setNftBridge(address _nftBridge) external {}
    function setVoter(address _voter) external {}
    function setMinSigs(uint256 _minSigs) external {}

    function setTrustedRemoteAddress(uint16 _remoteChainId, bytes calldata _remoteAddress) external {}

    function getAxelarGateway() public view returns (address) {}
    function getAxelarGasService() public view returns (address) {}
    function getCcipRouter() public view returns (address) {}
    function getLzEndpoint() public view returns (address) {}

    /// @dev Set or reaffirm the delegatee address for an NFT. The zero address indicates there is no delegated address.
    ///      Throws unless `msg.sender` is the current NFT owner, or an authorized operator of the current owner.
    ///      Throws if `_tokenId` is not a valid NFT. (NOTE: This is not written the EIP)
    ///      Throws if `_approved` is the current owner. (NOTE: This is not written the EIP)
    /// @param _delegate Address to be approved for the given NFT ID.
    /// @param _tokenId ID of the token to be approved.
    function delegate(address _delegate, uint256 _tokenId) public {}

    /// @dev Enables or disables delegate status for a third party ("delegate") to vote
    ///      with all of `msg.sender`'s assets. It also emits the DelegateForAll event.
    ///      Throws if `_delegate` is the `msg.sender`. (NOTE: This is not written the EIP)
    /// @notice This works even if the sender doesn't own any tokens at the time.
    /// @param _delegate Address to add to the set of authorized delegates.
    /// @param _status True if the delegate is approved, false to revoke approval.
    function setDelegateForAll(address _delegate, bool _status) external {}

    function isDelegateOrOwner(address _voter, uint256 _tokenId)
        external
        view
        returns (bool)
    {}
}