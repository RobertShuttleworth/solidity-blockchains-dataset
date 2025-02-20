// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Define the interface for Nft4 contract
interface INft5 {
    function mint(uint256 tokenId, uint256 fraction, address _to, string memory data) external;
    function remint(uint256 tokenId,uint256 fraction,uint256 _marketPriceOfToken,address _to,string memory data) external; 
    function burnNft(uint256 tokenId,uint256 fraction,address _from) external;
    function safeTransferNft(address  _from,address  _to,uint256 _tokenId, uint256 _fraction,string memory _data) external;
    function updatePriceOfHouse(uint256 tokenId, uint256 newPrice) external;
    function approveMinter(address addr) external;
    function getAdmin() external view returns (address);
    function getErc20Token() external view returns (address);
    function getInternalValue() external view returns (uint);
    function getExternalValue() external view returns (uint);


}