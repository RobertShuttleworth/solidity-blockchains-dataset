// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./hardhat_console.sol";


import "./openzeppelin_contracts_access_AccessControl.sol";
import "./openzeppelin_contracts_token_ERC721_extensions_ERC721Pausable.sol";
import "./openzeppelin_contracts_utils_Pausable.sol";

import "./contracts_interface_2.i_Fish_CERTNFT.sol";

contract Fish_CERTNFT is I_Fish_CERTNFT, AccessControl, ERC721Pausable {

    
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    
    string private baseURI;
    
    uint256 public nftCounter;
    

    // This is the Minimum Implementation for the Relational Metadata Standard
    mapping(uint256 => uint256) private ipfsHistoryCounter_byTokenID;
    mapping(uint256 => mapping(uint256 => string)) private ipfsMetadataHistory_byTokenID;


    // leaf domain data
    mapping(uint256 => Fish_CERTNFT_Metadata) private nftMetaData_byTokenID;


    constructor(string memory _name, string memory _symbol, string memory _uri) AccessControl() ERC721(_name, _symbol) Pausable() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setRoleAdmin(MINTER_ROLE, DEFAULT_ADMIN_ROLE);
        
        baseURI = _uri;
        nftCounter = 0;
    }



    // Contract Meta Administration
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }



    // Public View Functions (protocol)
    //   Contract
    function totalSupply() external view returns ( uint256 ) {
        return nftCounter;
    }
    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    //   NFT
    function tokenURI(uint256 _tokenID) public view virtual override(ERC721) returns (string memory) {
        return string(abi.encodePacked(baseURI, nftMetaData_byTokenID[_tokenID].tokenIPFSURI));
    }
    function getTokenURI_history(uint256 _tokenID) external view returns (string[] memory) {
        
    }

   
    // public view functions (leaf domain)
    function getNFTMetadata(uint256 _tokenID) external view returns (Fish_CERTNFT_Metadata memory) {
        return nftMetaData_byTokenID[_tokenID];
    }
     
   

    // Role Controlled Action Functions
    function setTokenURI(uint256 _tokenID, string calldata _newIPFSMetdataURI) external onlyRole(MINTER_ROLE) {
        // Save the current URI in the history mapping
        uint256 currentCounter = ipfsHistoryCounter_byTokenID[_tokenID];
        ipfsMetadataHistory_byTokenID[_tokenID][currentCounter] = _newIPFSMetdataURI;

        // Increment the history counter for this token ID
        ipfsHistoryCounter_byTokenID[_tokenID] = currentCounter + 1;

        // Set the new URI
        nftMetaData_byTokenID[_tokenID].tokenIPFSURI = _newIPFSMetdataURI;

        emit TokenURIUpdatedEvent (_tokenID, nftMetaData_byTokenID[_tokenID].currentOwner, _newIPFSMetdataURI);
    }

    function mint(address _to, Fish_CERTNFT_Metadata memory _nftMetadata) external whenNotPaused onlyRole(MINTER_ROLE) returns(uint256){
        console.log("Fish_CERTNFT: mint");
        unchecked {
            nftCounter += 1;
        }
        _mint(_to, nftCounter);
        
        nftMetaData_byTokenID[nftCounter] = _nftMetadata;

        emit MintEvent( _to, nftCounter, _nftMetadata);
        return nftCounter;
    }


    // internal functions
    function _getTokenURI_history(uint256 _tokenID) internal view returns (string[] memory){
        uint256 historyCount = ipfsHistoryCounter_byTokenID[_tokenID];
        string[] memory fullHistory = new string[](historyCount);
        
        // Retrieve all previous URIs from history
        for (uint256 i = 0; i < historyCount; i++) {
            fullHistory[i] = ipfsMetadataHistory_byTokenID[_tokenID][i];
        }

        return fullHistory;
    }

    // Other Functions (maybe required for some external thing?)
    function supportsInterface(bytes4 interfaceId) public view virtual override(AccessControl, ERC721, IERC165) returns (bool) {
        return interfaceId == type(IAccessControl).interfaceId || super.supportsInterface(interfaceId) || interfaceId == type(IERC721).interfaceId;
    }
}