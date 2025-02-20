// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./openzeppelin_contracts_token_ERC721_IERC721.sol";
import "./openzeppelin_contracts-upgradeable_utils_ReentrancyGuardUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";
import "./openzeppelin_contracts-upgradeable_proxy_utils_UUPSUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_access_OwnableUpgradeable.sol";

contract Lock4PassV1 is Initializable, UUPSUpgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    IERC20 public ttToken; // TT token address
    IERC20 public attToken; // ATT token address
    IERC721 public passcard; // Passcard address
    
    uint256 ATT_FEE_RATE; //  300 / 10000 = 3%
    address ATT_FEE_HOLDER;
    uint256 TT_FEE_RATE; //  300 / 10000 = 3%
    address TT_FEE_HOLDER;
    uint256 public UNLOCK_DURATION;
    uint256 public INITIAL_TOKEN_ID; // 20000
    uint256 public SUPPLY_LIMIT; // 15360
    
    function initialize(
        address ttTokenAddress,
        address attTokenAddress,
        address passcardAddress,
        uint256 attFeeRate,
        address attFeeHolder,
        uint256 ttFeeRate,
        address ttFeeHolder,
        uint256 unlockDuration
    ) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        ttToken = IERC20(ttTokenAddress);
        attToken = IERC20(attTokenAddress);
        passcard = IERC721(passcardAddress);
        ATT_FEE_RATE = attFeeRate;
        ATT_FEE_HOLDER = attFeeHolder;
        TT_FEE_RATE = ttFeeRate;
        TT_FEE_HOLDER = ttFeeHolder;
        UNLOCK_DURATION = unlockDuration;
        INITIAL_TOKEN_ID = 1;
        SUPPLY_LIMIT = 1679;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    bool public isPausingForOperation;

    // Lock Rule
    struct LockRule {
        uint256 ruleId;
        bool isValid;
        uint256 ttAmount;
        uint256 attAmount;
        uint256 passcardRewards;
    }
    mapping(uint256 => LockRule) public lockRules;

    // User Info
    mapping(address => uint256) public userCurrentLockedId;
    mapping(address => bool) public isUserStaked;

    struct LockInfo {
        uint256 lockId;
        address userAddress;
        uint256 ttAmount;
        uint256 attAmount;
        uint256 lockTime;
        uint256 duration;
        uint256 unlockTime;
        uint256 passcardCnt;
        bool isWithdrawn;
    }
    
    mapping(address => mapping(uint256 => LockInfo)) public userLockInfo;

    event Lock(address indexed user, uint256 lockId, uint256 ttAmount, uint256 attAmount, uint256 passcardCnt, uint256 lockDuration);
    event Unlock(address indexed user, uint256 lockId, uint256 ttAmount, uint256 attAmount);
    event UnlockDurationChanged(uint256 oldDuration, uint256 newDuration);

    /*
     * User Functions
     */
    function lock(uint256 ruleId, uint256 ttAmount, uint256 attAmount) public nonReentrant {
        require(!isPausingForOperation, "Contract is pausing for operation.");
        require(isUserStaked[msg.sender] != true, "Contract is pausing for operation.");
        require(ttAmount > 0 || attAmount > 0, "No TT token to lock.");
        require(SUPPLY_LIMIT > 0, "No more passcard.");

        LockRule memory rule = lockRules[ruleId];
        require(rule.isValid, "Lock rule is invalid.");
        require(rule.attAmount == attAmount, "Invalid stake amount.");

        uint256 ttLockAmount = 0;
        uint256 attLockAmount = 0;
        uint256 multiplyer = 0;

        if (rule.ttAmount > 0) {
            require(ttAmount > 0, "Amount must be greater than zero");
            require(ttAmount % rule.ttAmount == 0, "Invalid lock amount.");
            multiplyer = ttAmount / rule.ttAmount;

            // TT
            ttLockAmount = _processTokenTransfer(ttToken, msg.sender, TT_FEE_HOLDER, address(this), ttAmount, TT_FEE_RATE);

            // ATT
            if (rule.attAmount > 0) {
                attAmount = rule.attAmount * multiplyer;
                attLockAmount = _processTokenTransfer(attToken, msg.sender, ATT_FEE_HOLDER, address(this), attAmount, ATT_FEE_RATE);
            }
        } else {
            require(attAmount > 0, "Amount must be greater than zero");
            require(attAmount % rule.attAmount == 0, "Invalid lock amount.");
            multiplyer = attAmount / rule.attAmount;

            // ATT
            attLockAmount = _processTokenTransfer(attToken, msg.sender, ATT_FEE_HOLDER, address(this), attAmount, ATT_FEE_RATE);
        }

        uint256 passcardCnt = rule.passcardRewards * multiplyer;
        // transfer passcard to user
        for (uint256 i = 0; i < passcardCnt; i++) {
            uint256 tokenId = INITIAL_TOKEN_ID + i;
            passcard.safeTransferFrom(address(this), msg.sender, tokenId);
        }
        INITIAL_TOKEN_ID += passcardCnt;
        SUPPLY_LIMIT -= passcardCnt;

        userCurrentLockedId[msg.sender] += 1;
        uint256 currentId = userCurrentLockedId[msg.sender];
        uint256 unlockTime = block.timestamp + UNLOCK_DURATION * 1 days;

        userLockInfo[msg.sender][currentId] = LockInfo(currentId, msg.sender, ttLockAmount, attLockAmount, block.timestamp, UNLOCK_DURATION, unlockTime, passcardCnt, false);
        isUserStaked[msg.sender] = true;
        
        emit Lock(msg.sender, currentId, ttLockAmount, attLockAmount, passcardCnt, UNLOCK_DURATION);
    }

    function _processTokenTransfer(
        IERC20 token,
        address from,
        address feeHolder,
        address to,
        uint256 amount,
        uint256 feeRate
    ) internal returns (uint256) {
        uint256 fee = amount * feeRate / 10000;
        uint256 netAmount = amount - fee;
        require(token.transferFrom(from, feeHolder, fee), "Fee transfer failed.");
        require(token.transferFrom(from, to, netAmount), "Locking transfer failed.");
        return netAmount;
    }
 
    function unlock(uint256 lockId) public nonReentrant {
        require(!isPausingForOperation, "Contract is pausing for operation.");
        LockInfo memory lockInfo = userLockInfo[msg.sender][lockId];
        require(block.timestamp >= lockInfo.unlockTime, "Unlock is not available yet. Please wait until the specified date.");
        require(!lockInfo.isWithdrawn, "Already unlocked.");

        if (lockInfo.ttAmount > 0) {
            ttToken.transfer(msg.sender, lockInfo.ttAmount);
        }
        
        if (lockInfo.attAmount > 0) {
            attToken.transfer(msg.sender, lockInfo.attAmount);
        }

        userLockInfo[msg.sender][lockId].isWithdrawn = true;

        emit Unlock(msg.sender, lockInfo.lockId, lockInfo.ttAmount, lockInfo.attAmount);
    }


    /*
     * Contract Admin Functions
     */
    function pausingForOperation() public onlyOwner {
        isPausingForOperation = true;
    }

    function operationCompleted() public onlyOwner {
        isPausingForOperation = false;
    }

    function setATT_FEE_RATE(uint256 rate) public onlyOwner {
        ATT_FEE_RATE = rate;
    }

    function setATT_FEE_HOLDER(address holder) public onlyOwner {
        ATT_FEE_HOLDER = holder;
    }

    function setTT_FEE_RATE(uint256 rate) public onlyOwner {
        TT_FEE_RATE = rate;
    }

    function setTT_FEE_HOLDER(address holder) public onlyOwner {
        TT_FEE_HOLDER = holder;
    }

    function setINITIAL_TOKEN_ID(uint256 id) public onlyOwner {
        INITIAL_TOKEN_ID = id;
    }

    function addSupply(uint256 amount) public onlyOwner {
        SUPPLY_LIMIT += amount;
    }

    /**
    * @notice Sets the unlock duration in days.
    * @param day Duration in days to set as unlock period.
    */
    function setUnlockDuration(uint256 day) public onlyOwner {
        require(day > 0, "Invalid duration: can not be zero.");
        emit UnlockDurationChanged(UNLOCK_DURATION, day);
        UNLOCK_DURATION = day;
    }

    function addLockRule(uint256 ruleId, uint256 ttAmount, uint256 attAmount, uint256 passcardRewards) public onlyOwner {
        require(lockRules[ruleId].isValid == false, "Rule already exists.");
        lockRules[ruleId] = LockRule(ruleId, true, ttAmount, attAmount, passcardRewards);
    }

    function updateLockRule(uint256 ruleId, bool isValid, uint256 ttAmount, uint256 attAmount, uint256 passcardRewards) public onlyOwner {
        lockRules[ruleId].isValid = isValid;
        lockRules[ruleId].ttAmount = ttAmount;
        lockRules[ruleId].attAmount = attAmount;
        lockRules[ruleId].passcardRewards = passcardRewards;
    }

    function removeLockRule(uint256 ruleId) public onlyOwner {
        lockRules[ruleId].ruleId = 0;
        lockRules[ruleId].isValid = false;
        lockRules[ruleId].ttAmount = 0;
        lockRules[ruleId].attAmount = 0;
        lockRules[ruleId].passcardRewards = 0;
    }

    function transferNFT(address to, uint256 tokenId) public onlyOwner {
        passcard.safeTransferFrom(address(this), to, tokenId);
    }

    function transferToken(address contractAddress, address to, uint256 amount) public onlyOwner {
        IERC20 contractToken = IERC20(contractAddress);
        contractToken.transfer(to, amount);
    }
}