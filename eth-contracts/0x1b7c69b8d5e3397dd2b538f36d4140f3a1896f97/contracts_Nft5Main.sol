// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "./openzeppelin_contracts-upgradeable_token_ERC1155_ERC1155Upgradeable.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC1155_extensions_ERC1155BurnableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";
import "./openzeppelin_contracts-upgradeable_security_ReentrancyGuardUpgradeable.sol";
import "./contracts_Nft5Admin.sol";
import "./contracts_INft5.sol";
import "./hardhat_console.sol";

contract Nft5Main is
    Initializable,
    ERC1155Upgradeable,
    ERC1155BurnableUpgradeable,
    ReentrancyGuardUpgradeable,
    Nft5Admin
{
    uint256 private _totalBurnedTRY;
    INft5 public nftV3Contract;

    event TokenMinted(address indexed owner, uint256 indexed tokenId);
    event TokenReMinted(address indexed owner, uint256 indexed tokenId);
    event TokenBurned(address indexed from, uint256 indexed tokenId, uint256 fraction);

    function initialize(address _nftAddress) public initializer {
    require(_nftAddress != address(0), "!0x");
    nftV3Contract = INft5(_nftAddress);
    internalValue = nftV3Contract.getInternalValue();
    externalValue = nftV3Contract.getExternalValue();
    erc20Token = IMintableERC20(nftV3Contract.getErc20Token());
    __Ownable_init();

    }
    function mint(
        uint256 tokenId,
        uint256 fraction,
        uint256 housePrice,
        address _to,
        string memory data
    ) public nonReentrant onlyOwner {
        require(tokenId > 0 && !tokenMinted[tokenId], "!0x/ET");
        require(fraction > 0 && housePrice > 0, "NV");
        require(_to != address(0), "!0x");
        require(fractionalBalances[_to][tokenId] + fraction >= fractionalBalances[_to][tokenId], "Overflow error");
        maxFraction[tokenId] = fraction;
        nftV3Contract.mint( tokenId, fraction,_to, data);
        fractionalBalances[_to][tokenId] += fraction;
        if (!isAddressExists[tokenId][_to]) {
            tokenOwners[tokenId].push(_to);
            isAddressExists[tokenId][_to] = true;
        }
        tokenMinted[tokenId] = true;
        housePrices[tokenId] = housePrice;
        fractionPrices[tokenId] = housePrice / fraction;
        emit TokenMinted(_to, tokenId);
    }

    function remint(
        uint256 tokenId,
        uint256 fraction,
        uint256 _marketPriceOfToken,
        address _to,
        string memory data
    ) public whenNotPaused nonReentrant onlyOwner {
        require(fraction <= burnedFractions[tokenId], "NV");
        require(_marketPriceOfToken > 0, "NV");
        require(_to != address(0), "!0x");
        require(
            fraction > 0 && fraction <= maxFraction[tokenId],
            "NV"
        );
        uint256 _burnedFraction = burnedFractions[tokenId];
        uint256 singleFractionValue = fractionPrices[tokenId];
        uint256 _fractionalBalance = fractionalBalances[_to][tokenId];
        uint256 tryEgemOfSingleNft = (singleFractionValue * 100000000) /
            _marketPriceOfToken;
        require(_totalBurnedTRY >= (singleFractionValue * fraction), "FLG");
        _totalBurnedTRY = _totalBurnedTRY - (singleFractionValue * fraction);
        uint256 priceOfTotalRemintNft = tryEgemOfSingleNft *
            fraction *
            100000000;

        erc20Token.burnFrom(_to, priceOfTotalRemintNft); 
        nftV3Contract.mint( tokenId, fraction,_to, data);
        require(_burnedFraction >= fraction, "NV");
        burnedFractions[tokenId] = _burnedFraction - fraction;
        

        if (!isAddressExists[tokenId][_to]) {
            tokenOwners[tokenId].push(_to);
            isAddressExists[tokenId][_to] = true;
            fractionalBalances[_to][tokenId] = fraction;
        } else {
            fractionalBalances[_to][tokenId] = _fractionalBalance + fraction;
        }

        uint256 totalEGEMSupply = erc20Token.totalSupply();

        uint256 totalBurnedEGEM = singleFractionValue * fraction * 100000000;
        internalValue = totalEGEMSupply > 0
            ? (_totalBurnedTRY * 1e8 * 1e8) / totalEGEMSupply
            : 0;
       
        emit TokenReMinted(_to, tokenId);
    }

    function burnNft(
        uint256 tokenId,
        uint256 fraction,
        address _from,
        uint256 _marketPriceOfToken
    ) public whenNotPaused nonReentrant onlyOwner {
        
        require(
            _marketPriceOfToken > 0,
            "VL0"
        );
        require(
            fractionalBalances[_from][tokenId] >= fraction,
            "BLV"
        );
        require(
            fraction > 0 && fraction <= maxFraction[tokenId],
            "FLG"
        );
        require(
            _from != address(0),
            "!0x"
        );
        uint256 _fractionalBalance = fractionalBalances[_from][tokenId];
        uint256 _singleFractionValue = fractionPrices[tokenId];
        uint256 totalBurnedTRY = _totalBurnedTRY;
           

         nftV3Contract.burnNft( tokenId, fraction,_from);

        uint256 newFromBalance = _fractionalBalance - fraction;
        fractionalBalances[_from][tokenId] = newFromBalance;

        burnedFractions[tokenId] += fraction;

        uint256 tryEgemOfSingleNft = (_singleFractionValue * 100000000) /
            _marketPriceOfToken;

        uint256 priceOfTotalBurnNft = (tryEgemOfSingleNft * fraction) *
            100000000;

        erc20Token.mint(_from, priceOfTotalBurnNft); 

        _totalBurnedTRY += _singleFractionValue * fraction;

        totalBurnedTRY = _totalBurnedTRY;


        if (newFromBalance == 0) {
            removeTokenOwner(tokenId, _from);
            isAddressExists[tokenId][_from] = false;
        }
    
    internalValue =
            ((totalBurnedTRY * 100000000 * 100000000) /erc20Token.totalSupply());
            
        
        emit TokenBurned(_from, tokenId, fraction);
    }
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 fraction,
        string memory data
    ) public  nonReentrant  onlyOwner {        
        require(from != address(0) && to != address(0),"!0x00");
         require(
            fraction > 0 && fraction <= maxFraction[id],
            "BLV" );
        uint256 fromBalance = fractionalBalances[from][id];
        require(fromBalance >= fraction, "NV");
        require(from != to, "!0x");
        nftV3Contract.safeTransferNft(from,to,id,fraction,data);
        require(fractionalBalances[from][id] >= fraction, "BLV");
        fractionalBalances[from][id] -= fraction;
        fractionalBalances[to][id] += fraction;
        
        if (!isAddressExists[id][to]) {
            tokenOwners[id].push(to);
            isAddressExists[id][to] = true;
        }
       
        if (fractionalBalances[from][id] == 0) {
        removeTokenOwner(id, from);
        isAddressExists[id][from] = false;
    }
    }

    function getBalance(address account, uint256 tokenId) external view returns (uint256) {
        return fractionalBalances[account][tokenId];
    }
    

}