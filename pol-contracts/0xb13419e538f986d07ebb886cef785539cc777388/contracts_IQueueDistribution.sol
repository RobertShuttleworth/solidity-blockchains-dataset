//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IQueueDistribution {
    function incrementBalance(uint amount, uint queueId) external;
    function addToQueue(uint256 tokenId, uint256 quantity) external;
    function getCurrentIndex() external view returns (uint[3] memory);
    function claim(uint queueId) external;
}