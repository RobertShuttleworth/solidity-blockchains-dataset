// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./openzeppelin_contracts_utils_structs_EnumerableSet.sol";
import "./openzeppelin_contracts_access_AccessControl.sol";
import "./openzeppelin_contracts_utils_Pausable.sol";

import "./contracts_interface_2.i_Fish_CERTNFT.sol";
import "./contracts_interface_3.i_Fish_RewardERC20.sol";

import "./contracts_6.Fish_Staking_Slave.sol";


import "./contracts_interface_5.i_Fish_Staking_Master.sol";

contract Fish_Staking_Master is I_Fish_Staking_Master, AccessControl, Pausable {

    bytes32 public constant DEPOSIT_ROLE = keccak256("DEPOSIT_ROLE");


    I_Fish_CERTNFT NFT;
    I_Fish_RewardERC20 ERC20;

    
    uint8 public PoolCtr;
    uint8 public activePool_index;
    mapping(uint8 => RetailCERTPoolMetaData) public poolsContainer;


    mapping(address => mapping(uint256 => bool)) private ownedNFT_byUserByID; // NFT Map
    mapping(address => uint256) private totalPower_byUser; // user total power
    mapping(address => uint8) private latestActivePool_byUser;
    mapping(address => mapping(uint8 => uint256)) private totalClaimedRewards_byUserByPoolIndex;

    mapping(uint256 => mapping(address => bool)) public initMaps;


    constructor(I_Fish_CERTNFT _nft, I_Fish_RewardERC20 _erc20) Pausable() AccessControl() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

        ERC20 = _erc20;
        NFT = _nft;
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function createPool(
        uint256 _rewardsPerBlock,
        uint256 _startBlock,
        uint256 _endBlock
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(PoolCtr < 25, "Hard Limit of 25 pool ");

        uint256 requiredPoolERC20Balance = _rewardsPerBlock * (_endBlock - _startBlock);
        // require(ERC20.balanceOf(address(this)) >= requiredPoolERC20Balance, "Master contract must have enough balance to support new slave");

        if (PoolCtr > 0) {
            require(poolsContainer[PoolCtr - 1].endBlock == _startBlock, "Pools must be consecutive");
        }

        poolsContainer[PoolCtr].startBlock = _startBlock;
        poolsContainer[PoolCtr].endBlock = _endBlock;
        // TODO: mint erc20

        Fish_Staking_Slave newPool = new Fish_Staking_Slave(
            ERC20,
            _rewardsPerBlock,
            _startBlock,
            _endBlock,
            msg.sender,
            PoolCtr
        );

        // Store metadata in the poolsContainer mapping
         RetailCERTPoolMetaData memory poolMetaData = RetailCERTPoolMetaData({
            startBlock: _startBlock,
            endBlock: _endBlock,
            rewardsPerBlock: _rewardsPerBlock,
            poolContractAddress: address(newPool),
            poolIndex: PoolCtr,
            initialised: false,
            completed: false
        });
        poolsContainer[PoolCtr] = poolMetaData;

        ERC20.mint(address(newPool), requiredPoolERC20Balance);

        emit CreatePoolEvent(PoolCtr, poolMetaData);

        PoolCtr = PoolCtr + 1;
    }


    // Admin Domain Specific Functions
    function depositFor_admin(address _nftHoldingAddress, address _forAddress, uint256[] memory _CERTNFT_ids_list) external onlyRole(DEPOSIT_ROLE) {
        iDeposit_unSafe(_nftHoldingAddress, _forAddress, _CERTNFT_ids_list);
    }
    function claimFor_admin(address _forAddress) external onlyRole(DEPOSIT_ROLE) {
        iClaim_unSafe(_forAddress);
    }
    function withdrawFor_admin(address _forAddress, uint256[] memory _CERTNFT_ids_list) external onlyRole(DEPOSIT_ROLE) {
        iWithdraw_unSafe(_forAddress, _CERTNFT_ids_list);
    }


    // view functions for dApp
    function getPendingRewardsPrimingData(address _user) external view returns (address[] memory, uint256) {
        uint256 size = activePool_index - latestActivePool_byUser[_user] + 1;
        address[] memory poolAddress_list = new address[](size);
        
        // console.log("Fish_Staking_Master: getPendingRewardsPrimingData: activePool_index: ", activePool_index);
        // console.log("Fish_Staking_Master: getPendingRewardsPrimingData: latestActivePool_byUser[_user]: ", latestActivePool_byUser[_user]);
        // console.log("Fish_Staking_Master: getPendingRewardsPrimingData: size: ", size);

        uint8 returnIndex = 0;
        for (uint8 i=latestActivePool_byUser[_user];i<=activePool_index;i++) {
            // console.log("Fish_Staking_Master: getPendingRewardsPrimingData: i: ", i);
            // console.log("Fish_Staking_Master: getPendingRewardsPrimingData: poolsContainer[i].poolContractAddress: ", poolsContainer[i].poolContractAddress);
            poolAddress_list[returnIndex] = poolsContainer[i].poolContractAddress;
            returnIndex += 1;
        }

        return (poolAddress_list, totalPower_byUser[_user]);
    }

    function getClaimedRewards_byPool() external view returns (uint256[] memory) {
        // Allocate memory for the array with a size equal to PoolCtr
        uint256[] memory toReturn = new uint256[](PoolCtr);

        // Populate the array with claimed rewards by pool
        for (uint8 i = 0; i < PoolCtr; i++) {
            toReturn[i] = totalClaimedRewards_byUserByPoolIndex[msg.sender][i];
        }

        // Return the populated array
        return toReturn;
    }

    // User Function
    function deposit(uint256[] memory _CERTNFT_ids_list) external whenNotPaused {
        iDeposit_unSafe(msg.sender, msg.sender, _CERTNFT_ids_list);
    }
    function claim() external whenNotPaused {
        iClaim_unSafe(msg.sender);
    }
    function withdraw(uint256[] memory _CERTNFT_ids_list) external whenNotPaused {
        iWithdraw_unSafe(msg.sender, _CERTNFT_ids_list);
    }


    // function emergencyWithdrawAdmin(address _addr , uint256 _tokenID ) external onlyRole(DEFAULT_ADMIN_ROLE) {
    //     require(NFTMap[_addr][_tokenID] == true ,"Token not deposited");
    //     NFT.safeTransferFrom(address(this), _addr, _tokenID);
    //     NFTMap[_addr][_tokenID] = false;
    //     Fish_CERTNFT_Metadata memory data = NFT.getNFTMetadata(_tokenID);
    //     userAmt[msg.sender] = userAmt[msg.sender] - data.power;

    //     // Update Reward Debt in pools
    //     for ( uint256 i = 0 ; i < PoolCtr ; i ++ ){
    //         Fish_Staking_Slave pool =  Fish_Staking_Slave(poolsContainer[i]);
    //         pool.emergencyWithdrawAdmin(msg.sender, data.power );
    //     }

    //     emit EmergencyWithdraw(_addr, data.power , _tokenID);
    // }


    // internal functions
    function iDeposit_unSafe(
        address _nftHoldingAddress, 
        address _depositFor, 
        uint256[] memory _CERTNFT_ids_list
    ) internal {
        // Validate the input list
        require(_CERTNFT_ids_list.length > 0, "deposit: list must be longer than zero items");
        require(_CERTNFT_ids_list.length <= 20, "deposit: list must be <= 20 items");

        uint256 userTotalPower = totalPower_byUser[_depositFor];

        // Ensure all relevant pools are initialized based on real data
        iIterateActivePool();

        // Get rewards and pool indices from iUpdateUserToActivePool_unSafe
        (uint256[] memory claimedRewards, uint8[] memory poolIndices) = iUpdateUserToActivePool_unSafe(
            _depositFor, 
            userTotalPower, 
            activePool_index
        );

        // Transfer NFTs and calculate total power to deposit
        uint256 totalPowerToDeposit = 0;
        for (uint256 i = 0; i < _CERTNFT_ids_list.length; i++) {
            require(
                ownedNFT_byUserByID[_depositFor][_CERTNFT_ids_list[i]] == false, 
                "Token already deposited"
            );
            Fish_CERTNFT_Metadata memory data = NFT.getNFTMetadata(_CERTNFT_ids_list[i]);
            require(data.isWhale == false, "Cannot stake Whale CERTs in this Pool");
            
            NFT.safeTransferFrom(_nftHoldingAddress, address(this), _CERTNFT_ids_list[i]);
            ownedNFT_byUserByID[_depositFor][_CERTNFT_ids_list[i]] = true;

            totalPowerToDeposit += data.power;
        }

        // Deposit into the active pool
        Fish_Staking_Slave pool = Fish_Staking_Slave(poolsContainer[activePool_index].poolContractAddress);
        uint256 activePoolReward = pool.deposit(_depositFor, userTotalPower, totalPowerToDeposit);

        // Append the active pool reward and index to the arrays
        uint256[] memory finalClaimedRewards = new uint256[](claimedRewards.length + 1);
        uint8[] memory finalPoolIndices = new uint8[](poolIndices.length + 1);

        for (uint256 i = 0; i < claimedRewards.length; i++) {
            finalClaimedRewards[i] = claimedRewards[i];
            finalPoolIndices[i] = poolIndices[i];

            totalClaimedRewards_byUserByPoolIndex[_depositFor][poolIndices[i]] += claimedRewards[i];
        }
        finalClaimedRewards[claimedRewards.length] = activePoolReward;
        finalPoolIndices[poolIndices.length] = activePool_index;



        // Update the user's total power
        totalPower_byUser[_depositFor] = userTotalPower + totalPowerToDeposit;

        // Emit the event with the updated arrays
        emit DepositEvent(_depositFor, _CERTNFT_ids_list, totalPowerToDeposit, finalClaimedRewards, finalPoolIndices);
    }

    function iClaim_unSafe(address _claimFor) internal {
        // Ensure all relevant pools are initialized based on real data
        uint256 userTotalPower = totalPower_byUser[_claimFor];

        // Get rewards and pool indices from iUpdateUserToActivePool_unSafe
        (uint256[] memory claimedRewards, uint8[] memory poolIndices) = iUpdateUserToActivePool_unSafe(
            _claimFor,
            userTotalPower,
            activePool_index + 1
        );

        // Fetch the active pool reward
        Fish_Staking_Slave activePool = Fish_Staking_Slave(poolsContainer[activePool_index].poolContractAddress);
        uint256 activePoolReward = activePool.claim(_claimFor, userTotalPower);

        // Append the active pool reward and index to the arrays
        uint256[] memory finalClaimedRewards = new uint256[](claimedRewards.length + 1);
        uint8[] memory finalPoolIndices = new uint8[](poolIndices.length + 1);

        for (uint256 i = 0; i < claimedRewards.length; i++) {
            finalClaimedRewards[i] = claimedRewards[i];
            finalPoolIndices[i] = poolIndices[i];

            totalClaimedRewards_byUserByPoolIndex[_claimFor][poolIndices[i]] += claimedRewards[i];
        }
        finalClaimedRewards[claimedRewards.length] = activePoolReward;
        finalPoolIndices[poolIndices.length] = activePool_index;

        // Emit the event with the updated arrays
        emit ClaimEvent(_claimFor, finalClaimedRewards, finalPoolIndices);
    }

    function iWithdraw_unSafe(address _withdrawFor, uint256[] memory _CERTNFT_ids_list) internal {
        require(_CERTNFT_ids_list.length > 0, "withdraw: list of NFTs must be longer than zero");
        require(_CERTNFT_ids_list.length <= 20, "withdraw: list must be <= 20 items");

        uint userTotalPower = totalPower_byUser[_withdrawFor];

        // Ensure all relevant pools are initialized based on real data
        iIterateActivePool();

        // Get rewards and pool indices from iUpdateUserToActivePool_unSafe
        (uint256[] memory claimedRewards, uint8[] memory poolIndices) = iUpdateUserToActivePool_unSafe(
            _withdrawFor, 
            userTotalPower, 
            activePool_index
        );

        // Bring the token into the master contract
        uint256 totalPowerToWithdraw = 0;
        for (uint256 i = 0; i < _CERTNFT_ids_list.length; i++) {
            require(
                ownedNFT_byUserByID[_withdrawFor][_CERTNFT_ids_list[i]] == true, 
                "Token not deposited"
            );
            NFT.safeTransferFrom(address(this), _withdrawFor, _CERTNFT_ids_list[i]);
            ownedNFT_byUserByID[_withdrawFor][_CERTNFT_ids_list[i]] = false;

            Fish_CERTNFT_Metadata memory data = NFT.getNFTMetadata(_CERTNFT_ids_list[i]);
            totalPowerToWithdraw += data.power;
        }

        // Withdraw from the active pool
        Fish_Staking_Slave pool = Fish_Staking_Slave(poolsContainer[activePool_index].poolContractAddress);
        uint256 activePoolReward = pool.withdraw(_withdrawFor, userTotalPower, totalPowerToWithdraw);

        // Append the new reward and pool index to the arrays
        uint256[] memory finalClaimedRewards = new uint256[](claimedRewards.length + 1);
        uint8[] memory finalPoolIndices = new uint8[](poolIndices.length + 1);

        for (uint256 i = 0; i < claimedRewards.length; i++) {
            finalClaimedRewards[i] = claimedRewards[i];
            finalPoolIndices[i] = poolIndices[i];

            totalClaimedRewards_byUserByPoolIndex[_withdrawFor][poolIndices[i]] += claimedRewards[i];
        }
        finalClaimedRewards[claimedRewards.length] = activePoolReward;
        finalPoolIndices[poolIndices.length] = activePool_index;

        // Update the user's total power
        totalPower_byUser[_withdrawFor] = userTotalPower - totalPowerToWithdraw;

        // Emit the event with the updated arrays
        emit WithdrawEvent(_withdrawFor, _CERTNFT_ids_list, totalPowerToWithdraw, finalClaimedRewards, finalPoolIndices);
    }


    
    function iUpdateUserToActivePool_unSafe(
        address _claimFor, 
        uint256 _userTotalPower, 
        uint8 _targetPoolIndex
    ) 
        internal 
        returns (uint256[] memory rewards, uint8[] memory poolIndices) 
    {
        // Initialize dynamic arrays to store rewards and pool indices
        uint256[] memory claimedRewards = new uint256[](_targetPoolIndex - latestActivePool_byUser[_claimFor]);
        uint8[] memory claimedPoolIndices = new uint8[](_targetPoolIndex - latestActivePool_byUser[_claimFor]);
        
        uint256 counter = 0; // Track the index for dynamic arrays

        // Loop through all the completed, previous pools and process claims
        if (latestActivePool_byUser[_claimFor] < activePool_index) {
            for (uint8 i = latestActivePool_byUser[_claimFor]; i < _targetPoolIndex; i++) {
                Fish_Staking_Slave poolContract = Fish_Staking_Slave(poolsContainer[i].poolContractAddress);
                uint256 reward = poolContract.claim(_claimFor, _userTotalPower);

                // Store the reward and its pool index
                claimedRewards[counter] = reward;
                claimedPoolIndices[counter] = i;
                counter++;
            }

            // Update the user's latest active pool index
            latestActivePool_byUser[_claimFor] = activePool_index;
        }

        return (claimedRewards, claimedPoolIndices);
    }

    
    
    // internal functions for intraContract protocol
    function iIterateActivePool() internal {
        RetailCERTPoolMetaData memory thisPoolMetaData;
        Fish_Staking_Slave prevPoolContract;
        uint256 prevPoolTotalPower;

        for (uint8 i = activePool_index; i < PoolCtr; i++) {
            thisPoolMetaData = poolsContainer[i];
            if (thisPoolMetaData.startBlock < block.number) {
                if (thisPoolMetaData.initialised == false) {
                    // so we need to initalise this pool
                    if (i > 0) {
                        // prevPoolMetaData = poolsContainer[i-1];
                        // if (prevPoolMetaData.completed == false) {
                        prevPoolContract = Fish_Staking_Slave(poolsContainer[i - 1].poolContractAddress);
                        prevPoolTotalPower = prevPoolContract.completeContractAndGetPoolTotalPower();
                        poolsContainer[i - 1].completed = true;
                        // }
                    }

                    Fish_Staking_Slave thisPoolContract = Fish_Staking_Slave(poolsContainer[i].poolContractAddress);
                    thisPoolContract.initialisePool(prevPoolTotalPower);
                    poolsContainer[i].initialised = true;
                    activePool_index = i;
                }
            } else {
                break;
            }
        }
    }



    // Other Functions (maybe required for some external thing?)
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4) {
        return 0x150b7a02;
    }
    function supportsInterface(bytes4 interfaceId) public view virtual override(AccessControl) returns (bool) {
        return interfaceId == type(IAccessControl).interfaceId || super.supportsInterface(interfaceId) || interfaceId == type(IERC721).interfaceId;
    }
}