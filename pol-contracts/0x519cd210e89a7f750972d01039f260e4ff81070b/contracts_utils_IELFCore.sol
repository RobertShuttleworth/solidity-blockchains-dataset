pragma solidity >=0.8.0 <0.9.0;

import './contracts_token_IERC721.sol';

interface IELFCore is IERC721{

    function isHatched(uint256 _tokenId) external view returns (bool res);
    function gainELF(uint _tokenId) external view returns (uint label, uint dad, uint mom, uint gene, uint bornAt, uint[] memory children);
}