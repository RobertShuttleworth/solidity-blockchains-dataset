// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

import "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";
import "./openzeppelin_contracts-upgradeable_access_OwnableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC20_extensions_ERC20BurnableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_utils_math_SafeMathUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC20_utils_SafeERC20Upgradeable.sol";
import "./uniswap_v2-periphery_contracts_interfaces_IUniswapV2Router01.sol";
import "./chainlink_contracts_src_v0.8_shared_interfaces_AggregatorInterface.sol"; 
import "./openzeppelin_contracts-upgradeable_token_ERC20_extensions_IERC20MetadataUpgradeable.sol";



contract fPRXY is OwnableUpgradeable, ERC20BurnableUpgradeable {
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    event RewardAdded(uint256 reward);
    event Staked(
        address indexed user,
        uint256 totalStake,
        uint256 amount,
        uint256 stakeTime,
        uint256 stakeId
    );
    event Unstaked(
        address indexed user,
        uint256 totalStake,
        uint256 amount,
        uint256 unstakeTime,
        uint256 stakeId
    );
    event RewardPaid(address indexed user, uint256 reward);
    event RecoverToken(address indexed token, uint256 indexed amount);

    uint256[4] public rewardPerTokenStored;
    uint256[3] public stakeLimit;
    uint256[4] public stakePerTier;

    uint256[4] private apy;

    uint256 public stakingStartDate;
    uint256 private totalStakeAmount;
    uint256 public lastUpdateTime;
    uint256 public userCount;
    uint256 public unstakeLockingPeriod;
    uint256 public totalRewards;

    bool public stakingStatus;

    address public V2_ROUTER;
    address public USDC;
    address public WBTC;
    address public PRXY;
    address public BTCpx;
    address public treasury;
    address public btcpxTreasury;

    mapping(address => mapping(uint256 => uint256))
        public userRewardPerTokenPaidById;
    mapping(address => mapping(uint256 => uint256)) public rewardsById;
    mapping(uint256 => address) public userList;
    mapping(address => bool) internal isExisting;
    mapping(address => mapping(uint256 => uint256)) public userStakeById;
    mapping(address => mapping(uint256 => bool)) public rewardClaimStatusById;
    mapping(address => mapping(uint256 => bool)) public userStakeIdStatus;
    mapping(address => mapping(uint256 => uint256)) public userStakeTimeById;
    mapping(address => uint256) internal userStake;
    mapping(address => uint256) public userTotalStakeId;

    function initialize(uint256 _stakingStartDate) external initializer {
        __ERC20_init("Farm PRXY", "fPRXY");
        __ERC20Burnable_init();
        __Ownable_init();
        stakingStartDate = _stakingStartDate;
        stakingStatus = true;
        treasury = 0xf76FD435Bab7392B52B4123f0A16D8310EfDF8E0;
        btcpxTreasury = 0xd1f4EC7fF772BC382c2345Cc4F57dc4bF13685a9;
        unstakeLockingPeriod = 1 days;
        apy[0] = 0;
        apy[1] = 300;
        apy[2] = 500;
        apy[3] = 700;
        stakeLimit[0] = 1000e18;
        stakeLimit[1] = 10000e18;
        stakeLimit[2] = 25000e18;
        V2_ROUTER = 0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff;
        USDC = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
        WBTC = 0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6;
        PRXY = 0xab3D689C22a2Bb821f50A4Ff0F21A7980dCB8591;
        BTCpx = 0x9C32185b81766a051E08dE671207b34466DD1021;
    }






    function setStakingStatus(bool val) public onlyOwner {
        stakingStatus = val;
    }

    function updateTreasury(address _treasury) external onlyOwner {
        treasury = _treasury;
    }

    //_lockingPeriod should be in seconds li,e 1 days = 86400 seconds
    function updateLockingPeriod(uint256 _lockingPeriod) external onlyOwner {
        unstakeLockingPeriod = _lockingPeriod;
    }

    function updateBtCpxTreasury(address _treasury) external onlyOwner {
        btcpxTreasury = _treasury;
    }

    function updateApyValue(uint256[4] memory _apy) external onlyOwner {
        apy = _apy;
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp;
    }

    function getStakeTier(uint256 _stakeAmount)
        public
        view
        returns (uint256 _apyIndex)
    {
        if (_stakeAmount < stakeLimit[1] && _stakeAmount >= stakeLimit[0]) {
            _apyIndex = 1;
        } else if (
            _stakeAmount < stakeLimit[2] && _stakeAmount >= stakeLimit[1]
        ) {
            _apyIndex = 2;
        } else if (_stakeAmount >= stakeLimit[2]) {
            _apyIndex = 3;
        }
    }

    function updateReward(
        address account,
        uint256 index,
        uint256 amount,
        bool isStaking
    ) private {
        uint256 _stakeId = userTotalStakeId[account];
        if (block.timestamp >= stakingStartDate) {
            rewardPerTokenStored[0] = rewardPerToken(0);
            rewardPerTokenStored[1] = rewardPerToken(1);
            rewardPerTokenStored[2] = rewardPerToken(2);
            rewardPerTokenStored[3] = rewardPerToken(3);
            lastUpdateTime = lastTimeRewardApplicable();
            if (account != address(0)) {
                for (uint256 i = 0; i < _stakeId; i++) {
                    if (userStakeIdStatus[account][i]) {
                        uint256 _stakeAmount = userStakeById[account][i];

                        if (isStaking && index == i) {
                            _stakeAmount = amount;
                        }
                        uint256 _apyIndex = getStakeTier(_stakeAmount);
                        _stakeAmount = userStakeById[account][i];

                        rewardsById[account][i] = earned(
                            account,
                            _apyIndex,
                            _stakeAmount,
                            i
                        );
                        userRewardPerTokenPaidById[account][
                            i
                        ] = rewardPerTokenStored[_apyIndex];
                    }
                }
            }
        }
    }

    function rewardPerToken(uint256 _apyIndex) public view returns (uint256) {
        if (block.timestamp < stakingStartDate) {
            return 0;
        }
        if (totalSupply() == 0) {
            return rewardPerTokenStored[_apyIndex];
        }
        return
            rewardPerTokenStored[_apyIndex].add(
                lastTimeRewardApplicable()
                    .sub(lastUpdateTime)
                    .mul(rewardRate(_apyIndex))
                    .mul(1e18)
                    .div(totalSupply())
            );
    }

    function earned(
        address account,
        uint256 _apyIndex,
        uint256 _stakeAmount,
        uint256 _stakingId
    ) public view returns (uint256 _rewardEarned) {
        _rewardEarned = _stakeAmount
            .mul(
                rewardPerToken(_apyIndex).sub(
                    userRewardPerTokenPaidById[account][_stakingId]
                )
            )
            .div(1e18)
            .add(rewardsById[account][_stakingId]);
    }

    function earnedByList(address account, uint256[] memory _stakeId)
        external
        view
        returns (uint256 _rewardEarned)
    {
        for (uint256 i = 0; i < _stakeId.length; i++) {
            uint256 _stakingId = _stakeId[i];
            if (userStakeIdStatus[account][_stakingId]) {
                uint256 _stakeAmount = userStakeById[account][_stakingId];
                uint256 _apyIndex = getStakeTier(_stakeAmount);
                _rewardEarned += earned(
                    account,
                    _apyIndex,
                    _stakeAmount,
                    _stakingId
                );
            } else {
                _rewardEarned += rewardsById[account][_stakingId];
            }
        }
    }

    function stake(uint256 amount, address recipient) external {
        require(amount > 0, "Cannot stake 0");
        require(stakingStatus, "Staking is paused");
        if (!isUserExisting(recipient)) {
            userList[userCount] = recipient;
            userCount++;
            isExisting[recipient] = true;
        }
        IERC20Upgradeable(PRXY).safeTransferFrom(
            _msgSender(),
            treasury,
            amount
        );
        uint256 _stakeId = userTotalStakeId[recipient];
        uint256 _apyIndex = getStakeTier(amount);
        stakePerTier[_apyIndex] += amount;
        userStakeTimeById[recipient][_stakeId] = block.timestamp;
        userStakeIdStatus[recipient][_stakeId] = true;
        userTotalStakeId[recipient]++;
        updateReward(recipient, _stakeId, amount, true);
        userStakeById[recipient][_stakeId] = amount;
        userStake[recipient] += amount;
        _mint(recipient, amount);
        emit Staked(
            recipient,
            userStake[recipient],
            amount,
            block.timestamp,
            _stakeId
        );
    }


// The two checks need to be implemented at the start of the unstake function.
// userStakeById[_msgSender()][_stakeId] = 0; // Need to be checked if the tokens are 0 for that _stakeId.
// userStakeIdStatus[_msgSender()][_stakeId] = false; // Need to be checked if the user has already unstaked the tokens for that _stakeId.





    function unstake(uint256 _stakeId) public {
        require(
            block.timestamp >
                userStakeTimeById[_msgSender()][_stakeId].add(
                    unstakeLockingPeriod
                ),
            "Not allowed to unstake"
        );
        require( userStakeIdStatus[_msgSender()][_stakeId] == false, "You already have unstaked Your Token");
        updateReward(_msgSender(), 0, 0, false);
        uint256 _stakeAmount = userStakeById[_msgSender()][_stakeId];
        require(_stakeAmount <= userStake[_msgSender()], "Cannot withdraw 0");
        userStakeById[_msgSender()][_stakeId] = 0;
        userStakeIdStatus[_msgSender()][_stakeId] = false;
        userStake[_msgSender()] -= _stakeAmount;
        uint256 _apyIndex = getStakeTier(_stakeAmount);
        stakePerTier[_apyIndex] -= _stakeAmount;
        _burn(_msgSender(), _stakeAmount);
        IERC20Upgradeable(PRXY).safeTransferFrom(
            treasury,
            _msgSender(),
            _stakeAmount
        );
        emit Unstaked(
            _msgSender(),
            userStake[_msgSender()],
            _stakeAmount,
            block.timestamp,
            _stakeId
        );
    }




    function getReward(uint256[] memory _stakeId) public {
        
        updateReward(_msgSender(), 0, 0, false);
        uint256 _rewardEarned;

        // Use a mapping to track unique stake IDs.
        // mapping(uint256 => bool) memory uniqueStakeIds;
         bool[] memory uniqueStakeIds = new bool[](_stakeId.length);


        for (uint256 i = 0; i < _stakeId.length; i++) {
            uint256 _stakingId = _stakeId[i];

             // Skip if this stake ID has already been processed.
            if (uniqueStakeIds[_stakingId]) {
                continue;
            }

             // Mark this stake ID as processed.
             uniqueStakeIds[_stakingId] = true;

            // Check if the reward has already been claimed or the user has unstaked.
            if (
                rewardClaimStatusById[_msgSender()][_stakingId] == true
                // userStakeIdStatus[_msgSender()][_stakingId] == false
            ) {
                continue; // Skip this stake ID if reward has already been claimed or unstaked.
            }

            if (userStakeIdStatus[_msgSender()][_stakingId]) {
                uint256 _stakeAmount = userStakeById[_msgSender()][_stakingId];
                uint256 _apyIndex = getStakeTier(_stakeAmount);
                _rewardEarned += earned(
                    _msgSender(),
                    _apyIndex,
                    _stakeAmount,
                    _stakingId
                );
            } else {
                _rewardEarned += rewardsById[_msgSender()][_stakingId];
            }

            // Mark reward as claimed for this stake ID.
            rewardClaimStatusById[_msgSender()][_stakingId] = true;

            // Reset rewards for this stake ID.
            rewardsById[_msgSender()][_stakingId] = 0;
        }

        if (_rewardEarned > 0) {
            // Divide by 1e8 to normalize the multiplication in reward rate.
            IERC20Upgradeable(BTCpx).safeTransferFrom(
                btcpxTreasury,
                _msgSender(),
                _rewardEarned.div(1e8)
            );
            emit RewardPaid(_msgSender(), _rewardEarned);
            totalRewards += _rewardEarned;
        }
}


    function getTotalRewardForYear(uint256 _apyIndex)
        public
        view
        returns (uint256)
    {
        return
            apy[_apyIndex]
                .mul(totalSupply().mul(getPrxyPriceInUsd()))
                .div(getBtcPriceInUsd().mul(1e10))
                .div(10000);
    }

    function getTotalRewardForYearByAmount(uint256 _amount)
        public
        view
        returns (uint256)
    {
        uint256 apyInfo = _amount < 1000e18
            ? apy[0]
            : (_amount > 10000e18 ? apy[2] : apy[1]);
        return
            apyInfo
                .mul(totalSupply().mul(getPrxyPriceInUsd()))
                .div(getBtcPriceInUsd().mul(1e10))
                .div(10000);
    }

    function getOutputAmount(uint256 amountIn, address[] memory path)
        private
        view
        returns (uint256 _output)
    {
        uint256[] memory amounts = IUniswapV2Router01(V2_ROUTER).getAmountsOut(
            amountIn,
            path
        );
        return amounts[amounts.length - 1];
    }

    function getPrxyPriceInUsd() public view returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = PRXY;
        path[1] = USDC;
        uint256[] memory amounts = IUniswapV2Router01(V2_ROUTER).getAmountsOut(
            1e18,
            path
        );
        return amounts[amounts.length - 1];
    }

    function getBtcPriceInUsd() public view returns (uint256) {
      return uint256(AggregatorInterface(0xc907E116054Ad103354f2D350FD2514433D57F6f).latestAnswer());
    }

    function getTVLInUsd() external view returns (uint256) {
        return (totalSupply().mul(getPrxyPriceInUsd())).div(1 * 10**(18));
    }

    //multiplied by 10**4 make take 6 dp
    function getAPY()
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        return (apy[0].mul(10**4), apy[1].mul(10**4), apy[2].mul(10**4), apy[3].mul(10**4));
    }

    function rewardRate(uint256 _apyIndex) public view returns (uint256) {
        //multiplied by 1e8 for decimals
        return getTotalRewardForYear(_apyIndex).mul(1e8).div(31536000);
    }

    function stakeAmount(address account) public view returns (uint256) {
        return userStake[account];
    }

    function rewardTokenDecimals() external view returns (uint8) {
        return IERC20MetadataUpgradeable(BTCpx).decimals();
    }

    function stakeTokenDecimals() external view returns (uint8) {
        return IERC20MetadataUpgradeable(PRXY).decimals();
    }

    function stakeToken() external view returns (address) {
        return PRXY;
    }

    function rewardToken() external view returns (address) {
        return BTCpx;
    }

    function isUserExisting(address _who) public view returns (bool) {
        return isExisting[_who];
    }

    function recoverExcessToken(address token, uint256 amount)
        external
        onlyOwner
    {
        IERC20Upgradeable(token).safeTransfer(owner(), amount);
        emit RecoverToken(token, amount);
    }

    function recoverETH() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}