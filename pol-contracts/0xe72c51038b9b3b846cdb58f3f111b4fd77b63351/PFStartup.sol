// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "./openzeppelin_contracts_utils_Pausable.sol";
import "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";
import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./openzeppelin_contracts_utils_ReentrancyGuard.sol";
import "./interfaces_IToken.sol";
import "./interfaces_IERC1155.sol";
import "./interfaces_IVesting.sol";
import "./interfaces_ILendingPool.sol";
import "./interfaces_IPFOracle.sol";

contract PFStartup is Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    event OfferFlagSet(bool flag);
    event RatesSet(
        uint256 tpftRate,
        uint256 userInterestRate,
        uint256 privateSaleIntersetRate
    );
    event PlatformWalletSet(address _wallet);
    event StakingAndAavePercentSet(
        uint256 _stakingPercent,
        uint256 _aavePercent
    );
    event MinAndMaxGoalAMountSet(uint256 _minmount, uint256 _maxamount);
    event MinGoalAmtCriteriaSet(uint256 rate);
    event PlatformFeesSet(uint256 unpledgeRate, uint256 claimRate);
    event MinAndMaxCampaignTimeSet(uint256 _minTime, uint256 _maxTime);
    event ProfitDistributionAddressesSet(address _receiver, uint256 _percent);
    event ProfitDistributionUpdated(address _reciever, uint256 _percent);
    event CampaignCreated(uint256 campaignId);
    event CampaignPaused(uint256 campaignId);
    event CampaignUnpaused(uint256 campaignId);
    event Pledged(uint256 campaignId, uint256 _amount);
    event Unpledged(uint256 campaignId);
    event TPFTRewardClaimed(address claimer);
    event CampaignClaimed(uint256 campaignId);
    event AaveRewardsClaimed(uint256 campaignId, address claimer);
    event ERC20TokenWithdrawed(address _tokenAddress, address receiver);

    error PFStartup_GreaterEqualCheckFailed(uint256 val1, uint256 val2);
    error PFStartup_LessEqualCheckFailed(uint256 val1, uint256 val2);
    error PFStartup_GreaterCheckFailed(uint256 val1, uint256 val2);
    error PFStartup_OwnerCannotPledge();
    error PFStartup_ZeroAddress();
    error PFStartup_NotAuthorized();
    error PFStartup_AlreadyProjectExists();
    error PFStartup_CampaignNotActive();
    error PFStartup_CampaignAlreadyClaimed();
    error PFStartup_CampaignReachedGoalAmt();
    error PFStartup_TGEFalse();
    error PFStartup_NothingToClaim();
    error PFStartup_AaveRewardNotAvailableForCampaign();
    error PFStartup_AaveRewardAlreadyClaimed();

    struct Campaign {
        // Creator of campaign
        address creator;
        // Timestamp of start of campaign
        uint256 startAt;
        // Total amount collected
        uint256 collected;
        // Timestamp of end of campaign
        uint256 minPledgeAmt;
        // Amount of money to raise
        uint256 goalAmt;
        // Total number of investors
        uint256 totalInvestors;
        // True if goalAmt was reached and creator has claimed the tokens.
        bool claimed;
        uint32 endAt;
    }

    IToken internal tpftToken;
    IERC1155 internal memoryToken;
    IERC20 internal token;
    IPFOracle public pfOracle;

    address private platformWallet;
    uint internal count;
    uint256 internal userInterestRate = 20;
    uint256 internal privateSaleIntersetRate = 5;
    uint256 internal totalTVL; // DAI
    uint256 internal totalInvestors;
    uint256 internal tpftRate;
    uint256 internal aavePercent;
    uint256 internal stakingPercent;
    uint256 internal totalBackerTPFTrewardDistributed;
    uint256 internal maxGoalAmount = 50000e18;
    uint256 internal minGoalAmount = 5e18;
    uint256 internal minCampaignTime = 90 days;
    uint256 internal maxCampaignTime = 365 days;
    uint256 public lastAaveWithdrawal;
    uint256 public minGoalAmtCriteria = 80;
    uint256 public unpledgePlatformFees = 1;
    uint256 public claimPlatformFees = 5;
    bool public offerFlag = true;
    address public daiOracle;
    address[] public profitDistributionAddresses;

    // 1 if running, 0 if cancled or not present, 2 if paused
    mapping(uint256 campaignId => uint status) public idStatus;
    mapping(address user => bool isRunning) public hasProjectRunning;
    mapping(uint campaignId => Campaign) internal campaigns;
    mapping(address pledger => uint256 amount) internal totalPledges;
    mapping(address pledger => mapping(uint256 campaignId => uint256 nftId))
        public nftIDs;
    mapping(uint campaignId => mapping(address pledger => uint amount))
        internal collectedAmount;
    mapping(address pledger => mapping(uint campaignId => bool isInvesting))
        internal isInvestingInID;
    mapping(address pledger => uint256 daiAmount)
        internal totalDAIInvestedAmount;
    mapping(address pledger => mapping(uint256 campaignId => uint256 startTime))
        internal pledgeStartTime;
    mapping(address pledger => uint256 tpftReward)
        public totalTPFTpledgerewards;
    mapping(address pledger => uint[] totalNFTs) internal totalUserNFTs;
    mapping(address pledger => uint reward) public tpftBackerRewardBalances;
    mapping(uint campaignId => uint aaveReward) public campaignAaveReward;
    mapping(uint campaignId => address[] investors)
        internal campaignInvestorsList;
    mapping(address pledger => mapping(uint256 campaignId => uint256 reward))
        public claimedAaveRewardUser;
    mapping(address receiver => uint256 percent)
        internal addressToProfitDistributionPercent;
    mapping(uint256 campaignId => bool claimed)
        public claimedAaveRewardCampaign;
    mapping(address creator => uint campaignId) public creatorToCampaign;

    function onlyTimelock() internal view {
        checkCaller(pfOracle.timeLock());
    }

    function onlyMultiSig() internal view {
        checkCaller(pfOracle.multiSig());
    }

    function checkCaller(address caller) internal view {
        if (msg.sender != caller) {
            revert PFStartup_NotAuthorized();
        }
    }

    constructor(
        address _tpftToken,
        address _memoryToken,
        address _paymentToken,
        IPFOracle _pfOracle,
        address _platformWallet,
        address _daiOracle,
        uint256 _tpftrate,
        uint256 _aavePercent
    ) payable {
        tpftToken = IToken(_tpftToken);
        memoryToken = IERC1155(_memoryToken);
        token = IERC20(_paymentToken);
        pfOracle = _pfOracle;
        platformWallet = _platformWallet;
        daiOracle = _daiOracle;
        tpftRate = _tpftrate;
        aavePercent = _aavePercent;
        IERC20(token).safeIncreaseAllowance(
            address(pfOracle._lendingPool()),
            type(uint256).max
        );
    }

    /// @notice Checks if the given address is not a zero address
    /// @param _check The address to check
    /// @dev Reverts if the address is the zero address
    function zeroAddressCheck(address _check) internal pure {
        if (_check == address(0)) {
            revert PFStartup_ZeroAddress();
        }
    }

    /// @notice Sets the offer flag
    /// @param flag The boolean value to set the offer flag
    /// @dev Only callable by super admins
    function setOfferFlag(bool flag) external {
        onlyMultiSig();
        offerFlag = flag;
        emit OfferFlagSet(flag);
    }
    /// @notice Sets the rates
    /// @param _tpftRate The new rate for tpftRate
    /// @param _userInterestRate The new rate for _userInterestRate
    /// @param _privateSaleIntersetRate The new rate for _privateSaleInterestRate
    /// @dev Only callable by super admins
    function setRates(
        uint _tpftRate,
        uint _userInterestRate,
        uint _privateSaleIntersetRate
    ) external {
        onlyTimelock();
        tpftRate = _tpftRate;
        userInterestRate = _userInterestRate;
        privateSaleIntersetRate = _privateSaleIntersetRate;
        emit RatesSet(_tpftRate, _userInterestRate, _privateSaleIntersetRate);
    }

    /// @notice Sets the platform wallet address
    /// @param _wallet The address of the new platform wallet
    /// @dev Only callable by super admins
    function setPlatformWallet(address _wallet) external {
        onlyTimelock();
        platformWallet = _wallet;
        emit PlatformWalletSet(_wallet);
    }

    /// @notice Sets the staking and aave percentage
    /// @param _stakingPercent The new staking percentage
    /// @param _aavePercent The new aave percentage
    /// @dev Only callable by super admins
    function setStakingAndAavePercent(
        uint _stakingPercent,
        uint _aavePercent
    ) external {
        onlyMultiSig();
        stakingPercent = _stakingPercent;
        aavePercent = _aavePercent;
        emit StakingAndAavePercentSet(_stakingPercent, _aavePercent);
    }

    /// @notice Sets the goal amounts
    /// @param _minamount The new minimum goal amount in wei
    /// @param _maxamount The new maximum goal amount in wei
    /// @dev Only callable by super admins, value is multiplied by 10^18
    function setMinAndMaxGoalAmount(uint _minamount, uint _maxamount) external {
        onlyMultiSig();
        minGoalAmount = _minamount * 1e18;
        maxGoalAmount = _maxamount * 1e18;
        emit MinAndMaxGoalAMountSet(_minamount, _maxamount);
    }

    /// @notice Sets the minimum goal amount criteria
    /// @param rate The new minimum goal amount percentage
    /// @dev Only callable by super admins
    function setMinGoalCriteriaAmount(uint rate) external {
        onlyMultiSig();
        minGoalAmtCriteria = rate;
        emit MinGoalAmtCriteriaSet(rate);
    }

    /// @notice Sets the platform fees
    /// @param unpledgeRate The new unpledge Platform  fees rate
    /// @param claimRate The new claim Platform  fees rate
    /// @dev Only callable by super admins
    function setPlatformFees(uint unpledgeRate, uint claimRate) external {
        onlyMultiSig();
        unpledgePlatformFees = unpledgeRate;
        claimPlatformFees = claimRate;
        emit PlatformFeesSet(unpledgeRate, claimRate);
    }

    /// @notice Sets the campaign time
    /// @param _minTime The new minimum campaign time in days
    /// @param _maxTime The new maximum campaign time in days
    /// @dev Only callable by super admins, value is multiplied by 1 day
    function setMinAndMaxCampaignTime(uint _minTime, uint _maxTime) external {
        onlyMultiSig();
        minCampaignTime = _minTime * 1 days;
        maxCampaignTime = _maxTime * 1 days;
        emit MinAndMaxCampaignTimeSet(_minTime, _maxTime);
    }

    /// @notice Sets the claim distribution for a receiver
    /// @param _receiver The address of the receiver
    /// @param _percent The percentage of the claim distribution
    /// @dev Only callable by super admins
    function setProfitDistributionAddresses(
        address _receiver,
        uint256 _percent
    ) external {
        onlyMultiSig();
        profitDistributionAddresses.push(_receiver);
        addressToProfitDistributionPercent[_receiver] = _percent;
        emit ProfitDistributionAddressesSet(_receiver, _percent);
    }

    /// @notice Sets the new TPFT token address
    /// @param _newTpftAddress The address of the new TPFT token contract
    /// @dev Only callable by super admins, checks if the address is non-zero
    function setPFAddresses(
        address _newTpftAddress,
        address _newMemoryAddress,
        address _newTokenAddress,
        address _pfOracle
    ) external {
        onlyMultiSig();
        zeroAddressCheck(_newTpftAddress);
        zeroAddressCheck(_newMemoryAddress);
        zeroAddressCheck(_newTokenAddress);
        token = IERC20(_newTokenAddress);
        memoryToken = IERC1155(_newMemoryAddress);
        tpftToken = IToken(_newTpftAddress);
        pfOracle = IPFOracle(_pfOracle);
    }

    function updateProfitDistribution(
        address _reciever,
        uint _percent
    ) external {
        onlyMultiSig();
        addressToProfitDistributionPercent[_reciever] = _percent;
        emit ProfitDistributionUpdated(_reciever, _percent);
    }

    /// @notice Gets the campaign parameters
    /// @return minGoalAmount The minimum goal amount in wei
    /// @return maxGoalAmount The maximum goal amount in wei
    /// @return minCampaignTime The minimum campaign time in seconds
    /// @return maxCampaignTime The maximum campaign time in seconds
    function getCampaignParameters()
        external
        view
        returns (uint, uint, uint, uint)
    {
        return (minGoalAmount, maxGoalAmount, minCampaignTime, maxCampaignTime);
    }

    /// @notice Gets all NFTs owned by a user
    /// @param user The address of the user
    /// @return An array of NFT IDs owned by the user
    function getUserAllNFTs(
        address user
    ) external view returns (uint[] memory) {
        return totalUserNFTs[user];
    }

    /// @notice Gets the current project ID
    /// @return The current project ID
    function getCurrentId() external view returns (uint256) {
        return count;
    }

    /// @notice Gets the current project ID
    /// @return The current project ID
    function getProfitDistributionPercent(
        address receiver
    ) external view returns (uint256) {
        return addressToProfitDistributionPercent[receiver];
    }

    /// @notice Gets the platform Wallet
    /// @return The Platform Wallet
    function getPlatformWallet() external view returns (address) {
        return platformWallet;
    }

    /// @notice Gets the current rates
    /// @return The staking percentage, tpftRate, userInterestRate, privateSaleIntersetRate, aavePercent
    function getCurrentRates()
        external
        view
        returns (uint256, uint256, uint256, uint256, uint256)
    {
        return (
            stakingPercent,
            tpftRate,
            userInterestRate,
            privateSaleIntersetRate,
            aavePercent
        );
    }

    /// @notice Gets the total number of investors
    /// @return The total number of investors
    function getTotalInvestors() external view returns (uint256) {
        return totalInvestors;
    }

    /// @notice Gets the addresses of the key contracts
    /// @return memoryToken The address of the Memory token contract
    /// @return tpftToken The address of the TPFT token contract
    function getContractAddresses()
        external
        view
        returns (address, address, address, address)
    {
        return (
            address(memoryToken),
            address(tpftToken),
            address(pfOracle),
            address(token)
        );
    }

    /// @notice Gets the campaign details for a given ID
    /// @param _id The campaign ID
    /// @return The campaign details as a Campaign struct
    function getCampaignDetail(
        uint256 _id
    ) external view returns (Campaign memory) {
        return campaigns[_id];
    }

    /// @notice Gets the amount pledged by a specific pledger for a specific campaign
    /// @param _id The campaign ID
    /// @param _pledger The address of the pledger
    /// @return The amount pledged by the pledger in wei
    function getCollectedAmount(
        uint256 _id,
        address _pledger
    ) external view returns (uint256) {
        return collectedAmount[_id][_pledger];
    }

    /// @notice Gets the start time of a pledge for a user and campaign ID
    /// @param user The address of the user
    /// @param id The campaign ID
    /// @return The start time of the pledge in seconds
    function getUserPledgedStartTime(
        address user,
        uint256 id
    ) external view returns (uint256) {
        return pledgeStartTime[user][id];
    }

    /// @notice Gets the total pledged DAI amount
    /// @return The total pledged DAI amount in wei
    function getTotalpledgedDAIamount() external view returns (uint256) {
        return totalTVL;
    }

    /// @notice Gets the total TPFT rewards distributed to backers
    /// @return The total TPFT rewards distributed in wei
    function getTotalTPFTBackerRewards() external view returns (uint256) {
        return totalBackerTPFTrewardDistributed;
    }

    /**
     * @dev Pause Transactions on contract.
     */
    function pause() external {
        onlyTimelock();
        _pause();
    }

    /**
     * @dev Unpause Transactions on contract.
     */
    function unpause() external {
        onlyTimelock();
        _unpause();
    }

    function greaterEqualCheck(uint256 val1, uint256 val2) internal pure {
        if (val1 < val2) {
            revert PFStartup_GreaterEqualCheckFailed(val1, val2);
        }
    }

    function lessEqualCheck(uint256 val1, uint256 val2) internal pure {
        if (val1 > val2) {
            revert PFStartup_LessEqualCheckFailed(val1, val2);
        }
    }

    function greaterCheck(uint256 val1, uint256 val2) internal pure {
        if (val1 <= val2) {
            revert PFStartup_GreaterCheckFailed(val1, val2);
        }
    }

    /// @notice Creates a new project campaign
    /// @param _goalAmt The goal amount for the campaign
    /// @param _campaignEndAt The end timestamp of the campaign
    /// @param _minPledgeAmt The minimum amount for pledges
    /// @param kycExpiresAt The KYC expiration timestamp
    /// @param dataHash The data hash for KYC validation
    /// @dev Checks for KYC status, ensures no running project for the creator, validates campaign time and goal amount, and updates the state
    function createProject(
        uint _goalAmt,
        uint32 _campaignEndAt,
        uint256 _minPledgeAmt,
        uint256 kycExpiresAt,
        bytes32 dataHash
    ) external nonReentrant whenNotPaused {
        kycCheck(msg.sender, kycExpiresAt, dataHash);
        if (hasProjectRunning[msg.sender]) {
            revert PFStartup_AlreadyProjectExists();
        }
        greaterEqualCheck(_campaignEndAt, block.timestamp + minCampaignTime);
        lessEqualCheck(_campaignEndAt, block.timestamp + maxCampaignTime);
        greaterEqualCheck(_goalAmt, minGoalAmount);
        lessEqualCheck(_goalAmt, maxGoalAmount);

        if (!offerFlag && getTGEFlagFromOracle()) {
            pfOracle.validateStakingCondition(
                _goalAmt,
                stakingPercent,
                msg.sender
            );
        }

        uint256 campaignId = count + 1;

        hasProjectRunning[msg.sender] = true;
        campaigns[campaignId] = Campaign({
            creator: msg.sender,
            goalAmt: _goalAmt,
            collected: 0,
            startAt: block.timestamp,
            endAt: _campaignEndAt,
            claimed: false,
            minPledgeAmt: _minPledgeAmt,
            totalInvestors: 0
        });

        creatorToCampaign[msg.sender] = campaignId;
        idStatus[campaignId] = 1;
        count = campaignId;

        emit CampaignCreated(campaignId);
    }

    /// @notice Pauses a campaign
    /// @param _id The campaign ID
    /// @dev Only callable by super admins
    function pauseCampaign(uint _id) external {
        onlyMultiSig();
        idStatus[_id] = 2;
        emit CampaignPaused(_id);
    }

    /// @notice Unpauses a campaign
    /// @param _id The campaign ID
    /// @dev Only callable by super admins
    function unpauseCampaign(uint _id) external {
        onlyMultiSig();
        idStatus[_id] = 1;
        emit CampaignUnpaused(_id);
    }

    /// @notice Allows a user to pledge an amount to a campaign
    /// @param _id The campaign ID
    /// @param _amount The amount to pledge
    /// @param kycExpiresAt The KYC expiration timestamp
    /// @param dataHash The data hash for KYC validation
    /// @dev Transfers tokens, updates pledge data, mints NFT for first-time investment, and distributes TPFT rewards
    function pledge(
        uint _id,
        uint _amount,
        uint256 kycExpiresAt,
        bytes32 dataHash
    ) external nonReentrant whenNotPaused {
        validationPledge(_id, _amount, kycExpiresAt, dataHash);

        Campaign storage campaign = campaigns[_id];
        address pfAddress = address(this);
        token.safeTransferFrom(msg.sender, pfAddress, _amount);
        uint256 stakeToAaveAmt = (_amount * aavePercent) / 100;
        pfOracle.sponsor(stakeToAaveAmt, pfAddress);
        totalPledges[msg.sender]++;
        campaign.collected = campaign.collected + _amount;
        collectedAmount[_id][msg.sender] =
            collectedAmount[_id][msg.sender] +
            _amount;
        uint256 TPFTAmount = uint(
            pfOracle.calculateTPFTAmountViaERC20(
                address(token),
                daiOracle,
                _amount
            )
        );

        uint256 totalTPFTAmount = (TPFTAmount * tpftRate) / 100;
        pfOracle.validateDistributorData(totalTPFTAmount, 6);

        tpftBackerRewardBalances[msg.sender] =
            tpftBackerRewardBalances[msg.sender] +
            totalTPFTAmount;
        if (getTGEFlagFromOracle()) {
            tpftToken.issue(msg.sender, tpftBackerRewardBalances[msg.sender]);
            tpftBackerRewardBalances[msg.sender] = 0;
        }
        totalTPFTpledgerewards[msg.sender] =
            totalTPFTpledgerewards[msg.sender] +
            totalTPFTAmount;

        if (!isInvestingInID[msg.sender][_id]) {
            uint nftID = memoryToken.mint(msg.sender, 1);
            nftIDs[msg.sender][_id] = nftID;
            totalUserNFTs[msg.sender].push(nftID);
            isInvestingInID[msg.sender][_id] = true;
            campaign.totalInvestors++;
            pledgeStartTime[msg.sender][_id] = block.timestamp;
        }
        if (totalDAIInvestedAmount[msg.sender] == 0) {
            totalInvestors++;
        }

        totalDAIInvestedAmount[msg.sender] =
            totalDAIInvestedAmount[msg.sender] +
            _amount;
        campaignInvestorsList[_id].push(msg.sender);
        totalTVL = totalTVL + _amount;
        totalBackerTPFTrewardDistributed =
            totalBackerTPFTrewardDistributed +
            totalTPFTAmount;
        pfOracle.distributionAmountFill(totalTPFTAmount, 5);

        emit Pledged(_id, _amount);
    }

    /// @notice Validates the pledge conditions
    /// @param id The campaign ID
    /// @param _amount The amount to pledge
    /// @param expiresAt The KYC expiration timestamp
    /// @param dataHash The data hash for KYC validation
    /// @dev Checks KYC status, campaign status, and pledge amount
    function validationPledge(
        uint256 id,
        uint256 _amount,
        uint256 expiresAt,
        bytes32 dataHash
    ) internal {
        kycCheck(msg.sender, expiresAt, dataHash);
        getCampStatus(id);
        Campaign storage campaign = campaigns[id];
        if (msg.sender == campaign.creator) {
            revert PFStartup_OwnerCannotPledge();
        }
        lessEqualCheck(block.timestamp, campaign.endAt);
        greaterEqualCheck(_amount, campaign.minPledgeAmt);
    }

    function getCampStatus(uint256 id) internal view {
        if (idStatus[id] != 1) {
            revert PFStartup_CampaignNotActive();
        }
    }

    function kycCheck(
        address _user,
        uint256 expiresAt,
        bytes32 dataHash
    ) internal {
        pfOracle.kycCheck(_user, expiresAt, dataHash);
    }

    function campaignEndCheck(uint256 campId) internal view {
        greaterCheck(block.timestamp, campaigns[campId].endAt);
    }

    /// @notice Allows a user to unpledge after the campaign has ended
    /// @param _id The campaign ID
    /// @dev Ensures the campaign has ended, the user has pledged, and the campaign goal was not met

    function unpledgeCheck(
        uint256 _id,
        address _user
    ) public view returns (bool) {
        uint256 _amount = collectedAmount[_id][_user];
        greaterCheck(_amount, 0);
        campaignEndCheck(_id);
        if (campaigns[_id].claimed) {
            revert PFStartup_CampaignAlreadyClaimed();
        }
        if (
            campaigns[_id].collected >=
            (campaigns[_id].goalAmt * minGoalAmtCriteria) / 100
        ) {
            revert PFStartup_CampaignReachedGoalAmt();
        }

        return true;
    }

    /// @notice Internal function to handle unpledging
    /// @param _id The campaign ID
    /// @dev Updates campaign and pledge data, burns NFTs, and handles token transfers
    function unpledge(uint _id) external nonReentrant whenNotPaused {
        unpledgeCheck(_id, msg.sender);
        uint256 _amount = collectedAmount[_id][msg.sender];
        Campaign storage campaign = campaigns[_id];

        campaign.collected = campaign.collected - _amount;
        collectedAmount[_id][msg.sender] =
            collectedAmount[_id][msg.sender] -
            _amount;
        uint256 tpftAmountForDai = uint(
            pfOracle.calculateTPFTAmountViaERC20(
                address(token),
                daiOracle,
                _amount
            )
        );
        uint256 tpftAmount = (tpftAmountForDai * tpftRate) / 100;

        if (
            getTGEFlagFromOracle() && tpftBackerRewardBalances[msg.sender] == 0
        ) {
            tpftToken.burn(msg.sender, tpftAmount);
        } else {
            greaterEqualCheck(tpftBackerRewardBalances[msg.sender], tpftAmount);
            tpftBackerRewardBalances[msg.sender] =
                tpftBackerRewardBalances[msg.sender] -
                tpftAmount;
        }
        totalTPFTpledgerewards[msg.sender] =
            totalTPFTpledgerewards[msg.sender] -
            tpftAmount;
        memoryToken.burn(msg.sender, nftIDs[msg.sender][_id], 1);

        isInvestingInID[msg.sender][_id] = false;
        campaign.totalInvestors--;

        address pfAddress = address(this);

        bool noWithdrawFromPool = false;
        if (token.balanceOf(pfAddress) >= _amount) {
            noWithdrawFromPool = true;
        }
        if (!noWithdrawFromPool) {
            uint balanceToWith = _amount - token.balanceOf(pfAddress);
            pfOracle.redeemToken(balanceToWith, pfAddress);
        }

        uint256 platformAmount = (_amount * unpledgePlatformFees) / 100;
        uint256 transferAmount = _amount - platformAmount;
        tokenTransfer(msg.sender, transferAmount);
        tokenTransfer(platformWallet, _amount - transferAmount);
        totalDAIInvestedAmount[msg.sender] =
            totalDAIInvestedAmount[msg.sender] -
            _amount;
        if (totalDAIInvestedAmount[msg.sender] == 0) {
            totalInvestors--;
        }
        pfOracle.distributionAmountDec(tpftAmount, 5);
        totalTVL = totalTVL - _amount;

        emit Unpledged(_id);
    }

    function getTGEFlagFromOracle() internal view returns (bool) {
        return pfOracle.getTGEFlag();
    }

    function tokenTransfer(address to, uint256 amount) internal {
        token.safeTransfer(to, amount);
    }

    /// @notice Claims TPFT rewards for the caller
    /// @dev Ensures that the TGE flag is true and the caller has rewards to claim
    function claimTPFTReward() external nonReentrant whenNotPaused {
        if (!getTGEFlagFromOracle()) {
            revert PFStartup_TGEFalse();
        }
        if (tpftBackerRewardBalances[msg.sender] == 0) {
            revert PFStartup_NothingToClaim();
        }
        tpftToken.issue(msg.sender, tpftBackerRewardBalances[msg.sender]);
        tpftBackerRewardBalances[msg.sender] = 0;

        emit TPFTRewardClaimed(msg.sender);
    }

    /// @notice Allows the project creator to claim the funds collected in their campaign
    /// @param _id The campaign ID
    /// @dev Ensures the caller is the project creator, the campaign has ended, and the goal amount has been met
    function claim(uint _id) external nonReentrant whenNotPaused {
        zeroAddressCheck(msg.sender);
        getCampStatus(_id);

        Campaign storage campaign = campaigns[_id];
        checkCaller(campaign.creator);
        campaignEndCheck(_id);
        greaterEqualCheck(
            campaign.collected,
            (campaign.goalAmt * minGoalAmtCriteria) / 100
        );

        campaign.claimed = true;
        uint256 platformAmount = (campaign.collected * claimPlatformFees) / 100;
        uint transferAmount = campaign.collected - platformAmount;
        uint256 distributionArrayLength = profitDistributionAddresses.length;
        uint256 distributionAmount;
        if (distributionArrayLength != 0) {
            for (uint i = 0; i < distributionArrayLength; i++) {
                address receiver = profitDistributionAddresses[i];
                if (addressToProfitDistributionPercent[receiver] > 0) {
                    distributionAmount =
                        ((platformAmount) *
                            addressToProfitDistributionPercent[receiver]) /
                        100;
                    tokenTransfer(receiver, distributionAmount);
                }
            }
        }

        address pfAddress = address(this);

        bool noWithdrawFromPool = false;
        if (token.balanceOf(pfAddress) >= campaign.collected) {
            noWithdrawFromPool = true;
        }
        if (!noWithdrawFromPool) {
            uint balanceToWith = campaign.collected -
                token.balanceOf(pfAddress);
            pfOracle.redeemToken(balanceToWith, pfAddress);
        }

        tokenTransfer(campaign.creator, transferAmount);
        if (platformAmount > distributionAmount) {
            tokenTransfer(platformWallet, platformAmount - distributionAmount);
        }

        totalTVL = totalTVL - campaign.collected;
        idStatus[_id] = 0;

        emit CampaignClaimed(_id);
    }

    /// @notice Withdraws Aave rewards to the specified address
    /// @param privateSaleAddress The address to receive the private sale portion of the rewards
    /// @dev Only callable by super admins, calculates and distributes rewards among campaigns and specified address

    function withdrawRewardfromAave(address privateSaleAddress) external {
        onlyMultiSig();
        zeroAddressCheck(privateSaleAddress);
        uint256 rewards = pfOracle.getAaveRewards(address(this));
        pfOracle.redeemToken(rewards, address(this));
        uint256 userRewards = ((rewards * userInterestRate) / 100);

        uint totalCampaignCollectedAmount;
        uint256 campaignAmountandTime;

        // Pre-calculate the totalCampaignCollectedAmount
        for (uint256 i = 1; i <= count; i++) {
            if (
                !claimedAaveRewardCampaign[i] &&
                campaigns[i].startAt < block.timestamp
            ) {
                uint256 endTime = campaigns[i].endAt <= block.timestamp
                    ? campaigns[i].endAt
                    : block.timestamp;
                campaignAmountandTime =
                    campaigns[i].collected *
                    (endTime - campaigns[i].startAt);
                totalCampaignCollectedAmount += campaignAmountandTime;
            }
        }

        if (totalCampaignCollectedAmount > 0) {
            for (uint256 i = 1; i <= count; i++) {
                if (
                    !claimedAaveRewardCampaign[i] &&
                    campaigns[i].startAt < block.timestamp
                ) {
                    uint256 endTime = campaigns[i].endAt <= block.timestamp
                        ? campaigns[i].endAt
                        : block.timestamp;
                    campaignAmountandTime =
                        campaigns[i].collected *
                        (endTime - campaigns[i].startAt);

                    campaignAaveReward[i] +=
                        (campaignAmountandTime * userRewards) /
                        totalCampaignCollectedAmount;
                    if (campaigns[i].endAt <= block.timestamp) {
                        claimedAaveRewardCampaign[i] = true;
                    } else {
                        campaigns[i].startAt = block.timestamp; // Adjust startAt only if campaign is ongoing
                    }
                }
            }
        }

        // 20% for the profit
        // Calculate and transfer private sale amount
        uint256 privateSaleAmount = (privateSaleIntersetRate != 0)
            ? (rewards * privateSaleIntersetRate) / 100
            : 0;

        if (privateSaleAmount > 0) {
            tokenTransfer(privateSaleAddress, privateSaleAmount);
            IVesting(privateSaleAddress).updateDAIrewards(privateSaleAmount);
        }

        // Transfer remaining rewards to the platform wallet
        tokenTransfer(
            platformWallet,
            rewards - userRewards - privateSaleAmount
        );

        lastAaveWithdrawal = count;
    }

    function userAaveReward(
        uint campaignId,
        address user
    ) external view returns (uint) {
        return getUserAaveRewards(campaignId, user);
    }

    /// @notice Gets the rewards from Aave for a specific user in a specific campaign
    /// @param campaignId The campaign ID
    /// @param user The address of the user
    /// @return userReward The user's Aave rewards
    /// @dev Calculates the user's share of the Aave rewards for the specified campaign
    function getUserAaveRewards(
        uint256 campaignId,
        address user
    ) internal view returns (uint256 userReward) {
        uint256 denominator = 0;
        uint256 campaignInvestorsLength = campaignInvestorsList[campaignId]
            .length;
        uint256 campaignEndAt = campaigns[campaignId].endAt;
        uint256 campaignReward = campaignAaveReward[campaignId];
        uint256 userInvestedAmount = collectedAmount[campaignId][user];
        uint256 userInvestedTime = campaignEndAt -
            pledgeStartTime[user][campaignId];

        // Calculate the denominator
        for (uint256 i = 0; i < campaignInvestorsLength; i++) {
            address tempUser = campaignInvestorsList[campaignId][i];
            uint256 investedAmount = collectedAmount[campaignId][tempUser];
            uint256 investmentTime = campaignEndAt -
                pledgeStartTime[tempUser][campaignId];
            denominator += (investedAmount * investmentTime);
        }

        // Avoid division by zero
        if (denominator > 0) {
            uint256 scaledUserReward = (userInvestedAmount *
                userInvestedTime *
                campaignReward *
                1e18) / denominator;
            userReward = scaledUserReward / 1e18;
        } else {
            userReward = 0; // Return 0 if there are no investments
        }

        return userReward;
    }

    /// @notice Claims Aave rewards for the caller from a specific campaign
    /// @param campaignId The campaign ID
    /// @dev Ensures the campaign reward is available, calculates and transfers the caller's reward
    //TODO: Add rewardsClaimed check
    function claimAaveRewards(uint campaignId) external whenNotPaused {
        if (!claimedAaveRewardCampaign[campaignId]) {
            revert PFStartup_AaveRewardNotAvailableForCampaign();
        }
        if (claimedAaveRewardUser[msg.sender][campaignId] != 0) {
            revert PFStartup_AaveRewardAlreadyClaimed();
        }
        uint256 reward = getUserAaveRewards(campaignId, msg.sender);
        claimedAaveRewardUser[msg.sender][campaignId] = reward;
        tokenTransfer(msg.sender, reward);
        emit AaveRewardsClaimed(campaignId, msg.sender);
    }

    /// @notice Withdraws a specified amount of Aave rewards
    /// @param rewards The amount of rewards to withdraw
    /// @dev Only callable by super admins, redeems the specified amount of tokens from Aave
    function aaveWithdrawal(uint256 rewards) external {
        onlyTimelock();
        pfOracle.redeemToken(rewards, address(this));
    }

    /// @notice Withdraws all ERC20 tokens of a specific type to a specified address
    /// @param _tokenAddress The address of the ERC20 token
    /// @param _payee The address to receive the tokens
    /// @dev Only callable by super admins, sends the entire balance of the specified ERC20 token to the specified address
    function withdrawERC20(address _tokenAddress, address _payee) external {
        onlyTimelock();
        IERC20 withdrawToken = IERC20(_tokenAddress);
        uint256 amt = withdrawToken.balanceOf(address(this));
        withdrawToken.safeTransfer(_payee, amt);

        emit ERC20TokenWithdrawed(_tokenAddress, _payee);
    }
}