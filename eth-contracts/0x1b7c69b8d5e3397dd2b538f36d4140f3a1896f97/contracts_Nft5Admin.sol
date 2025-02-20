// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./openzeppelin_contracts-upgradeable_access_OwnableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_security_PausableUpgradeable.sol";
import "./contracts_Nft5Storage.sol";
import "./hardhat_console.sol";

contract Nft5Admin is OwnableUpgradeable, PausableUpgradeable, Nft5Storage {
    function updatePriceOfHouse(
        uint256 _tokenId,
        uint256 _newPrice
    ) public onlyOwner {
        require(_newPrice > 0, "Price must be greater than zero");
        uint256 fractionCount = maxFraction[_tokenId];
        require(fractionCount > 0, "Token does not exist");
        housePrices[_tokenId] = _newPrice;
        fractionPrices[_tokenId] = _newPrice / fractionCount;
    }

    function updatePricesOfInternalToken(
        uint256 _newInternalPrice
    ) public onlyOwner {
        require(_newInternalPrice > 0, "Price must be greater than zero");
        internalValue = _newInternalPrice;
    }

    function updatePricesOfExternalToken(
        uint256 _newExternalPrice
    ) public onlyOwner {
        require(_newExternalPrice > 0, "Price must be greater than zero");
        externalValue = _newExternalPrice;
    }

    function setPause(bool _shouldPause) public onlyOwner {
        if (_shouldPause) {
            _pause();
        } else {
            _unpause();
        }
    }

    function getHoldersOfId(uint256 id) public view returns (address[] memory) {
        return tokenOwners[id];
    }

    function removeTokenOwner(uint256 tokenId, address owner) internal {
        address[] storage owners = tokenOwners[tokenId];
        uint256 length = owners.length;
        for (uint256 i = 0; i < length; ) {
            if (owners[i] == owner) {
                owners[i] = owners[length - 1];
                owners.pop();
                break;
            }
            unchecked {
                i++;
            }
        }
    }
}