// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.27;

import "./contracts_libraries_Periods.sol";
import "./contracts_libraries_Liquidity.sol";
import "./contracts_libraries_Tax.sol";
import "./contracts_libraries_Tokens.sol";
import "./contracts_interfaces_IDeveloper.sol";
import "./contracts_interfaces_IToken.sol";
import "./openzeppelin_contracts_token_ERC721_ERC721.sol";
import "./openzeppelin_contracts_token_ERC721_extensions_ERC721Enumerable.sol";
import "./openzeppelin_contracts_utils_Strings.sol";
import "./openzeppelin_contracts_utils_Base64.sol";
import "./uniswap_v2-periphery_contracts_interfaces_IUniswapV2Router02.sol";

contract Stake is ERC721, ERC721Enumerable {

    using Periods for uint256;
    using Tax for uint256;
    using Strings for uint256;
    using Tokens for IToken;
    using Liquidity for IUniswapV2Router02;

    struct GlobalConfig {
        uint256 period;
        uint256 deployPeriod;
        uint256 launchPeriod;
    }

    struct LaunchConfig {
        uint256 minimumLaunchPeriod;
        uint256 minimumRefundPeriod;
        uint256 minimumForceLaunchPeriod;
        uint256 minimumLaunchBalance;
        uint256 devAllocation;
    }

    struct PrestakeConfig {
        uint256 bonus;
        uint256 periodBonus;
        uint256 maxPeriods;
        uint256 airdrop;
        uint256 airdropPeriods;
        uint256 tokenMultiplier;
    }

    struct StakeConfig {
        uint256 periodRate;
        uint256 maxMultiplier;
        uint256 maxPeriods;
        uint256 maxClaims;
        uint256 percentToBank;
        uint256 percentToRewards;
    }

    struct BankConfig {
        uint256 periodRate;
        uint256 referralFee;
        uint256 withdrawPeriods;
        uint256 withdrawPercent;
    }

    struct Stats {
        uint256 totalSafe;
        uint256 totalBank;
        uint256 totalClaimed;
        uint256 rewardsPerShare;
        uint256 lastUpdate;
    }

    struct StakeInfo {
        uint256 id;
        address referrer;
        uint256 period;
        uint256 amount;
        uint256 initialSafeBalance;
        uint256 currentSafeBalance;
        uint256 initialBankBalance;
        uint256 currentBankBalance;
        uint256 airdrop;
        uint256 claims;
        uint256 availableSafe;
        uint256 availableBank;
        uint256 lastWithdraw;
        string image;
    }

    mapping(uint256 => uint256) private _airdropClaimed;
    mapping(uint256 => uint256) private _rewardDebt;
    mapping(uint256 => uint256) private _lastClaim;
    mapping(uint256 => uint256) private _lastBank;


    uint256 public constant MAX_SUPPLY = 10000;
    uint256 public constant IMAGE_COUNT = 5000;


    GlobalConfig public globalConfig;
    LaunchConfig public launchConfig;
    PrestakeConfig public prestakeConfig;
    StakeConfig public stakeConfig;
    BankConfig public bankConfig;
    Stats public stats;
    mapping(uint256 => StakeInfo) private _stakes;
    mapping(uint256 => uint256) private _multipliers;
    uint256 private _nextTokenId;
    IDeveloper private immutable _developer;
    IToken private _token;
    IToken private _pairToken;
    IUniswapV2Router02 private _router;


    event ProtocolLaunched();
    event RewardsUpdated();
    event AirdropClaimed(uint256 tokenId, uint256 amount);
    event PrestakeRefunded(uint256 tokenId, uint256 amount);
    event NewStake(uint256 tokenId, address referrer, uint256 amount);
    event BankClaimed(uint256 tokenId, uint256 amount);
    event BankCompounded(uint256 tokenId, uint256 amount);
    event BankWithdrawn(uint256 tokenId, uint256 amount);
    event SafeClaimed(uint256 tokenId, uint256 amount);
    event MetadataUpdate(uint256 tokenId);


    constructor() ERC721("Test DeFiDog Staking NFT", "TNDOG") {
        _developer = IDeveloper(msg.sender);
    }


    // #################################################################################################################
    // Setup functions. Can only be called once by the developer.
    // -----------------------------------------------------------------------------------------------------------------
    function setup(uint256 period, address tokenAddress, address pairTokenAddress, address routerAddress) external {
        require(msg.sender == address(_developer), "Stake: Unauthorized");
        require(address(_token) == address(0), "Stake: token already set");
        require(address(_pairToken) == address(0), "Stake: pair token already set");
        require(address(_router) == address(0), "Stake: router already set");
        _token = IToken(tokenAddress);
        _pairToken = IToken(pairTokenAddress);
        _router = IUniswapV2Router02(routerAddress);
        _setGlobalConfig(period);
        _setGlobalConfig(period);
        _setLaunchConfig(period);
        _setPrestakeConfig();
        _setStakeConfig();
        _setBankConfig();
        _preFillMultipliers();
    }
    function _setGlobalConfig(uint256 _period) internal {
        globalConfig = GlobalConfig({
            period: _period,
            deployPeriod: block.timestamp.period(_period),
            launchPeriod: 0
        });
    }
    function _setLaunchConfig(uint256 _period) internal {
        launchConfig = LaunchConfig({
            minimumLaunchPeriod: (block.timestamp + (_period * 30)).period(_period),
            minimumRefundPeriod: (block.timestamp + (_period * 60)).period(_period),
            minimumForceLaunchPeriod: (block.timestamp + (_period * 90)).period(_period),
            minimumLaunchBalance: 100000e18,
            devAllocation: 5e16 // 5% of total supply
        });
    }
    function _setPrestakeConfig() internal {
        prestakeConfig = PrestakeConfig({
            bonus: 5e16, // 5% bonus
            periodBonus: 25e14, // .25% period bonus
            maxPeriods: 30, // Max 30 periods of period bonus
            airdrop: 5e16, // 5% airdrop
            airdropPeriods: 75, // 75 periods until airdrop
            tokenMultiplier: 100 // 100:1 Token to Arb launch price
        });
    }
    function _setStakeConfig() internal {
        uint256 periodRate = 1e16; // 1% per period
        uint256 maxMultiplier = 10e18; // 10x maximum
        stakeConfig = StakeConfig({
            periodRate: periodRate,
            maxMultiplier: maxMultiplier,
            maxPeriods: 232, // it takes 232 periods to reach 10x
            maxClaims: 100, // maximum of 100 claims
            percentToBank: 125e15, // 12.5% of stake goes to bank
            percentToRewards: 125e15 // 12.5% of stake goes to rewards
        });
    }
    function _setBankConfig() internal {
        bankConfig = BankConfig({
            periodRate: 25e15, // 2.5% per period
            referralFee: 25e14, // .25% referral fee
            withdrawPeriods: 7, // 1 withdraw every 7 periods
            withdrawPercent: 25e16 // 25% of bank balance
        });
    }
    function _preFillMultipliers() internal {
        uint256 multiplier = 1e18;
        uint256 rate = stakeConfig.periodRate + 1e18;
        uint256 period = 1;
        while (multiplier < stakeConfig.maxMultiplier) {
            multiplier = (multiplier * rate) / 1e18;
            if (multiplier > stakeConfig.maxMultiplier) {
                multiplier = stakeConfig.maxMultiplier;
            }
            _multipliers[period] = multiplier;
            period++;
        }
        _multipliers[0] = 1e18;
    }
    // -----------------------------------------------------------------------------------------------------------------

    function currentTime() public view returns (uint256) {
        return block.timestamp;
    }

    function nft(uint256 tokenId) public view returns (StakeInfo memory) {
        StakeInfo memory stakeInfo = _stakes[tokenId];
        if (stakeInfo.amount == 0) return stakeInfo;
        stakeInfo = _calculatePreStakeBonusAndAirdrop(stakeInfo);
        stakeInfo = _calculateAutoCompound(stakeInfo);
        stakeInfo.availableBank = _calculateBankRewards(stakeInfo);
        stakeInfo.image = _getImageUri(_getImageNumber(tokenId));
        return stakeInfo;
    }
    function _calculatePreStakeBonusAndAirdrop(StakeInfo memory stakeInfo) internal view returns (StakeInfo memory) {
        uint256 effectiveLaunchPeriod = globalConfig.launchPeriod == 0 ? block.timestamp.period(globalConfig.period) : globalConfig.launchPeriod;
        if (stakeInfo.period > effectiveLaunchPeriod) return stakeInfo;
        uint256 bonus = stakeInfo.initialSafeBalance.tax(prestakeConfig.bonus);
        uint256 periods = effectiveLaunchPeriod.between(stakeInfo.period, globalConfig.period);
        if (periods > prestakeConfig.maxPeriods) periods = prestakeConfig.maxPeriods;
        uint256 periodBonus = periods > 0 ? stakeInfo.initialSafeBalance.tax(prestakeConfig.periodBonus) * periods : 0;
        uint256 totalPresaleSafe = stakeInfo.initialSafeBalance + bonus + periodBonus;
        uint256 totalPeriods = block.timestamp.between(stakeInfo.period, globalConfig.period);
        if (totalPeriods >= prestakeConfig.airdropPeriods && globalConfig.launchPeriod > 0) {
            stakeInfo.airdrop = totalPresaleSafe.tax(prestakeConfig.airdrop);
        }
        stakeInfo.currentSafeBalance = totalPresaleSafe;
        return stakeInfo;
    }
    function _calculateAutoCompound(StakeInfo memory stakeInfo) internal view returns (StakeInfo memory) {
        if (globalConfig.launchPeriod == 0) return stakeInfo;
        uint256 startAutoCompoundPeriod = stakeInfo.period > globalConfig.launchPeriod ? stakeInfo.period : globalConfig.launchPeriod;
        uint256 stakePeriods = block.timestamp.between(startAutoCompoundPeriod, globalConfig.period) - stakeInfo.claims;
        if (stakePeriods >= 1) {
            uint256 effectiveStakePeriods = stakePeriods - 1;
            if (effectiveStakePeriods > stakeConfig.maxPeriods) effectiveStakePeriods = stakeConfig.maxPeriods;
            stakeInfo.currentSafeBalance = stakeInfo.currentSafeBalance.tax(_multipliers[effectiveStakePeriods]);
        }
        if (_lastClaim[stakeInfo.id] < block.timestamp.period(globalConfig.period) && stakePeriods > 0 && stakeInfo.claims < stakeConfig.maxClaims) {
            stakeInfo.availableSafe = stakeInfo.currentSafeBalance.tax(stakeConfig.periodRate);
        }
        return stakeInfo;
    }
    function _calculateBankRewards(StakeInfo memory stakeInfo) internal view returns (uint256) {
        if(_lastBank[stakeInfo.id] >= block.timestamp.period(globalConfig.period)) return 0;
        return stakeInfo.currentBankBalance.tax(stats.rewardsPerShare) - _rewardDebt[stakeInfo.id];
    }

    function contractURI() public pure returns (string memory) {
        string memory json = '{"name": "DefiDog","description":"DeFiDog is a meme token with decentralized finance utility."}';
        return string.concat("data:application/json;utf8,", json);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);
        uint256 imageNumber = _getImageNumber(tokenId);
        string memory imageUri = _getImageUri(imageNumber);
        StakeInfo memory stakeInfo = nft(tokenId);
        return _buildTokenURI(tokenId, imageUri, stakeInfo);
    }

    function _getImageNumber(uint256 tokenId) internal pure returns (uint256) {
        return tokenId > IMAGE_COUNT ? tokenId % IMAGE_COUNT : tokenId;
    }

    function _getImageUri(uint256 imageNumber) internal pure returns (string memory) {
        return string(abi.encodePacked("ipfs://QmStdrwVvgYW7EDDkLhvzt8U39y3DJR5DizgvTUFs4Mt3Q/", imageNumber.toString(), ".png"));
    }

    function _buildTokenURI(uint256 tokenId, string memory imageUri, StakeInfo memory stakeInfo) internal pure returns (string memory) {
        return string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encode(
                    bytes(
                        abi.encodePacked(
                            "{",
                            '"name":"DeFiDog #', tokenId.toString(),
                            '","description":"DeFiDog is a meme token with decentralized finance utility.","image":"', imageUri, '","attributes":[',
                            '{"display_type":"date","trait_type":"Birthday","value":', stakeInfo.period.toString(), "},",
                            _getAttribute("Safe Balance", stakeInfo.currentSafeBalance, 18, false),
                            _getAttribute("Bank Balance", stakeInfo.currentBankBalance, 18, false),
                            _getAttribute("Claims", stakeInfo.claims, 0, true),
                            "]}"
                        )
                    )
                )
            )
        );
    }

    function _getAttribute(string memory traitType, uint256 value, uint8 decimals, bool isLast) internal pure returns (string memory) {
        string memory valueStr = decimals == 0 ? value.toString() : _toDecimalString(value, decimals);
        return string(
            abi.encodePacked(
                '{"trait_type":"', traitType, '","value":"', valueStr, '"}',
                isLast ? "" : ","
            )
        );
    }

    function _toDecimalString(uint256 value, uint8 decimals) internal pure returns (string memory) {
        uint256 integerPart = value / (10 ** decimals);
        uint256 fractionalPart = value % (10 ** decimals);
        return string(abi.encodePacked(integerPart.toString(), ".", _padFractionalPart(fractionalPart, decimals)));
    }

    function _padFractionalPart(uint256 fractionalPart, uint8 decimals) internal pure returns (string memory) {
        string memory fractionalStr = fractionalPart.toString();
        while (bytes(fractionalStr).length < decimals) {
            fractionalStr = string(abi.encodePacked("0", fractionalStr));
        }
        return fractionalStr;
    }

    function stake(address referrer, address token, uint256 amount) external update distribute {
        require(_nextTokenId < MAX_SUPPLY, "Stake: Maximum supply reached");
        require(referrer != msg.sender, "Stake: Invalid referrer");
        require(token != address(0), "Stake: Invalid token");
        require(amount > 0, "Stake: Invalid amount");
        IToken receivingToken = IToken(token);
        uint256 tokensReceived = receivingToken.receiveTokensFrom(msg.sender, amount);
        require(tokensReceived > 0, "Stake: Invalid amount");
        IToken _stakeToken = globalConfig.launchPeriod == 0 ? _pairToken : _token;
        uint256 stakeTokensReceived = _router.swapTokens(token, address(_stakeToken), tokensReceived);
        require(stakeTokensReceived > 0, "Stake: Invalid amount");
        if(globalConfig.launchPeriod == 0) stakeTokensReceived = stakeTokensReceived * prestakeConfig.tokenMultiplier;
        _stake(referrer, msg.sender, stakeTokensReceived);
    }


    function _stake(address referrer, address staker, uint256 amount) internal {
        if(referrer == address(0)) referrer = address(_developer);
        uint256 tokenId = ++_nextTokenId;
        uint256 amountToBank = amount.tax(stakeConfig.percentToBank);
        uint256 amountToRewards = amount.tax(stakeConfig.percentToRewards);
        uint256 amountToSafe = amount - amountToBank - amountToRewards;
        _stakes[tokenId] = StakeInfo({
            id: tokenId,
            referrer: referrer,
            period: block.timestamp.period(globalConfig.period),
            amount: amount,
            initialSafeBalance: amountToSafe,
            currentSafeBalance: amountToSafe,
            initialBankBalance: amountToBank,
            currentBankBalance: amountToBank,
            airdrop: 0,
            claims: 0,
            availableSafe: 0,
            availableBank: 0,
            lastWithdraw: block.timestamp.period(globalConfig.period),
            image: ''
        });
        _rewardDebt[tokenId] = amountToBank.tax(stats.rewardsPerShare);
        stats.totalSafe += amountToSafe;
        stats.totalBank += amountToBank;
        _safeMint(staker, tokenId);
        if(globalConfig.launchPeriod > 0) _addLiquidity(amount - amountToRewards);
        emit NewStake(tokenId, referrer, amount);
    }


    function _addLiquidity(uint256 amount) internal {
        uint256 tokenAmount = amount / 2;
        uint256 pairTokenAmount = _router.swapTokens(address(_token), address(_pairToken), amount - tokenAmount);
        _router.increaseLiquidity(address(_token), address(_pairToken), tokenAmount, pairTokenAmount);
    }

    function canRefund() external view returns (bool) {
        if(globalConfig.launchPeriod > 0) return false;
        if(_pairToken.balanceOf(address(this)) >= launchConfig.minimumLaunchBalance) return false;
        uint256 currentPeriod = block.timestamp.period(globalConfig.period);
        return currentPeriod >= launchConfig.minimumRefundPeriod && currentPeriod < launchConfig.minimumForceLaunchPeriod;
    }

    function refund(uint256 tokenId) external {
        require(globalConfig.launchPeriod == 0, "Stake: Already launched");
        require(msg.sender == ownerOf(tokenId), "Stake: Unauthorized");
        uint256 currentPeriod = block.timestamp.period(globalConfig.period);
        require(currentPeriod >= launchConfig.minimumRefundPeriod && currentPeriod < launchConfig.minimumForceLaunchPeriod, "Stake: Cannot refund");
        require(_pairToken.balanceOf(address(this)) < launchConfig.minimumLaunchBalance, "Stake: Cannot refund");
        StakeInfo memory stakeInfo = _stakes[tokenId];
        delete _stakes[tokenId];
        stats.totalSafe -= stakeInfo.initialSafeBalance;
        stats.totalBank -= stakeInfo.initialBankBalance;
        _pairToken.sendTokensTo(msg.sender, stakeInfo.amount / prestakeConfig.tokenMultiplier);
        emit PrestakeRefunded(tokenId, stakeInfo.amount / prestakeConfig.tokenMultiplier);
    }

    function canLaunch() external view returns (bool) {
        if(globalConfig.launchPeriod > 0) return false;
        uint256 currentPeriod = block.timestamp.period(globalConfig.period);
        if(currentPeriod < launchConfig.minimumLaunchPeriod) return false;
        uint256 currentBalance = _pairToken.balanceOf(address(this));
        if(currentBalance == 0) return false;
        if(currentBalance < launchConfig.minimumLaunchBalance && currentPeriod < launchConfig.minimumForceLaunchPeriod) return false;
        return true;
    }

    function launch() external {
        require(globalConfig.launchPeriod == 0, "Stake: Already launched");
        uint256 currentPeriod = block.timestamp.period(globalConfig.period);
        uint256 currentBalance = _pairToken.balanceOf(address(this));
        require(currentBalance > 0, "Stake: No balance");
        if(currentBalance >= launchConfig.minimumLaunchBalance) {
            require(currentPeriod >= launchConfig.minimumLaunchPeriod, "Stake: Minimum launch period not met");
        }
        else {
            require(currentPeriod >= launchConfig.minimumForceLaunchPeriod, "Stake: Minimum force launch period not met");
        }
        globalConfig.launchPeriod = currentPeriod;
        _distributeDevTokens(currentBalance);
        _createLiquidityPool(currentBalance);
        emit ProtocolLaunched();
        updateRewards();
    }
    function _distributeDevTokens(uint256 currentBalance) internal {
        uint256 adjustedCurrentBalance = currentBalance * prestakeConfig.tokenMultiplier;
        uint256 devAllocation = adjustedCurrentBalance.tax(launchConfig.devAllocation);
        uint256 devCount = _developer.devCount();
        if(devCount == 0) return;
        uint256 perDevAllocation = devAllocation / devCount;
        for(uint256 i = 1; i <= devCount; i++) {
            _stake(address(0), _developer.developers(i), perDevAllocation);
        }
    }
    function _createLiquidityPool(uint256 currentBalance) internal {
        uint256 mintAmount = (currentBalance + currentBalance.tax(stakeConfig.percentToRewards)) * prestakeConfig.tokenMultiplier;
        _token.mint(address(this), mintAmount);
        _router.increaseLiquidity(address(_token), address(_pairToken), currentBalance * prestakeConfig.tokenMultiplier, currentBalance);
        _token.setPair(_router.getPairAddress(address(_token), address(_pairToken)));
    }


    function airdrop(uint256 tokenId) external update distribute {
        require(ownerOf(tokenId) == msg.sender, "Stake: Unauthorized");
        StakeInfo memory stakeInfo = nft(tokenId);
        require(stakeInfo.airdrop > 0, "Stake: No airdrop available");
        require(_airdropClaimed[tokenId] == 0, "Stake: Airdrop already claimed");
        _airdropClaimed[tokenId] = block.timestamp.period(globalConfig.period);
        _token.mint(address(this), stakeInfo.airdrop);
        _sendTokensToStakerAndReferrer(tokenId, stakeInfo.airdrop);
        emit AirdropClaimed(tokenId, stakeInfo.airdrop);
    }


    function _sendTokensToStakerAndReferrer(uint256 tokenId, uint256 amount) internal {
        uint256 referralFee = amount.tax(bankConfig.referralFee);
        _token.sendTokensTo(ownerOf(tokenId), amount - referralFee);
        _token.sendTokensTo(_stakes[tokenId].referrer, referralFee);
    }


    function claimSafe(uint256 tokenId) external update distribute {
        require(msg.sender == ownerOf(tokenId), "Stake: Unauthorized");
        StakeInfo memory stakeInfo = nft(tokenId);
        require(stakeInfo.availableSafe > 0, "Stake: No safe rewards available");
        _stakes[tokenId].claims++;
        _stakes[tokenId].currentBankBalance += stakeInfo.availableSafe;
        _lastClaim[tokenId] = block.timestamp.period(globalConfig.period);
        stats.totalBank += stakeInfo.availableSafe;
        emit SafeClaimed(tokenId, stakeInfo.availableSafe);
        emit MetadataUpdate(tokenId);
    }


    function claimBank(uint256 tokenId) external update distribute {
        require(msg.sender == ownerOf(tokenId), "Stake: Unauthorized");
        StakeInfo memory stakeInfo = nft(tokenId);
        require(stakeInfo.availableBank > 0, "Stake: No bank rewards available");
        _rewardDebt[tokenId] += stakeInfo.availableBank;
        _lastBank[tokenId] = block.timestamp.period(globalConfig.period);
        stats.totalClaimed += stakeInfo.availableBank;
        _sendTokensToStakerAndReferrer(tokenId, stakeInfo.availableBank);
        emit BankClaimed(tokenId, stakeInfo.availableBank);
        emit MetadataUpdate(tokenId);
    }


    function compoundBank(uint256 tokenId) public update distribute {
        require(msg.sender == ownerOf(tokenId), "Stake: Unauthorized");
        StakeInfo memory stakeInfo = nft(tokenId);
        require(stakeInfo.availableBank > 0, "Stake: No bank rewards available");
        _rewardDebt[tokenId] += stakeInfo.availableBank;
        _stakes[tokenId].currentBankBalance += stakeInfo.availableBank;
        _lastBank[tokenId] = block.timestamp.period(globalConfig.period);
        stats.totalBank += stakeInfo.availableBank;
        emit BankCompounded(tokenId, stakeInfo.availableBank);
        emit MetadataUpdate(tokenId);
    }


    function withdraw(uint256 tokenId, uint256 amount) external update distribute {
        require(globalConfig.launchPeriod > 0, "Stake: Not launched");
        require(msg.sender == ownerOf(tokenId), "Stake: Unauthorized");
        StakeInfo memory stakeInfo = nft(tokenId);
        require(stakeInfo.currentBankBalance >= amount, "Stake: Insufficient bank balance");
        uint256 maxWithdrawAmount = stakeInfo.currentBankBalance.tax(bankConfig.withdrawPercent);
        require(amount <= maxWithdrawAmount, "Stake: Withdraw amount exceeds limit");
        uint256 periodsSinceLastWithdraw = _getEffectiveLastWithdrawPeriod(tokenId).between(block.timestamp, globalConfig.period);
        require(periodsSinceLastWithdraw >= bankConfig.withdrawPeriods, "Stake: Cannot withdraw yet");
        _stakes[tokenId].lastWithdraw = block.timestamp.period(globalConfig.period);
        _stakes[tokenId].currentBankBalance -= amount;
        _rewardDebt[tokenId] = _stakes[tokenId].currentBankBalance.tax(stats.rewardsPerShare);
        stats.totalBank -= amount;
        _token.mint(address(this), amount);
        _sendTokensToStakerAndReferrer(tokenId, amount);
        emit BankWithdrawn(tokenId, amount);
        emit MetadataUpdate(tokenId);
    }
    function _getEffectiveLastWithdrawPeriod(uint256 tokenId) internal view returns (uint256) {
        return _stakes[tokenId].lastWithdraw > globalConfig.launchPeriod ? _stakes[tokenId].lastWithdraw : globalConfig.launchPeriod;
    }


    function updateRewards() public {
        if(globalConfig.launchPeriod == 0) return;
        uint256 currentPeriod = block.timestamp.period(globalConfig.period);
        if(currentPeriod == stats.lastUpdate) return;
        uint256 balance = _token.balanceOf(address(this));
        uint256 availableRewards = balance.tax(bankConfig.periodRate);
        stats.rewardsPerShare += availableRewards * 1e18 / stats.totalBank;
        stats.lastUpdate = currentPeriod;
        emit RewardsUpdated();
    }


    // Openzeppelin overrides
    function _update(address to, uint256 tokenId, address auth) internal override(ERC721, ERC721Enumerable) returns (address) {
        return super._update(to, tokenId, auth);
    }
    function _increaseBalance(address account, uint128 value) internal override(ERC721, ERC721Enumerable) {
        super._increaseBalance(account, value);
    }
    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }


    modifier update() {
        updateRewards();
        _;
    }
    modifier distribute() {
        _developer.distribute();
        _;
    }
}