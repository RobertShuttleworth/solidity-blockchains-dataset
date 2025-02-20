// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./openzeppelin_contracts_utils_ReentrancyGuard.sol";


/* fMoney Burn Contract */

/*

A one-way deposit with no exits, permanently locking fBux in this contract.
From the records stored in this contract we'll mint the new fBux token on Sonic and award depositors their exact amounts.

*/

contract FbuxMigrationTracker is ReentrancyGuard{

    //EVENTS

    event FbuxMigrated(address indexed user, uint amount);
    event FbuxBurned(address indexed burnAddress, uint amount);
    event Paused(uint value);
    event UnPaused(uint value);

    // Stores user's migrated fBux
    struct MigrationInfo {
        uint totalAmount;
        bool exists;
    }

    IERC20 public fBux;

    // Track migration amounts per address
    mapping(address => MigrationInfo) public migrationinfo;

    // Keep track of all participating addresses
    address[] public addressList;

    // Has access to setPauser
    address public admin;

    // Pausing controller
    uint public pauser;

    // fBux Migration Tally.
    uint public totalFBuxMigrated;

    constructor(IERC20 _tokenAddress, address _admin) {
        fBux = _tokenAddress;
        admin = _admin;
        pauser = 1;
    }
    
    // Permanently lock fBux in this contract and store amt into userInfo
    function migrateFbux(uint amount) external nonReentrant() {
        require(pauser != 2, "Paused");
        require(amount != 0, "0");
        address caller = msg.sender;

        require(
            fBux.transferFrom(caller, address(this), amount), 
            "Transfer fail"
        );

        MigrationInfo storage userRecord = migrationinfo[caller];
        
        if (!userRecord.exists) {
            addressList.push(caller);
            userRecord.exists = true;
        }

        userRecord.totalAmount += amount;
        totalFBuxMigrated += amount;
        emit FbuxMigrated(caller, amount);
    }

    // Returns all participating addresses
    function getAddresses() external view returns (address[] memory) {
        return addressList;
    }

    // Returns migration details for a specific address
    function userMigrationDetails(address user) external view returns (uint, bool) {
        MigrationInfo memory userRecord = migrationinfo[user];
        return (userRecord.totalAmount, userRecord.exists);
    }

    // Returns number of participating addresses
    function getTotalParticipants() external view returns (uint) {
        return addressList.length;
    }

    // Returns fBux balance in the contract.
    function fBuxBal() public view returns (uint) {
        return fBux.balanceOf(address(this));
    }

    // Close out use of this contract and it's accounting in case of more migration phases.
    function setPauser(uint value) external {
        require(msg.sender == admin, "!Admin");
        require(value >= 1 && value <= 2, "!Range");
        pauser = value;

        if(value == 2){
            emit Paused(2);
        }

        if(value == 1){
            emit UnPaused(1);
        }
    }
}