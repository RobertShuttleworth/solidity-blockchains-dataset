// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./openzeppelin_contracts_access_IAccessControl.sol";
import "./openzeppelin_contracts_token_ERC721_IERC721.sol";

import "./contracts_interface_0.FishStructs.sol";

interface I_Fish_CERTNFT is IAccessControl, IERC721   {

    event MintEvent ( address indexed _addr , uint256 indexed _fishNFT_id , Fish_CERTNFT_Metadata _nftMetadata);

    event TokenURIUpdatedEvent (uint256 indexed _fishNFT_id, address _currentOwner, string _newIPFSMetdataURI);

    // event rewardDistributorUpdatedEvent (uint256 indexed _fishNFT_id, address _currentOwner, address indexed oldRewardDistributor, address indexed newRewardDistributor);


    // contract meta administration
    function pause() external;
    function unpause() external;


    // contract public view
    function totalSupply() external view returns ( uint256 );


    // public actions
    function mint (address _to, Fish_CERTNFT_Metadata memory _nftMetadata) external returns(uint256);

    function setTokenURI(uint256 _tokenID, string calldata _newIPFSMetdataURI) external;
    function getTokenURI_history(uint256 _tokenID) external view returns (string[] memory);
    function getNFTMetadata(uint256 _tokenID) external view returns (Fish_CERTNFT_Metadata memory);

}