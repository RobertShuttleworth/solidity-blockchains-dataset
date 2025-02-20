// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.24;

// ######################################%@##############################r###########
// bona fide edge of the line that divides reality from fiction, 2024

import {Strings} from "./node_modules_openzeppelin_contracts_utils_Strings.sol";
import {Ownable} from "./node_modules_solady_src_auth_Ownable.sol";

contract CloudlinesStore is Ownable {

    event CloudlinesItemPurchased (address recipient, bytes32 playerKey, uint32 itemId);

    address public recipientAddress;

    uint256 public sponsorPrice;

    mapping(uint32 => uint256) public itemPrices;
    mapping(uint32 => bool) public priceSet;

    constructor(
        string memory _name,
        string memory _symbol
    ) {
        _initializeOwner(msg.sender);
    }

    function setSponsorPrice(uint256 price) public onlyOwner {
        sponsorPrice = price;
    }

    function setItemPrice(uint32 itemId, uint256 price) public onlyOwner {
        itemPrices[itemId] = price;
        priceSet[itemId] = true;
    }

    function setRecipient(address recipient) public onlyOwner {
        require(recipient != address(0), "Invalid recipient address");
        recipientAddress = recipient;
    }

    function getItemPrice(uint32 itemId) public view returns (uint256) {
        return itemPrices[itemId];
    }


    function purchaseItem(address recipient, bytes32 playerKey, uint32 itemId) public payable returns (uint256) {
        require(priceSet[itemId], "Item price not set");
        require(msg.value >= itemPrices[itemId], "Insufficient payment");
        require(recipientAddress != address(0), "Recipient address not set");

        (bool success, ) = recipientAddress.call{value: msg.value}("");
        require(success, "Transfer failed");

        emit CloudlinesItemPurchased(recipient, playerKey, itemId);

        return 0;
    }

    function purchaseItem(address recipient, bytes32 playerKey, uint32[] memory itemId) public payable returns (uint256) {
        uint256 totalPrice = 0;
        for (uint i = 0; i < itemId.length; i++) {
            require(priceSet[itemId[i]], "Item price not set");
            totalPrice += itemPrices[itemId[i]];
        }
        require(msg.value >= totalPrice, "Insufficient payment");
        require(recipientAddress != address(0), "Recipient address not set");

        (bool success, ) = recipientAddress.call{value: msg.value}("");
        require(success, "Transfer failed");

        for (uint i = 0; i < itemId.length; i++) {
            emit CloudlinesItemPurchased(recipient, playerKey, itemId[i]);
        }
    
        return 0;
    }
}