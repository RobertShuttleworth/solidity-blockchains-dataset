// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {CrowdFunding} from "./src_CrowdFunding.sol";

contract CrowdFundingFactory {
    address public owner;
    bool public paused;

    struct Campaign {
        address campaignAddress;
        address owner;
        string name;
        uint256 createdAt;
    }

    Campaign[] public campaigns;
    mapping(address => Campaign[]) public userCampaigns;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not Factory owner.");
        _;
    }

    modifier notPaused() {
        require(!paused, "Factory is paused.");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function createCampaign(
        string memory _name,
        string memory _description,
        uint256 _goal,
        uint256 _durationInDays
    ) external notPaused {
        address sender = msg.sender;
        CrowdFunding newCampaign = new CrowdFunding(
            sender,
            _name,
            _description,
            _goal,
            _durationInDays
        );
        address compaignAddress = address(newCampaign);

        Campaign memory campaign = Campaign({
            campaignAddress: compaignAddress,
            owner: sender,
            name: _name,
            createdAt: block.timestamp
        });
        campaigns.push(campaign);
        userCampaigns[sender].push(campaign);
    }

    function togglePaused() external onlyOwner {
        paused = !paused;
    }

    function getAllCampaigns() external view returns (Campaign[] memory) {
        return campaigns;
    }

    function getUserCampaigns(
        address _user
    ) external view returns (Campaign[] memory) {
        return userCampaigns[_user];
    }
}