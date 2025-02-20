// SPDX-License-Identifier: MIT

pragma solidity ^0.8.27;

import './openzeppelin_contracts_token_ERC20_IERC20.sol';
import './openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol';
import './openzeppelin_contracts_access_Ownable.sol';
import './openzeppelin_contracts_utils_Pausable.sol';
import './contracts_BlackSail_Interface.sol';

interface IIchiDepositHelper {
    function forwardDepositToICHIVault(
        address _vault,
        address _deployer,
        address _token,
        uint256 _amount,
        uint256 _minAmountOut,
        address _to
    ) external;
}

contract Blacksail_StrategyV3 is Ownable, Pausable {
    using SafeERC20 for IERC20;

    uint256 public immutable MAX = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

    // Tokens
    address public native_token;
    address public reward_token;
    address public staking_token;
    address public deposit_token;

    // Fee structure
    uint256 public WITHDRAWAL_MAX = 100000;
    uint256 public WITHDRAW_FEE = 100;  //      0.1% of withdrawal amount
    uint256 public DIVISOR = 1000;
    uint256 public CALL_FEE = 100;  //          10% of Platform fee  
    uint256 public FEE_BATCH = 900; /*        90% of Platform fee  */ /** @dev 1/2 goes to treasury 1/2 to vaults */ 
    uint256 public PLATFORM_FEE = 45; //         4.5% Platform fee 

    // Third Party Addresses
    address public rewardPool;
    address public ichi;
    address public vaultDeployer;
    address public unirouter;

    // Information
    uint256 public lastHarvest;
    bool public harvestOnDeposit;

    // Platform Addresses
    address public quarterMaster;
    address public feeDistributor;
    address public vault;
    address public factory;

    // Routes
    ISolidlyRouter.Routes[] public rewardToNative;
    ISolidlyRouter.Routes[] public nativeToDeposit;
    address[] public rewards;

    event Harvest(address indexed harvester);
    event ChargeFees(uint256 callFee, uint256 protocolFee);
    event Deposit(uint256 amount);
    event Withdraw(uint256 amount);

    constructor (
        address _staking_token,
        address _rewardPool,
        address _ichi,
        address _vaultDeployer,
        address _unirouter,
        bool _harvestOnDeposit,
        ISolidlyRouter.Routes[] memory _rewardToNative,
        ISolidlyRouter.Routes[] memory _nativeToDeposit,
        address _factory,
        address _feeDistributor
    ) Ownable(msg.sender) {

        quarterMaster = msg.sender;
        staking_token = _staking_token;
        rewardPool = _rewardPool;
        ichi = _ichi;
        vaultDeployer = _vaultDeployer;
        unirouter = _unirouter;
        factory = _factory;
        feeDistributor = _feeDistributor;

        harvestOnDeposit = _harvestOnDeposit;

        for (uint i; i < _rewardToNative.length; i++) {
            rewardToNative.push(_rewardToNative[i]);
        }

        for (uint i; i < _nativeToDeposit.length; i++) {
            nativeToDeposit.push(_nativeToDeposit[i]);
        }

        reward_token = rewardToNative[0].from;
        native_token = rewardToNative[rewardToNative.length - 1].to;
        deposit_token = nativeToDeposit[nativeToDeposit.length - 1].to;

        rewards.push(reward_token);
        _giveAllowances();
    }

    /// @dev sets fee distributor
    function setDistributor(address _distributor) external {
        require(msg.sender == quarterMaster, "!auth");

        feeDistributor = _distributor;
    }

    /** @dev Sets the vault connected to this strategy */
    function setVault(address _vault) external onlyOwner {
        vault = _vault;
    }

    /** @dev Function to synchronize balances before new user deposit. Can be overridden in the strategy. */
    function beforeDeposit() external virtual {
        if (harvestOnDeposit) {
            require(msg.sender == vault, "Vault deposit only");
            _harvest(tx.origin);
        }
    }

    /** @dev Deposits funds into third party farm */
    function deposit() public whenNotPaused {

        // if (ISailFactory(factory).paused()) revert('Protocol has paused all vaults');

        uint256 staking_balance = IERC20(staking_token).balanceOf(address(this));

        if (staking_balance > 0) {
           IEqualizerPool(rewardPool).deposit(staking_balance);
        } 
    }

    function withdraw(uint256 _amount) external {
        require(msg.sender == vault, "!vault");

        uint256 stakingBal = IERC20(staking_token).balanceOf(address(this));

        if (stakingBal < _amount) {
            IEqualizerPool(rewardPool).withdraw(_amount - stakingBal);
            stakingBal = IERC20(staking_token).balanceOf(address(this));
        }           
 
        if (stakingBal > _amount) {
            stakingBal = _amount;
        }

        uint256 wFee = (stakingBal * WITHDRAW_FEE) / WITHDRAWAL_MAX;

        if (tx.origin != owner() && !paused()) {
            stakingBal = stakingBal - wFee;
        }

        emit Withdraw(stakingBal - wFee);
    }

    function harvest() external {
        require(msg.sender == tx.origin || msg.sender == vault, "!auth Contract Harvest");
        _harvest(msg.sender);
    }

    /** @dev Compounds the strategy's earnings and charges fees */
    function _harvest(address caller) internal whenNotPaused {
        
        IEqualizerPool(rewardPool).getReward(address(this), rewards);
        uint256 rewardAmt = IERC20(reward_token).balanceOf(address(this));

        if (rewardAmt > 0){
            chargeFees(caller);
            addLiquidity();
            deposit();
        }

        lastHarvest = block.timestamp;
        emit Harvest(msg.sender);
    }

    /** @dev This function converts all funds to WFTM, charges fees, and sends fees to respective accounts */
    function chargeFees(address caller) internal {                  
        uint256 toNative = IERC20(reward_token).balanceOf(address(this));

        ISolidlyRouter(unirouter).swapExactTokensForTokens(toNative, 0, rewardToNative, address(this), block.timestamp);
        
        uint256 nativeBal = IERC20(native_token).balanceOf(address(this)) * PLATFORM_FEE / DIVISOR;         

        uint256 callFeeAmount = nativeBal * CALL_FEE / DIVISOR;      
        IERC20(native_token).safeTransfer(caller, callFeeAmount);

        uint256 sailFee = nativeBal * FEE_BATCH / DIVISOR;
        IERC20(native_token).safeTransfer(feeDistributor, sailFee);

        emit ChargeFees(callFeeAmount, sailFee);
    }

    /** @dev Converts WFTM to deposit_token */
    function addLiquidity() internal {

        uint256 nativeBalance = IERC20(native_token).balanceOf(address(this));

        if (native_token != deposit_token) {
            ISolidlyRouter(unirouter).swapExactTokensForTokens(
                nativeBalance, 0, nativeToDeposit, address(this), block.timestamp
            );
        }

        uint256 depositTokenBal = IERC20(deposit_token).balanceOf(address(this));
        IIchiDepositHelper(ichi).forwardDepositToICHIVault(
            staking_token, vaultDeployer, deposit_token, depositTokenBal, 0, address(this)
        );
    }

    /** @dev Determines the amount of reward in WFTM upon calling the harvest function */
    function harvestCallReward() public view returns (uint256) {
        uint256 rewardBal = rewardsAvailable();
        uint256 nativeOut;
        if (rewardBal > 0) {
            (nativeOut, ) = ISolidlyRouter(unirouter).getAmountOut(rewardBal, reward_token, native_token);
        }

        return (((nativeOut * PLATFORM_FEE) / DIVISOR) * CALL_FEE) / DIVISOR;
    }

    /** @dev Sets harvest on deposit to @param _harvestOnDeposit */
    function setHarvestOnDeposit(bool _harvestOnDeposit) external onlyOwner {
        harvestOnDeposit = _harvestOnDeposit;

        if (harvestOnDeposit) {
            setWithdrawalFee(0);
        } else {
            setWithdrawalFee(10);
        }
    }

    /** @dev Returns the amount of rewards that are pending */
    function rewardsAvailable() public view returns (uint256) {
        return IEqualizerPool(rewardPool).earned(reward_token, address(this));
    }

    /** @dev calculate the total underlaying staking tokens held by the strat */
    function balanceOf() public view returns (uint256) {
        return balanceOfStakingToken() + balanceOfPool();
    }

    /** @dev it calculates how many staking tokens this contract holds */
    function balanceOfStakingToken() public view returns (uint256) {
        return IERC20(staking_token).balanceOf(address(this));
    }

    /** @dev it calculates how many staking tokens the strategy has working in the farm */
    function balanceOfPool() public view returns (uint256) {
        return IEqualizerPool(rewardPool).balanceOf(address(this));
        // return _amount;
    }

    /** @dev called as part of strat migration. Sends all the available funds back to the vault */
    function retireStrat() external {
        require(msg.sender == vault, "!vault");
        IEqualizerPool(rewardPool).withdraw(balanceOfPool());
        uint256 stakingBal = IERC20(staking_token).balanceOf(address(this));
        IERC20(staking_token).transfer(vault, stakingBal);
    }

    /** @dev Pauses the strategy contract and executes the emergency withdraw function */
    function panic() public Quartermaster() {
        pause();
        IEqualizerPool(rewardPool).withdraw(balanceOfPool());
    }

    /** @dev Pauses the strategy contract */
    function pause() public Quartermaster() {
        _pause();
        _removeAllowances();
    }

    /** @dev Unpauses the strategy contract */
    function unpause() external Quartermaster() {
        _unpause();
        _giveAllowances();
        deposit();
    }

    /** @dev Gives allowances to spenders */
    function _giveAllowances() internal {
        IERC20(staking_token).approve(rewardPool, MAX);
        IERC20(reward_token).approve(unirouter, MAX);
        IERC20(native_token).approve(unirouter, MAX);
        IERC20(deposit_token).approve(ichi, MAX);
    }

    /** @dev Removes allowances to spenders */
    function _removeAllowances() internal {
        IERC20(staking_token).approve(rewardPool, 0);
        IERC20(reward_token).approve(unirouter, 0);
        IERC20(native_token).approve(unirouter, 0);
        IERC20(deposit_token).approve(ichi, 0);
    }

    function setWithdrawalFee(uint256 fee) internal {
        require(fee <= 100, "Fee too high");
        // Maximum 0.1% withdrawal fee (WITHDRAW_FEE / DIVISOR)
        WITHDRAW_FEE = fee;
    }

    modifier Quartermaster() {
        require(msg.sender == quarterMaster, "Not Quartermaster");
        _;
    }
}