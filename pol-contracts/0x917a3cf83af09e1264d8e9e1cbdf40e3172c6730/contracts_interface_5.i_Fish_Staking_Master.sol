// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface I_Fish_Staking_Master {
    // Events
    event CreatePoolEvent(uint8 poolIndex, RetailCERTPoolMetaData poolMetaData);
    
    event DepositEvent(address indexed _user, uint256[] _CERTNFT_ids_list, uint256 _totalPower, uint256[] _claimedRewards, uint8[] _claimFromPoolIndicies);
    event ClaimEvent(address indexed _user, uint256[] _claimedRewards, uint8[] _claimFromPoolIndicies);
    event WithdrawEvent(address indexed _user,uint256[] _CERTNFT_ids_list, uint256 _totalPower, uint256[] _claimedRewards, uint8[] _claimFromPoolIndicies);
    // event EmergencyWithdraw(address indexed _user, uint256 _tokenID, uint256 _power );
    

    // Struct (only for understanding the interface, not part of interface definition)
    struct RetailCERTPoolMetaData {
        uint256 startBlock;
        uint256 endBlock;
        uint256 rewardsPerBlock;
        address poolContractAddress;
        uint8 poolIndex;
        bool initialised;
        bool completed;
    }

    // // Public Variables
    // function PoolCtr() external view returns (uint8);
    // function activePool_index() external view returns (uint8);
    // function poolsContainer(uint8 index) external view returns (RetailCERTPoolMetaData memory);
    // function ownedNFT_byUserByID(address user, uint256 tokenID) external view returns (bool);
    // function totalPower_byUser(address user) external view returns (uint256);
    // function latestActivePool_byUser(address user) external view returns (uint8);
    // function initMaps(uint256 poolID, address user) external view returns (bool);

    // Public/External Functions
    function pause() external;
    function unpause() external;

    function createPool(
        uint256 _rewardsPerBlock,
        uint256 _startBlock,
        uint256 _endBlock
    ) external;

    function depositFor_admin(address _nftHoldingAddress, address _forAddress, uint256[] memory _CERTNFT_ids_list) external;
    function claimFor_admin(address _forAddress) external;
    function withdrawFor_admin(address _forAddress, uint256[] memory _CERTNFT_ids_list) external;

    function deposit(uint256[] memory _CERTNFT_ids_list) external;
    function claim() external;
    function withdraw(uint256[] memory _CERTNFT_ids_list) external;
}