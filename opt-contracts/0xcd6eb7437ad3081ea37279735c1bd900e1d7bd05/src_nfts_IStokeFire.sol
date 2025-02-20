// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IStokeFire {
    function tokenURI(uint256 id) external view returns (string memory);

    function beforeTransfer(
        address _from,
        address _to,
        uint256 _tokenId
    ) external;

    function afterTransfer(
        address _from,
        address _to,
        uint256 _tokenId
    ) external;
}