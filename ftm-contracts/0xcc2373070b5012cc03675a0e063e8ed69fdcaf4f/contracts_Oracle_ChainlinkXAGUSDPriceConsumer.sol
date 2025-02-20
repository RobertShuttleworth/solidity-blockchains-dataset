// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./pythnetwork_pyth-sdk-solidity_IPyth.sol";
import "./pythnetwork_pyth-sdk-solidity_PythStructs.sol";

contract ChainlinkXAGUSDPriceConsumer {

    IPyth pyth;
    bytes32 priceId;
    PythStructs.Price public price;
    
    constructor(address pythContract, bytes32 _priceId) {
        pyth = IPyth(pythContract);
        priceId =  _priceId;
    }

    /**
     * Returns the latest price
     */
    function updatePrice(bytes[] calldata priceUpdateData) public payable{
        // Update the on-chain Pyth price
        uint fee = pyth.getUpdateFee(priceUpdateData);
        pyth.updatePriceFeeds{ value: fee }(priceUpdateData);
    }

    function getLatestPrice() public view returns(int){
        return ((pyth.getPriceUnsafe(priceId).price)/1e5);
    }

    //price reset : PID controller
    function getDecimals() public payable returns (uint8) {
        return uint8(uint32(price.expo));
    }
}