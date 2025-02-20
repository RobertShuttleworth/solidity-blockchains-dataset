// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "./contracts_DCAVault.sol";
import "./contracts_interfaces_IZap.sol";
import "./contracts_interfaces_IConstants.sol";
import "./contracts_interfaces_IStrategy.sol";
import "./contracts_interfaces_IStrategyInfo.sol";
import "./contracts_interfaces_IDCAManagement.sol";
import "./contracts_interfaces_IDCAVault.sol";
import "./contracts_libraries_uniswapV3_TransferHelper.sol";
import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./openzeppelin_contracts_access_AccessControl.sol";
import "./openzeppelin_contracts_security_ReentrancyGuard.sol";
import "./openzeppelin_contracts_utils_structs_EnumerableSet.sol";

contract DCAManagement is IDCAManagement, AccessControl, ReentrancyGuard {
    using EnumerableSet for EnumerableSet.AddressSet;

    // For backend
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");

    IConstants public Constants;
    IZap public Zap;

    // Mapping from user address to strategy address to array of DCAPlans
    mapping(address => mapping(address => DCAPlan[])) public userStrategyPlans;
    // Mapping from user address to set of strategy addresses
    mapping(address => EnumerableSet.AddressSet) private userAllStrategies;
    // Mapping from user address to array of canceled DCAPlans
    mapping(address => DCAPlan[]) public userCanceledPlans;

    // Set of all users
    EnumerableSet.AddressSet private allUsers;

    // Incremental plan id
    uint256 public planId;

    // Fee
    uint24 public constant FEE_DENOMINATOR = 1000000;
    uint24 public feeNumerator; // ex: 0.1% = 1000
    uint256 public maxPlanAmount = 100;

    constructor(address _constants, address _zap, address _executor) {
        require(_constants != address(0), "Constants address cannot be zero");
        require(_zap != address(0), "Zap address cannot be zero");

        Constants = IConstants(_constants);
        Zap = IZap(_zap);

        // set deployer as EXECUTOR_ROLE roleAdmin
        _setRoleAdmin(EXECUTOR_ROLE, DEFAULT_ADMIN_ROLE);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        // set EXECUTOR_ROLE memebers
        _setupRole(EXECUTOR_ROLE, _executor);
    }

    ///@dev Set DCA plan for a specific strategy by user
    ///@param _strategy The strategy address
    ///@param _inputToken The input token address
    ///@param _eachTimeInvestAmount The amount of token to invest each time
    ///@param _eachTimePeriod The period of time to invest
    ///@param _periodData The period data
    function createDCAPlan(
        address _strategy,
        address _inputToken,
        uint256 _eachTimeInvestAmount,
        uint256 _eachTimePeriod,
        DCAPeriodData calldata _periodData
    ) public {
        _validateInputData(_inputToken, _eachTimeInvestAmount, _eachTimePeriod, _periodData);

        address user = msg.sender;
        uint256 userPlanCount = userStrategyPlans[user][_strategy].length;
        require(userPlanCount < maxPlanAmount, "Max plan amount reached");

        // Create user vualt every time
        address userPlanVaultAddress = _initialDCAVault();

        DCAPlan memory newPlan = DCAPlan({
            id: planId,
            userPlanVaultAddress: userPlanVaultAddress,
            isPaused: false,
            eachTimeInvestAmount: _eachTimeInvestAmount,
            eachTimePeriod: _eachTimePeriod,
            startTimestamp: block.timestamp,
            cancelTimestamp: 0,
            firstInvestTimestamp: 0,
            lastReinvestTimestamp: 0,
            planDetail: DCAPlanDetail({
                strategy: _strategy,
                inputToken: _inputToken,
                costOfDCA: 0,
                userReceivedToken0Amount: 0,
                userReceivedToken1Amount: 0,
                rewardAccumulated: 0
            }),
            periodData: _periodData
        });

        // Increment the plan id
        planId++;

        userStrategyPlans[user][_strategy].push(newPlan);

        // Add strategy to user's plan set if it's a new plan
        bool isNewStrategy = userAllStrategies[user].add(_strategy);

        // Add user to allUsers set if it's a new user
        if (isNewStrategy && userAllStrategies[user].length() == 1) {
            allUsers.add(user);
        }

        emit DCAPlanCreated(
            _strategy, user, userPlanVaultAddress, planId - 1, _inputToken, _eachTimeInvestAmount, _eachTimePeriod
        );
    }

    ///@dev Create a new vault
    function _initialDCAVault() internal returns (address) {
        // Create a new vault using normal create
        DCAVault newVault = new DCAVault(address(this));

        return address(newVault);
    }

    ///@dev Execute the DCA plan for a specific strategy by user from backend executor
    ///@param _userAddress The user address
    ///@param _strategy The strategy contract address
    ///@param _planIndex The index of the plan to execute
    ///@param _swapInAmount The amount of token to swap in
    ///@param _minimumSwapOutAmount The minimum amount of token to swap out
    function executeDCAPlan(
        address _userAddress,
        address _strategy,
        uint256 _planIndex,
        uint256 _swapInAmount,
        uint256 _minimumSwapOutAmount
    ) public onlyRole(EXECUTOR_ROLE) nonReentrant {
        // Check plan index is valid
        require(_planIndex < userStrategyPlans[_userAddress][_strategy].length, "Invalid plan index");

        // Initialize ExecutionData struct
        ExecutionData memory data;
        DCAPlan memory plan = userStrategyPlans[_userAddress][_strategy][_planIndex];

        // Check plan has a vault
        data.userPlanVaultAddress = plan.userPlanVaultAddress;
        require(data.userPlanVaultAddress != address(0), "User does not have a vault");

        data.inputToken = plan.planDetail.inputToken;
        data.inputAmount = plan.eachTimeInvestAmount;
        (data.token0, data.token1) = _getTokenAddresses(_strategy);

        // Check lastReinvestTimestamp + eachTimePeriod / 2 <= block.timestamp
        require(
            plan.lastReinvestTimestamp + (plan.eachTimePeriod / 2) <= block.timestamp,
            "Each time period has not passed yet"
        );
        // Check user has enough input token
        require(IERC20(data.inputToken).balanceOf(_userAddress) >= data.inputAmount, "Insufficient input token balance");
        // Check user allowance for input token to this contract
        require(
            IERC20(data.inputToken).allowance(_userAddress, address(this)) >= data.inputAmount,
            "Insufficient input token allowance"
        );

        // Check the user vault share before deposit
        data.shareBefore = IStrategyInfo(_strategy).userShare(data.userPlanVaultAddress);

        uint256 sendBackToken0Amount;
        uint256 sendBackToken1Amount;

        // Transfer token from user to this contract
        TransferHelper.safeTransferFrom(data.inputToken, _userAddress, address(this), data.inputAmount);

        // Deduct the fee
        uint256 fee = (data.inputAmount * feeNumerator) / FEE_DENOMINATOR;
        data.inputAmount -= fee;
        address depositToken = data.inputToken;
        uint256 depositAmount = data.inputAmount;

        // If input token is one of the pair token, directly deposit liquidity
        if (data.inputToken != data.token0 && data.inputToken != data.token1) {
            // Approve the input token to zap contract
            TransferHelper.safeApprove(data.inputToken, address(Zap), data.inputAmount);

            // Update the deposit token and amount
            depositAmount = Zap.swapToken(false, data.inputToken, data.token0, data.inputAmount, address(this));
            depositToken = data.token0;
        }

        // Approve the deposit token to strategy contract
        TransferHelper.safeApprove(depositToken, _strategy, depositAmount);

        // Record the send back token0 & token1 amount
        (,,,, sendBackToken0Amount, sendBackToken1Amount) = IStrategy(_strategy).depositLiquidity(
            false, data.userPlanVaultAddress, depositToken, depositAmount, _swapInAmount, _minimumSwapOutAmount
        );

        // Transfer the sendback token to user from userVault
        _transferTokensIfNeeded(data.token0, _userAddress, sendBackToken0Amount, data.userPlanVaultAddress);
        _transferTokensIfNeeded(data.token1, _userAddress, sendBackToken1Amount, data.userPlanVaultAddress);

        // Get the user vault share after deposit
        data.shareAfter = IStrategyInfo(_strategy).userShare(data.userPlanVaultAddress);

        // Update the plan lastReinvestTimestamp and costOfDCA
        if (plan.firstInvestTimestamp == 0) {
            userStrategyPlans[_userAddress][_strategy][_planIndex].firstInvestTimestamp = block.timestamp;
        }
        userStrategyPlans[_userAddress][_strategy][_planIndex].lastReinvestTimestamp = block.timestamp;
        userStrategyPlans[_userAddress][_strategy][_planIndex].planDetail.costOfDCA += data.inputAmount;

        emit DCAPlanExecuted(
            _strategy, _userAddress, data.userPlanVaultAddress, plan.id, data.inputToken, data.inputAmount
        );
    }

    ///@dev Update the DCA plan for a specific strategy by user
    ///@param _strategy The strategy address
    ///@param _inputToken The input token address
    ///@param _planIndex The index of the plan to update
    ///@param _planId The plan id
    ///@param _eachTimeInvestAmount The amount of token to invest each time
    ///@param _eachTimePeriod The period of time to invest
    ///@param _isPaused The status of the plan
    ///@param _periodData The period data (Day, Week, Month, Hour, Minute)
    function updateDCAPlan(
        address _strategy,
        uint256 _planIndex,
        uint256 _planId,
        address _inputToken,
        uint256 _eachTimeInvestAmount,
        uint256 _eachTimePeriod,
        bool _isPaused,
        DCAPeriodData calldata _periodData
    ) external {
        _validateInputData(_inputToken, _eachTimeInvestAmount, _eachTimePeriod, _periodData);

        address user = msg.sender;
        DCAPlan memory plan = _validatePlanIndexAndId(user, _strategy, _planIndex, _planId);

        userStrategyPlans[user][_strategy][_planIndex].planDetail.inputToken = _inputToken;
        userStrategyPlans[user][_strategy][_planIndex].eachTimeInvestAmount = _eachTimeInvestAmount;
        userStrategyPlans[user][_strategy][_planIndex].eachTimePeriod = _eachTimePeriod;
        userStrategyPlans[user][_strategy][_planIndex].isPaused = _isPaused;
        userStrategyPlans[user][_strategy][_planIndex].periodData = _periodData;

        emit DCAPlanUpdated(_strategy, user, plan.id, _eachTimeInvestAmount, _eachTimePeriod, _isPaused);
    }

    ///@dev Claim the reward from the strategy and transfer to the user
    ///@param _strategy The strategy address
    ///@param _planIndex The index of the plan to claim reward
    ///@param _planId The plan id
    function claimPlanReward(address _strategy, uint256 _planIndex, uint256 _planId) external {
        address user = msg.sender;
        DCAPlan memory plan = _validatePlanIndexAndId(user, _strategy, _planIndex, _planId);

        // Claim the reward
        uint256 reward = _claimPlanReward(user, _strategy, plan.userPlanVaultAddress);

        emit DCARewardClaimed(_strategy, user, plan.userPlanVaultAddress, plan.id, reward);
    }

    ///@dev Cancel a specific DCA plan by user
    ///@param _strategy The strategy address
    ///@param _planIndex The index of the plan to cancel
    ///@param _planId The plan id
    function cancelDCAPlan(address _strategy, uint256 _planIndex, uint256 _planId) external {
        address user = msg.sender;
        DCAPlan memory planToCancel = _validatePlanIndexAndId(user, _strategy, _planIndex, _planId);

        /**
         *         - get the plan share, user vault address, strategy token0 & token1 address
         *         - withdraw the liquidity from strategy
         *         - record the return token0 & token1 amount
         *         - transfer the return token0 & token1 amount to the user
         *         - add the cancel plan to the userCanceledPlans
         */
        address userPlanVaultAddress = planToCancel.userPlanVaultAddress;
        uint256 planShare = IStrategyInfo(_strategy).userShare(userPlanVaultAddress);
        address token0 = IStrategyInfo(planToCancel.planDetail.strategy).token0Address();
        address token1 = IStrategyInfo(planToCancel.planDetail.strategy).token1Address();

        // Claim reward
        if (IStrategyInfo(_strategy).userDistributeReward(planToCancel.userPlanVaultAddress) > 0) {
            _claimPlanReward(user, _strategy, userPlanVaultAddress);
        }

        (uint256 userReceivedToken0Amount, uint256 userReceivedToken1Amount) = (0, 0);
        if (planShare != 0) {
            (userReceivedToken0Amount, userReceivedToken1Amount) =
                IStrategy(_strategy).withdrawLiquidity(userPlanVaultAddress, planShare);
        }

        // Transfer remaining ETH, token0, and token1 back to user
        _transferRemainingFunds(userPlanVaultAddress, user, planToCancel);

        // Add the canceled plan to the userCanceledPlans
        planToCancel.planDetail.userReceivedToken0Amount = userReceivedToken0Amount;
        planToCancel.planDetail.userReceivedToken1Amount = userReceivedToken1Amount;
        planToCancel.cancelTimestamp = block.timestamp;

        // Keep user accumulated reward after plan canceled
        planToCancel.planDetail.rewardAccumulated =
            IStrategyInfo(_strategy).userDistributeRewardAccumulated(userPlanVaultAddress);

        userCanceledPlans[user].push(planToCancel);

        // Swap the plan at the specified index with the last plan and pop the last element
        uint256 lastIndex = userStrategyPlans[user][_strategy].length - 1;
        if (_planIndex != lastIndex) {
            userStrategyPlans[user][_strategy][_planIndex] = userStrategyPlans[user][_strategy][lastIndex];
        }
        userStrategyPlans[user][_strategy].pop();

        // If no more plans for the strategy, remove the strategy
        if (userStrategyPlans[user][_strategy].length == 0) {
            userAllStrategies[user].remove(_strategy);
        }

        // If the user has no more plans, remove them from allUsers
        if (userAllStrategies[user].length() == 0) {
            allUsers.remove(user);
        }

        emit DCAPlanCancelled(
            _strategy,
            user,
            userPlanVaultAddress,
            planToCancel.id,
            token0,
            token1,
            userReceivedToken0Amount,
            userReceivedToken1Amount,
            block.timestamp
        );
    }

    ///@dev Claim the reward from the strategy and transfer to the user, require user reward > 0
    function _claimPlanReward(address _user, address _strategy, address _userPlanVaultAddress)
        internal
        returns (uint256 reward)
    {
        // Check that there is a reward to claim
        reward = IStrategyInfo(_strategy).userDistributeReward(_userPlanVaultAddress);
        require(reward > 0, "User plan reward is 0");

        // Strategy transfers the reward to the user's vault
        IStrategy(_strategy).claimReward(_userPlanVaultAddress);

        // Transfer the reward from the vault to the user
        uint256 rewardAmount = IERC20(Constants.DISTRIBUTE_REWARD_ADDRESS()).balanceOf(_userPlanVaultAddress);
        IDCAVault(_userPlanVaultAddress).transfer(Constants.DISTRIBUTE_REWARD_ADDRESS(), _user, rewardAmount);
    }

    function _transferRemainingFunds(address _userPlanVaultAddress, address _user, DCAPlan memory _planToCancel)
        internal
    {
        uint256 ethBalance = _userPlanVaultAddress.balance;

        if (ethBalance > 0) {
            _transferETH(ethBalance, _userPlanVaultAddress, _user);
        }

        address token0 = IStrategyInfo(_planToCancel.planDetail.strategy).token0Address();
        address token1 = IStrategyInfo(_planToCancel.planDetail.strategy).token1Address();

        uint256 token0Balance = IERC20(token0).balanceOf(_userPlanVaultAddress);

        if (token0Balance > 0) {
            _transferToken(token0, token0Balance, _userPlanVaultAddress, _user);
        }

        uint256 token1Balance = IERC20(token1).balanceOf(_userPlanVaultAddress);

        if (token1Balance > 0) {
            _transferToken(token1, token1Balance, _userPlanVaultAddress, _user);
        }
    }

    ///@dev Transfer the ETH from the userVault to the user
    function _transferETH(uint256 _value, address _userPlanVaultAddress, address _to) internal {
        // Check the vault balance is enough
        require(address(_userPlanVaultAddress).balance >= _value, "Insufficient ETH balance");

        IDCAVault(_userPlanVaultAddress).transferETH(_to, _value);
    }

    ///@dev Transfer the token from the userVault to the user
    function _transferToken(address _token, uint256 _value, address _userPlanVaultAddress, address _to) internal {
        // Check the vault balance is enough
        require(IERC20(_token).balanceOf(_userPlanVaultAddress) >= _value, "Insufficient token balance");

        IDCAVault(_userPlanVaultAddress).transfer(_token, _to, _value);
    }

    ///@dev Check if the user is in the set
    ///@param _user The user address
    ///@return true if the user is in the set
    function isUserExist(address _user) public view returns (bool) {
        return allUsers.contains(_user);
    }

    ///@dev Get the list of all users
    ///@return The list of all users
    function getAllUsers() external view returns (address[] memory) {
        return allUsers.values();
    }

    ///@dev Get the user's all strategies
    ///@param _user The user address
    ///@return The list of user involve all strategies
    function getUserAllStrategies(address _user) external view returns (address[] memory) {
        return userAllStrategies[_user].values();
    }

    ///@dev Get user's all DCA plans for the strategy
    ///@param _user The user address
    ///@param _strategy The strategy address
    ///@return The list of user's DCA plans for the strategy
    function getUserStrategyDCAPlans(address _user, address _strategy) external view returns (DCAPlan[] memory) {
        return userStrategyPlans[_user][_strategy];
    }

    function getUserCanceledPlans(address _user) external view returns (DCAPlan[] memory) {
        return userCanceledPlans[_user];
    }

    ///@dev Check if the user is allowed to execute the DCA plan
    ///@param _user The user address
    ///@param _strategy The strategy address
    ///@param _planIndex The index of the plan
    ///@return true if the user is allowed to execute the DCA plan
    function allowExecPlan(address _user, address _strategy, uint256 _planIndex) external view returns (bool) {
        require(_planIndex < userStrategyPlans[_user][_strategy].length, "Invalid plan index");

        DCAPlan memory plan = userStrategyPlans[_user][_strategy][_planIndex];
        return (plan.lastReinvestTimestamp + (plan.eachTimePeriod / 2) <= block.timestamp);
    }

    ///@dev Get the token0 and token1 address of the strategy
    function _getTokenAddresses(address _strategyAddress) internal view returns (address token0, address token1) {
        token0 = IStrategyInfo(_strategyAddress).token0Address();
        token1 = IStrategyInfo(_strategyAddress).token1Address();
    }

    ///@dev Set the fee numerator
    function setFeeNumerator(uint24 _numerator) external onlyRole(EXECUTOR_ROLE) {
        uint24 _oldNumerator = feeNumerator;
        feeNumerator = _numerator;
        emit FeeNumeratorUpdated(_oldNumerator, _numerator);
    }

    ///@dev Admin withdraw the token from the contract
    function adminWithdraw(address _token, uint256 _amount) external onlyRole(EXECUTOR_ROLE) {
        TransferHelper.safeTransfer(_token, msg.sender, _amount);
    }

    function _transferTokensIfNeeded(address _token, address _user, uint256 _amount, address _userPlanVaultAddress)
        internal
    {
        if (_amount > 0 && IERC20(_token).balanceOf(_userPlanVaultAddress) >= _amount) {
            IDCAVault(_userPlanVaultAddress).transfer(_token, _user, _amount);
        }
    }

    function _validateInputData(
        address _inputToken,
        uint256 _eachTimeInvestAmount,
        uint256 _eachTimePeriod,
        DCAPeriodData calldata _periodData
    ) internal view {
        //Only allow USDC or USDC.e as input token
        require(
            _inputToken == Constants.USDC_ADDRESS() || _inputToken == Constants.USDCE_ADDRESS(),
            "invalid USDC or USDC.e address"
        );
        require(_eachTimeInvestAmount > 0, "Invalid each time invest amount");
        require(_eachTimePeriod > 0, "Invalid each time period");

        // Validate the period data
        _validatePeriodData(_periodData);
    }

    function _validatePeriodData(DCAPeriodData calldata _periodData) internal pure {
        if (_periodData.month > 0) {
            require(_periodData.day >= 1 && _periodData.day <= 28, "Day must be between 1 and 28 when month is set");
        } else if (_periodData.week > 0) {
            require(_periodData.day >= 1 && _periodData.day <= 7, "Day must be between 1 and 7 when week is set");
        }
    }

    function _validatePlanIndexAndId(address _user, address _strategy, uint256 _planIndex, uint256 _planId)
        internal
        view
        returns (DCAPlan memory plan)
    {
        require(_planIndex < userStrategyPlans[_user][_strategy].length, "Invalid plan index");

        plan = userStrategyPlans[_user][_strategy][_planIndex];
        require(_planId == plan.id, "Plan ID not match");
    }

    function setMaxPlanAmount(uint256 _maxPlanAmount) external onlyRole(EXECUTOR_ROLE) {
        require(_maxPlanAmount > 0, "Max plan amount should be greater than 0");
        uint256 _oldMaxPlanAmount = maxPlanAmount;
        maxPlanAmount = _maxPlanAmount;
        emit MaxPlanAmountUpdated(_oldMaxPlanAmount, _maxPlanAmount);
    }
}