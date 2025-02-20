// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.27;

interface IFIDTokenFactory {
    event FIDTokenCreated(
        address indexed factoryAddress,
        address indexed tokenCreator,
        address platformReferrer,
        address protocolFeeRecipient,
        address bondingCurve,
        string tokenURI,
        string name,
        string symbol,
        address tokenAddress,
        address poolAddress,
        uint256 platformReferrerFeeBps,
        uint256 orderReferrerFeeBps,
        uint256 fid,
        uint256 allocatedSupply
    );

    function deploy(
        address _tokenCreator,
        address _platformReferrer,
        string memory _tokenURI,
        string memory _name,
        string memory _symbol,
        uint256 _platformReferrerFeeBps,
        uint256 _orderReferrerFeeBps,
        uint256 _allocatedSupply,
        uint256 _fid,
        uint256 _deadline,
        bytes calldata _sig
    ) external payable returns (address);
} 