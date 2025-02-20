// SPDX-License-Identifier: MIT-2
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.27;

import {ERC1155} from "./openzeppelin_contracts_token_ERC1155_ERC1155.sol";
import {ERC1155Burnable} from "./openzeppelin_contracts_token_ERC1155_extensions_ERC1155Burnable.sol";
import {ERC1155Pausable} from "./openzeppelin_contracts_token_ERC1155_extensions_ERC1155Pausable.sol";
import {Ownable} from "./openzeppelin_contracts_access_Ownable.sol";

contract Cafe3 is ERC1155, Ownable, ERC1155Pausable, ERC1155Burnable {
    mapping (uint256 => uint256) private _mintRates;

    constructor(address initialOwner)
        ERC1155("cafe3.xyz")
        Ownable(initialOwner)
    {
    }

    function setMintRate(uint256 tokenId, uint256 _rate) public onlyOwner{
        _mintRates[tokenId] = _rate;
    }

    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }
    
    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function mint(uint256 id, uint256 amount, bytes memory data)
        payable public
    {
        _requireNotPaused();
        require(amount > 0, "amount is not valid.");
        uint256 cost = _mintRates[id] * amount;        
        require(msg.value >= cost, "not enough ether sent");

        (bool success,) = payable(owner()).call{value: cost}("");
        require(success, "Payment failed.");
        _mint(msg.sender, id, amount, data);
    }

    function mintBatch(uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        payable public 
    {
        _requireNotPaused();
        require(ids.length > 0, "TokenIds not provided.");
        require(amounts.length > 0, "Amounts not provided.");
        uint256 cost = 0;
        for (uint256 i; i < ids.length; i++){
            require(amounts[i] > 0, "incorrect amount.");
            require(_mintRates[ids[i]] > 0, "incorrect tokenId.");
            cost += _mintRates[ids[i]] * amounts[i];
        }
        require(msg.value >= cost, "not enough ether sent.");

        (bool success,) = payable(owner()).call{value: cost}("");
        require(success, "Payment failed.");
        _mintBatch(msg.sender, ids, amounts, data);
    }

    function _update(address from, address to, uint256[] memory ids, uint256[] memory values)
        internal
        override(ERC1155, ERC1155Pausable)
    {
        super._update(from, to, ids, values);
    }
}