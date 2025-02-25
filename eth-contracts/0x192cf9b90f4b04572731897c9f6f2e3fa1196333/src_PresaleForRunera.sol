//SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "./lib_openzeppelin-contracts_contracts_token_ERC20_IERC20.sol";
import "./lib_openzeppelin-contracts_contracts_security_Pausable.sol";
import "./lib_openzeppelin-contracts_contracts_access_Ownable.sol";
import "./lib_openzeppelin-contracts_contracts_security_ReentrancyGuard.sol";

interface Aggregator {
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}

interface StakingManager {
    function depositByPresale(address _user, uint256 _amount) external;
}

contract Presale is ReentrancyGuard, Ownable, Pausable {
    uint256 public totalTokensSold;
    uint256 public startTime;
    uint256 public endTime;
    uint256 public claimStart;
    address public saleToken;
    uint256 public baseDecimals;
    uint256 public maxTokensToBuy;
    uint256 public currentStep;
    uint256 public checkPoint;
    uint256 public usdRaised;
    uint256 public timeConstant;
    uint256 public totalBoughtAndStaked;
    uint256[][3] public rounds;
    uint256[] public prevCheckpoints;
    uint256[] public remainingTokensTracker;
    uint256[] public percentages;
    address[] public wallets;
    address public paymentWallet;
    address public admin;
    bool public dynamicTimeFlag;
    bool public whitelistClaimOnly;
    bool public stakeingWhitelistStatus;
    uint256 public totalCommissionUsdt;
    uint256 public totalCommissionNativeToken;

    uint8 public constant PERCENTAGE_REFERRAl = 5;

    IERC20 public USDTInterface;
    Aggregator public aggregatorInterface;
    mapping(address => uint256) public userDeposits;
    mapping(address => uint256) public addressToAmountReferral;
    mapping(address => uint256) public addressToCommissionPercentage;

    mapping(address => bool) public hasClaimed;
    mapping(address => bool) public isBlacklisted;
    mapping(address => bool) public isWhitelisted;
    mapping(address => bool) public wertWhitelisted;

    StakingManager public stakingManagerInterface;

    event SaleTimeSet(uint256 _start, uint256 _end, uint256 timestamp);
    event SaleTimeUpdated(
        bytes32 indexed key,
        uint256 prevValue,
        uint256 newValue,
        uint256 timestamp
    );
    event TokensBought(
        address indexed user,
        uint256 indexed tokensBought,
        address indexed purchaseToken,
        uint256 amountPaid,
        uint256 usdEq,
        uint256 timestamp
    );
    event TokensAdded(
        address indexed token,
        uint256 noOfTokens,
        uint256 timestamp
    );
    event TokensClaimed(
        address indexed user,
        uint256 amount,
        uint256 timestamp
    );
    event ClaimStartUpdated(
        uint256 prevValue,
        uint256 newValue,
        uint256 timestamp
    );
    event MaxTokensUpdated(
        uint256 prevValue,
        uint256 newValue,
        uint256 timestamp
    );
    event TokensBoughtAndStaked(
        address indexed user,
        uint256 indexed tokensBought,
        address indexed purchaseToken,
        uint256 amountPaid,
        uint256 usdEq,
        uint256 timestamp
    );
    event TokensClaimedAndStaked(
        address indexed user,
        uint256 amount,
        uint256 timestamp
    );

    constructor(
        address _oracle,
        address _usdt,
        uint256 _startTime,
        uint256 _endTime,
        uint256[][3] memory _rounds,
        uint256 _maxTokensToBuy,
        address _paymentWallet
    ) {
        require(_oracle != address(0), "Zero aggregator address");
        require(_usdt != address(0), "Zero USDT address");
        require(
            _startTime > block.timestamp && _endTime > _startTime,
            "Invalid time"
        );
        // __Pausable_init_unchained();
        // __Ownable_init_unchained();
        // __ReentrancyGuard_init_unchained();
        baseDecimals = (10 ** 18);
        aggregatorInterface = Aggregator(_oracle);
        USDTInterface = IERC20(_usdt);
        startTime = _startTime;
        endTime = _endTime;
        rounds = _rounds;
        maxTokensToBuy = _maxTokensToBuy;
        paymentWallet = _paymentWallet;
        emit SaleTimeSet(startTime, endTime, block.timestamp);
    }

    /**
     * @dev To pause the presale
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev To unpause the presale
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev To calculate the price in USD for given amount of tokens.
     * @param _amount No of tokens
     */
    function calculatePrice(uint256 _amount) public view returns (uint256) {
        uint256 USDTAmount;
        uint256 total = checkPoint == 0 ? totalTokensSold : checkPoint;
        require(_amount <= maxTokensToBuy, "Amount exceeds max tokens to buy");
        if (
            _amount + total > rounds[0][currentStep] ||
            block.timestamp >= rounds[2][currentStep]
        ) {
            require(currentStep < (rounds[0].length - 1), "Wrong params");
            if (block.timestamp >= rounds[2][currentStep]) {
                require(
                    rounds[0][currentStep] + _amount <=
                        rounds[0][currentStep + 1],
                    "Cant Purchase More in individual tx"
                );
                USDTAmount = _amount * rounds[1][currentStep + 1];
            } else {
                uint256 tokenAmountForCurrentPrice = rounds[0][currentStep] -
                    total;
                USDTAmount =
                    tokenAmountForCurrentPrice *
                    rounds[1][currentStep] +
                    (_amount - tokenAmountForCurrentPrice) *
                    rounds[1][currentStep + 1];
            }
        } else {
            USDTAmount = _amount * rounds[1][currentStep];
        }
        return USDTAmount;
    }

    /**
     * @dev To update the sale times
     * @param _startTime New start time
     * @param _endTime New end time
     */
    function changeSaleTimes(
        uint256 _startTime,
        uint256 _endTime
    ) external onlyOwner {
        require(_startTime > 0 || _endTime > 0, "Invalid parameters");
        if (_startTime > 0) {
            require(block.timestamp < startTime, "Sale already started");
            require(block.timestamp < _startTime, "Sale time in past");
            uint256 prevValue = startTime;
            startTime = _startTime;
            emit SaleTimeUpdated(
                bytes32("START"),
                prevValue,
                _startTime,
                block.timestamp
            );
        }
        if (_endTime > 0) {
            require(_endTime > startTime, "Invalid endTime");
            uint256 prevValue = endTime;
            endTime = _endTime;
            emit SaleTimeUpdated(
                bytes32("END"),
                prevValue,
                _endTime,
                block.timestamp
            );
        }
    }

    /**
     * @dev To get latest ETH price in 10**18 format
     */
    function getLatestPrice() public view returns (uint256) {
        (, int256 price, , , ) = aggregatorInterface.latestRoundData();
        price = (price * (10 ** 10));
        return uint256(price);
    }

    function setSplits(
        address[] memory _wallets,
        uint256[] memory _percentages
    ) public onlyOwner {
        require(_wallets.length == _percentages.length, "Mismatched arrays");
        delete wallets;
        delete percentages;
        uint256 totalPercentage = 0;

        for (uint256 i = 0; i < _wallets.length; i++) {
            require(_percentages[i] > 0, "Percentage must be greater than 0");
            totalPercentage += _percentages[i];
            wallets.push(_wallets[i]);
            percentages.push(_percentages[i]);
        }

        require(totalPercentage == 100, "Total percentage must equal 100");
    }

    modifier checkSaleState(uint256 amount) {
        require(
            block.timestamp >= startTime && block.timestamp <= endTime,
            "Invalid time for buying"
        );
        require(amount > 0, "Invalid sale amount");
        _;
    }

    /**
     * @dev To buy into a presale using USDT
     * @param amount No of tokens to buy
     * @param stake boolean flag for token staking
     */
    function buyWithUSDT(
        uint256 amount,
        address referral,
        bool stake
    ) external checkSaleState(amount) whenNotPaused returns (bool) {
        uint256 usdPrice = calculatePrice(amount);
        totalTokensSold += amount;
        uint256 price = usdPrice / (10 ** 12);
        if (checkPoint != 0) checkPoint += amount;
        uint256 total = totalTokensSold > checkPoint
            ? totalTokensSold
            : checkPoint;
        if (
            total > rounds[0][currentStep] ||
            block.timestamp >= rounds[2][currentStep]
        ) {
            if (block.timestamp >= rounds[2][currentStep]) {
                checkPoint = rounds[0][currentStep] + amount;
            }
            if (dynamicTimeFlag) {
                manageTimeDiff();
            }
            uint256 unsoldTokens = total > rounds[0][currentStep]
                ? 0
                : rounds[0][currentStep] - total - amount;

            remainingTokensTracker.push(unsoldTokens);
            currentStep += 1;
        }
        if (stake) {
            if (stakeingWhitelistStatus) {
                require(
                    isWhitelisted[_msgSender()],
                    "User not whitelisted for stake"
                );
            }
            stakingManagerInterface.depositByPresale(
                _msgSender(),
                amount * baseDecimals
            );
            totalBoughtAndStaked += amount;
            emit TokensBoughtAndStaked(
                _msgSender(),
                amount,
                address(USDTInterface),
                price,
                usdPrice,
                block.timestamp
            );
        } else {
            userDeposits[_msgSender()] += (amount * baseDecimals);
            emit TokensBought(
                _msgSender(),
                amount,
                address(USDTInterface),
                price,
                usdPrice,
                block.timestamp
            );
        }
        usdRaised += usdPrice;
        uint256 ourAllowance = USDTInterface.allowance(
            _msgSender(),
            address(this)
        );
        require(price <= ourAllowance, "Make sure to add enough allowance");
        splitUSDTValue(price, referral);

        return true;
    }

    /**
     * @dev To buy into a presale using ETH
     * @param amount No of tokens to buy
     * @param stake boolean flag for token staking
     */
    function buyWithEth(
        uint256 amount,
        address referral,
        bool stake
    )
        external
        payable
        checkSaleState(amount)
        whenNotPaused
        nonReentrant
        returns (bool)
    {
        uint256 usdPrice = calculatePrice(amount);
        uint256 ethAmount = (usdPrice * baseDecimals) / getLatestPrice();

        require(msg.value >= ethAmount, "Less payment");
        uint256 excess = msg.value - ethAmount;
        totalTokensSold += amount;
        if (checkPoint != 0) checkPoint += amount;
        uint256 total = totalTokensSold > checkPoint
            ? totalTokensSold
            : checkPoint;

        if (
            total > rounds[0][currentStep] ||
            block.timestamp >= rounds[2][currentStep]
        ) {
            if (block.timestamp >= rounds[2][currentStep]) {
                checkPoint = rounds[0][currentStep] + amount;
            }

            if (dynamicTimeFlag) {
                manageTimeDiff();
            }

            uint256 unsoldTokens = total > rounds[0][currentStep]
                ? 0
                : rounds[0][currentStep] - total - amount;
            remainingTokensTracker.push(unsoldTokens);
            currentStep += 1;
        }

        if (stake) {
            if (stakeingWhitelistStatus) {
                require(
                    isWhitelisted[_msgSender()],
                    "User not whitelisted for stake"
                );
            }
            stakingManagerInterface.depositByPresale(
                _msgSender(),
                amount * baseDecimals
            );
            totalBoughtAndStaked += amount;
            emit TokensBoughtAndStaked(
                _msgSender(),
                amount,
                address(0),
                ethAmount,
                usdPrice,
                block.timestamp
            );
        } else {
            userDeposits[_msgSender()] += (amount * baseDecimals);
            emit TokensBought(
                _msgSender(),
                amount,
                address(0),
                ethAmount,
                usdPrice,
                block.timestamp
            );
        }
        usdRaised += usdPrice;
        splitETHValue(ethAmount, referral);
        if (excess > 0) sendValue(payable(_msgSender()), excess);

        return true;
    }

    /**
     * @dev To buy ETH directly from wert .*wert contract address should be whitelisted if wertBuyRestrictionStatus is set true
     * @param _user address of the user
     * @param _amount No of ETH to buy
     * @param stake boolean flag for token staking
     */
    function buyWithETHWert(
        address _user,
        uint256 _amount,
        address _referral,
        bool stake
    )
        external
        payable
        checkSaleState(_amount)
        whenNotPaused
        nonReentrant
        returns (bool)
    {
        require(
            wertWhitelisted[_msgSender()],
            "User not whitelisted for this tx"
        );
        uint256 usdPrice = calculatePrice(_amount);
        uint256 ethAmount = (usdPrice * baseDecimals) / getLatestPrice();
        require(msg.value >= ethAmount, "Less payment");
        uint256 excess = msg.value - ethAmount;
        totalTokensSold += _amount;
        if (checkPoint != 0) checkPoint += _amount;
        uint256 total = totalTokensSold > checkPoint
            ? totalTokensSold
            : checkPoint;
        if (
            total > rounds[0][currentStep] ||
            block.timestamp >= rounds[2][currentStep]
        ) {
            if (block.timestamp >= rounds[2][currentStep]) {
                checkPoint = rounds[0][currentStep] + _amount;
            }
            if (dynamicTimeFlag) {
                manageTimeDiff();
            }
            uint256 unsoldTokens = total > rounds[0][currentStep]
                ? 0
                : rounds[0][currentStep] - total - _amount;
            remainingTokensTracker.push(unsoldTokens);
            currentStep += 1;
        }
        if (stake) {
            if (stakeingWhitelistStatus) {
                require(isWhitelisted[_user], "User not whitelisted for stake");
            }
            stakingManagerInterface.depositByPresale(
                _user,
                _amount * baseDecimals
            );
            totalBoughtAndStaked += _amount;
            emit TokensBoughtAndStaked(
                _user,
                _amount,
                address(0),
                ethAmount,
                usdPrice,
                block.timestamp
            );
        } else {
            userDeposits[_user] += (_amount * baseDecimals);
            emit TokensBought(
                _user,
                _amount,
                address(0),
                ethAmount,
                usdPrice,
                block.timestamp
            );
        }
        usdRaised += usdPrice;
        splitETHValue(ethAmount, _referral);
        if (excess > 0) sendValue(payable(_user), excess);
        return true;
    }

    /**
     * @dev Helper funtion to get ETH price for given amount
     * @param amount No of tokens to buy
     */
    function ethBuyHelper(
        uint256 amount
    ) external view returns (uint256 ethAmount) {
        uint256 usdPrice = calculatePrice(amount);
        ethAmount = (usdPrice * baseDecimals) / getLatestPrice();
    }

    /**
     * @dev Helper funtion to get USDT price for given amount
     * @param amount No of tokens to buy
     */
    function usdtBuyHelper(
        uint256 amount
    ) external view returns (uint256 usdPrice) {
        usdPrice = calculatePrice(amount);
        usdPrice = usdPrice / (10 ** 12);
    }

    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Low balance");
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "ETH Payment failed");
    }

    function splitETHValue(uint256 _amount, address _referral) internal {
        if (wallets.length == 0) {
            uint256 referralReward = 0;
            if (_referral != address(0)) {
                if (addressToCommissionPercentage[_referral] != 0) {
                    referralReward =
                        (_amount * addressToCommissionPercentage[_referral]) /
                        100;
                } else {
                    referralReward = (_amount * PERCENTAGE_REFERRAl) / 100;
                }
                sendValue(payable(_referral), referralReward);
                addressToAmountReferral[_referral] += 1;

                totalCommissionNativeToken += referralReward;
            }
            uint256 remainingAmount = _amount - referralReward;
            require(paymentWallet != address(0), "Payment wallet not set");
            sendValue(payable(paymentWallet), remainingAmount);
        } else {
            uint256 tempCalc;
            for (uint256 i = 0; i < wallets.length; i++) {
                uint256 amountToTransfer = (_amount * percentages[i]) / 100;
                sendValue(payable(wallets[i]), amountToTransfer);
                tempCalc += amountToTransfer;
            }
            if ((_amount - tempCalc) > 0) {
                sendValue(
                    payable(wallets[wallets.length - 1]),
                    _amount - tempCalc
                );
            }
        }
    }

    function splitUSDTValue(uint256 _amount, address _referral) internal {
        if (wallets.length == 0) {
            uint256 referralReward = 0;

            require(paymentWallet != address(0), "Payment wallet not set");
            if (_referral != address(0)) {
                if (addressToCommissionPercentage[_referral] != 0) {
                    referralReward =
                        (_amount * addressToCommissionPercentage[_referral]) /
                        100;
                } else {
                    referralReward = (_amount * PERCENTAGE_REFERRAl) / 100;
                }
                (bool successForRef, ) = address(USDTInterface).call(
                    abi.encodeWithSignature(
                        "transferFrom(address,address,uint256)",
                        _msgSender(),
                        _referral,
                        referralReward
                    )
                );
                require(successForRef, "Token payment for referral failed");
                addressToAmountReferral[_referral] += 1;
                totalCommissionUsdt += referralReward;
            }
            uint256 remainingAmount = _amount - referralReward;
            (bool success, ) = address(USDTInterface).call(
                abi.encodeWithSignature(
                    "transferFrom(address,address,uint256)",
                    _msgSender(),
                    paymentWallet,
                    remainingAmount
                )
            );
            require(success, "Token payment for payment wallet failed");
        } else {
            uint256 tempCalc;
            for (uint256 i = 0; i < wallets.length; i++) {
                uint256 amountToTransfer = (_amount * percentages[i]) / 100;
                (bool success, ) = address(USDTInterface).call(
                    abi.encodeWithSignature(
                        "transferFrom(address,address,uint256)",
                        _msgSender(),
                        wallets[i],
                        amountToTransfer
                    )
                );
                require(success, "Token payment failed");
                tempCalc += amountToTransfer;
            }
            if ((_amount - tempCalc) > 0) {
                (bool success, ) = address(USDTInterface).call(
                    abi.encodeWithSignature(
                        "transferFrom(address,address,uint256)",
                        _msgSender(),
                        wallets[wallets.length - 1],
                        _amount - tempCalc
                    )
                );
                require(success, "Token payment failed");
            }
        }
    }

    /**
     * @dev to initialize staking manager with new addredd
     * @param _stakingManagerAddress address of the staking smartcontract
     */
    function setStakingManager(
        address _stakingManagerAddress
    ) external onlyOwner {
        require(
            _stakingManagerAddress != address(0),
            "staking manager cannot be inatialized with zero address"
        );
        stakingManagerInterface = StakingManager(_stakingManagerAddress);
        IERC20(saleToken).approve(_stakingManagerAddress, type(uint256).max);
    }

    /**
     * @dev To set the claim start time and sale token address by the owner
     * @param _claimStart claim start time
     * @param noOfTokens no of tokens to add to the contract
     * @param _saleToken sale toke address
     */
    function startClaim(
        uint256 _claimStart,
        uint256 noOfTokens,
        address _saleToken,
        address _stakingManagerAddress
    ) external onlyOwner returns (bool) {
        require(_saleToken != address(0), "Zero token address");
        require(claimStart == 0, "Claim already set");
        claimStart = _claimStart;
        saleToken = _saleToken;
        whitelistClaimOnly = true;
        if (_stakingManagerAddress != address(0)) {
            stakingManagerInterface = StakingManager(_stakingManagerAddress);
            IERC20(_saleToken).approve(
                _stakingManagerAddress,
                type(uint256).max
            );
        }
        bool success = IERC20(_saleToken).transferFrom(
            _msgSender(),
            address(this),
            noOfTokens
        );
        require(success, "Token transfer failed");
        emit TokensAdded(_saleToken, noOfTokens, block.timestamp);
        return true;
    }

    /**
     * @dev To set status for claim whitelisting
     * @param _status bool value
     */
    function setStakeingWhitelistStatus(bool _status) external onlyOwner {
        stakeingWhitelistStatus = _status;
    }

    /**
     * @dev To change the claim start time by the owner
     * @param _claimStart new claim start time
     */
    function changeClaimStart(
        uint256 _claimStart
    ) external onlyOwner returns (bool) {
        require(claimStart > 0, "Initial claim data not set");
        require(_claimStart > endTime, "Sale in progress");
        require(_claimStart > block.timestamp, "Claim start in past");
        uint256 prevValue = claimStart;
        claimStart = _claimStart;
        emit ClaimStartUpdated(prevValue, _claimStart, block.timestamp);
        return true;
    }

    /**
     * @dev To claim tokens after claiming starts
     */
    function claim() external whenNotPaused returns (bool) {
        require(saleToken != address(0), "Sale token not added");
        require(!isBlacklisted[_msgSender()], "This Address is Blacklisted");
        if (whitelistClaimOnly) {
            require(
                isWhitelisted[_msgSender()],
                "User not whitelisted for claim"
            );
        }
        require(block.timestamp >= claimStart, "Claim has not started yet");
        require(!hasClaimed[_msgSender()], "Already claimed");
        hasClaimed[_msgSender()] = true;
        uint256 amount = userDeposits[_msgSender()];
        require(amount > 0, "Nothing to claim");
        delete userDeposits[_msgSender()];
        bool success = IERC20(saleToken).transfer(_msgSender(), amount);
        require(success, "Token transfer failed");
        emit TokensClaimed(_msgSender(), amount, block.timestamp);
        return true;
    }

    function claimAndStake() external whenNotPaused returns (bool) {
        require(saleToken != address(0), "Sale token not added");
        require(!isBlacklisted[_msgSender()], "This Address is Blacklisted");
        if (stakeingWhitelistStatus) {
            require(
                isWhitelisted[_msgSender()],
                "User not whitelisted for stake"
            );
        }
        uint256 amount = userDeposits[_msgSender()];
        require(amount > 0, "Nothing to stake");
        stakingManagerInterface.depositByPresale(_msgSender(), amount);
        delete userDeposits[_msgSender()];
        emit TokensClaimedAndStaked(_msgSender(), amount, block.timestamp);
        return true;
    }

    /**
     * @dev To add wert contract addresses to whitelist
     * @param _addressesToWhitelist addresses of the contract
     */
    function whitelistUsersForWERT(
        address[] calldata _addressesToWhitelist
    ) external onlyOwner {
        for (uint256 i = 0; i < _addressesToWhitelist.length; i++) {
            wertWhitelisted[_addressesToWhitelist[i]] = true;
        }
    }

    /**
     * @dev To remove wert contract addresses to whitelist
     * @param _addressesToRemoveFromWhitelist addresses of the contracts
     */
    function removeFromWhitelistForWERT(
        address[] calldata _addressesToRemoveFromWhitelist
    ) external onlyOwner {
        for (uint256 i = 0; i < _addressesToRemoveFromWhitelist.length; i++) {
            wertWhitelisted[_addressesToRemoveFromWhitelist[i]] = false;
        }
    }

    function changeMaxTokensToBuy(uint256 _maxTokensToBuy) external onlyOwner {
        require(_maxTokensToBuy > 0, "Zero max tokens to buy value");
        uint256 prevValue = maxTokensToBuy;
        maxTokensToBuy = _maxTokensToBuy;
        emit MaxTokensUpdated(prevValue, _maxTokensToBuy, block.timestamp);
    }

    function changeRoundsData(uint256[][3] memory _rounds) external onlyOwner {
        rounds = _rounds;
    }

    /**
     * @dev To add users to blacklist which restricts blacklisted users from claiming
     * @param _usersToBlacklist addresses of the users
     */
    function blacklistUsers(
        address[] calldata _usersToBlacklist
    ) external onlyOwner {
        for (uint256 i = 0; i < _usersToBlacklist.length; i++) {
            isBlacklisted[_usersToBlacklist[i]] = true;
        }
    }

    /**
     * @dev To remove users from blacklist which restricts blacklisted users from claiming
     * @param _userToRemoveFromBlacklist addresses of the users
     */
    function removeFromBlacklist(
        address[] calldata _userToRemoveFromBlacklist
    ) external onlyOwner {
        for (uint256 i = 0; i < _userToRemoveFromBlacklist.length; i++) {
            isBlacklisted[_userToRemoveFromBlacklist[i]] = false;
        }
    }

    /**
     * @dev To add users to whitelist which restricts users from claiming if claimWhitelistStatus is true
     * @param _usersToWhitelist addresses of the users
     */
    function whitelistUsers(
        address[] calldata _usersToWhitelist
    ) external onlyOwner {
        for (uint256 i = 0; i < _usersToWhitelist.length; i++) {
            isWhitelisted[_usersToWhitelist[i]] = true;
        }
    }

    /**
     * @dev To remove users from whitelist which restricts users from claiming if claimWhitelistStatus is true
     * @param _userToRemoveFromWhitelist addresses of the users
     */
    function removeFromWhitelist(
        address[] calldata _userToRemoveFromWhitelist
    ) external onlyOwner {
        for (uint256 i = 0; i < _userToRemoveFromWhitelist.length; i++) {
            isWhitelisted[_userToRemoveFromWhitelist[i]] = false;
        }
    }

    /**
     * @dev To set status for claim whitelisting
     * @param _status bool value
     */
    function setClaimWhitelistStatus(bool _status) external onlyOwner {
        whitelistClaimOnly = _status;
    }

    /**
     * @dev To set payment wallet address
     * @param _newPaymentWallet new payment wallet address
     */
    function changePaymentWallet(address _newPaymentWallet) external onlyOwner {
        require(_newPaymentWallet != address(0), "address cannot be zero");
        paymentWallet = _newPaymentWallet;
    }

    /**
     * @dev To manage time gap between two rounds
     */
    function manageTimeDiff() internal {
        for (uint256 i; i < rounds[2].length - currentStep; i++) {
            rounds[2][currentStep + i] = block.timestamp + i * timeConstant;
        }
    }

    /**
     * @dev To set time constant for manageTimeDiff()
     * @param _timeConstant time in <days>*24*60*60 format
     */
    function setTimeConstant(uint256 _timeConstant) external onlyOwner {
        timeConstant = _timeConstant;
    }

    /**
     * @dev To get array of round details at once
     * @param _no array index
     */
    function roundDetails(
        uint256 _no
    ) external view returns (uint256[] memory) {
        return rounds[_no];
    }

    /**
     * @dev to update userDeposits for purchases made on BSC
     * @param _users array of users
     * @param _userDeposits array of userDeposits associated with users
     */
    function updateFromBSC(
        address[] calldata _users,
        uint256[] calldata _userDeposits
    ) external onlyOwner {
        require(_users.length == _userDeposits.length, "Length mismatch");
        for (uint256 i = 0; i < _users.length; i++) {
            userDeposits[_users[i]] += _userDeposits[i];
        }
    }

    /**
     * @dev Set commission percentage for each wallet
     */
    function setCommissionPercentage(
        address _refferal,
        uint256 _commissionPercentage
    ) external {
        require(
            msg.sender == admin || msg.sender == owner(),
            "caller not admin or owner"
        );

        require(
            _refferal != address(0),
            "The address should be different from address 0"
        );

        require(
            _commissionPercentage <= 40,
            "The commission percentage cannot be greater than 40 percent"
        );

        addressToCommissionPercentage[_refferal] = _commissionPercentage;
    }

    /**
     * @dev To increment the rounds from backend
     */
    function incrementCurrentStep() external {
        require(
            msg.sender == admin || msg.sender == owner(),
            "caller not admin or owner"
        );
        prevCheckpoints.push(checkPoint);
        if (dynamicTimeFlag) {
            manageTimeDiff();
        }
        if (checkPoint < rounds[0][currentStep]) {
            if (currentStep == 0) {
                remainingTokensTracker.push(
                    rounds[0][currentStep] - totalTokensSold
                );
            } else {
                remainingTokensTracker.push(
                    rounds[0][currentStep] - checkPoint
                );
            }
            checkPoint = rounds[0][currentStep];
        }
        currentStep++;
    }

    /**
     * @dev To set admin
     * @param _admin new admin wallet address
     */
    function setAdmin(address _admin) external onlyOwner {
        admin = _admin;
    }

    /**
     * @dev To change details of the round
     * @param _step round for which you want to change the details
     * @param _checkpoint token tracker amount
     */
    function setCurrentStep(
        uint256 _step,
        uint256 _checkpoint
    ) external onlyOwner {
        currentStep = _step;
        checkPoint = _checkpoint;
    }

    /**
     * @dev To set time shift functionality on/off
     * @param _dynamicTimeFlag bool value
     */
    function setDynamicTimeFlag(bool _dynamicTimeFlag) external onlyOwner {
        dynamicTimeFlag = _dynamicTimeFlag;
    }

    /**
     * @dev     Function to return remainingTokenTracker Array
     */
    function trackRemainingTokens() external view returns (uint256[] memory) {
        return remainingTokensTracker;
    }

    /**
     * @dev     To update remainingTokensTracker Array
     * @param   _unsoldTokens  input parameters in uint256 array format
     */
    function setRemainingTokensArray(uint256[] memory _unsoldTokens) public {
        require(
            msg.sender == admin || msg.sender == owner(),
            "caller not admin or owner"
        );
        require(_unsoldTokens.length != 0, "cannot update invalid values");
        delete remainingTokensTracker;
        for (uint256 i; i < _unsoldTokens.length; i++) {
            remainingTokensTracker.push(_unsoldTokens[i]);
        }
    }
}