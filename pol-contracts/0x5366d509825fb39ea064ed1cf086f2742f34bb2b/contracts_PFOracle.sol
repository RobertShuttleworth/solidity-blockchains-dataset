// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";
import "./openzeppelin_contracts_token_ERC20_extensions_IERC20Metadata.sol";
import "./openzeppelin_contracts_utils_ReentrancyGuard.sol";
import "./chainlink_contracts_src_v0.8_shared_interfaces_AggregatorV3Interface.sol";
import "./contracts_interfaces_IPoolAddressesProvider.sol";
import "./contracts_interfaces_ILendingPool.sol";
import "./contracts_interfaces_ATokenInterface.sol";
import "./contracts_interfaces_IPoolAddressesProviderRegistry.sol";
import "./contracts_interfaces_IToken.sol";
import "./contracts_interfaces_IKYC.sol";
import "./contracts_interfaces_IDistributionController.sol";
import "./contracts_interfaces_IPFStaking.sol";

contract PFOracle is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Contract interfaces for interacting with other contracts
    IPoolAddressesProviderRegistry public lendingPoolAddressesProviderRegistry;
    IToken public tpftToken;
    IDistributionController public distController;
    IKYC public KYCcontract;
    IPFStaking public stakingContract;
    ATokenInterface public immutable aToken;

    uint256 private constant ADDRESSES_PROVIDER_ID = uint256(0);
    uint16 private constant REFERRAL_CODE = uint16(188);
    int256 public tpftRateforOneDollar = 33333333333333333333;
    address public paymentToken;
    address public timeLock;
    address public multiSig;

    mapping(address manager => bool status) internal managers;
    address[] internal managersList;

    // Modifier restricting access to managers
    modifier onlyManagers() {
        require(
            managers[msg.sender] == true,
            "PFOracle: Not Authorized To Perform This Activiity!"
        );
        _;
    }

    // Modifier restricting access to timelock-controlled functions
    modifier onlyTimelock() {
        require(msg.sender == timeLock, "Not Timelock");
        _;
    }

    // Modifier restricting access to multisig-controlled functions
    modifier onlyMultiSig() {
        require(msg.sender == multiSig, "Not MultiSig");
        _;
    }

    // Modifier to check zero address
    modifier zeroAddressCheck(address param) {
        require(param != address(0), "PFO: Zero");
        _;
    }

    constructor(
        address _tpftToken,
        address dcController,
        IKYC _kyc,
        ATokenInterface _aToken,
        address _timeLock,
        IPoolAddressesProviderRegistry _Registry,
        address _paymentToken,
        address _multiSig
    ) {
        tpftToken = IToken(_tpftToken);
        distController = IDistributionController(dcController);
        KYCcontract = _kyc;
        aToken = _aToken;
        timeLock = _timeLock;
        lendingPoolAddressesProviderRegistry = _Registry;
        paymentToken = _paymentToken;
        multiSig = _multiSig;
    }

    // @notice Returns the list of managers
    // @return The array of managers
    function getManagers() external view returns (address[] memory) {
        return managersList;
    }

    // @notice Returns the status of manager address
    // @return True if a manager False if not
    function getManagerStatus(
        address _managerAddress
    ) external view returns (bool) {
        return managers[_managerAddress];
    }

    // @notice Returns the TGEFlag status
    // @return True of False for TGEFlag
    function getTGEFlag() external view returns (bool) {
        return distController.TGEFlag();
    }

    // @notice Returns the KYC status for a user
    // @return True if kyc is done False if not
    function getKycStatusOfUser(address _user) internal returns (bool) {
        return KYCcontract.getKYCstatus(_user);
    }

    /// @notice Sets the tpftRateforOneDollar
    /// @param rate The new rate for tpftRateforOneDollar
    /// @dev Only callable by super admins
    function setTPFTRateForOneDollar(int256 rate) external onlyMultiSig {
        tpftRateforOneDollar = rate;
    }

    function setdistController(address _distController) external onlyMultiSig {
        distController = IDistributionController(_distController);
    }

    /// @notice Sets the staking contract address
    /// @param _newStakingAddress The address of the new staking contract
    /// @dev Only callable by super admins, checks if the address is non-zero
    function setStakingAddress(
        address _newStakingAddress
    ) external onlyMultiSig zeroAddressCheck(_newStakingAddress) {
        stakingContract = IPFStaking(_newStakingAddress);
    }

    /// @notice Sets the new KYC contract address
    /// @param _newKYCAddress The address of the new KYC contract
    /// @dev Only callable by super admins, checks if the address is non-zero
    function setKYCAddress(
        address _newKYCAddress
    ) external onlyMultiSig zeroAddressCheck(_newKYCAddress) {
        KYCcontract = IKYC(_newKYCAddress);
    }

    /// @notice Sets the new MultiSig contract address
    /// @param _newMultiSigAddress The address of the new MultiSig contract
    function setMultiSigAddress(
        address _newMultiSigAddress
    ) external onlyTimelock zeroAddressCheck(_newMultiSigAddress) {
        multiSig = _newMultiSigAddress;
    }

    /// @notice Sets the new Timelock contract address
    /// @param _newTimelockAddress The address of the new Timelock contract
    function setTimelockAddress(
        address _newTimelockAddress
    ) external onlyTimelock zeroAddressCheck(_newTimelockAddress) {
        timeLock = _newTimelockAddress;
    }

    // @notice add manager to list of managers
    // @param managerAddress address of manager to add
    function addManager(
        address managerAddress
    ) external onlyMultiSig zeroAddressCheck(managerAddress) {
        if (managers[managerAddress] == false) {
            managersList.push(managerAddress);
        }
        managers[managerAddress] = true;
    }

    // @notice removes manager from list of managers
    // @param managerAddress address of manager to remove
    function removeManager(
        address managerAddress
    ) external onlyMultiSig zeroAddressCheck(managerAddress) {
        managers[managerAddress] = false;
    }

    // @notice Fills the TPFT amount for the distributionID
    // @param _amount the TPFT amount to be filled
    // @param distributionId the id of distribution to fill
    function distributionAmountFill(
        uint256 _amount,
        uint256 distributionId
    ) external onlyManagers {
        distController.updateAmountFilled(distributionId, _amount);
    }

    // @notice decrease the filled TPFT amount for the distributionID
    // @param _amount the TPFT amount to be decreased
    // @param distributionId the id of distribution to descrease
    function distributionAmountDec(
        uint256 _amount,
        uint256 distributionId
    ) external onlyManagers {
        distController.decAmountFilled(distributionId, _amount);
    }

    /// @notice Calculates the TPFT amount based on ERC20 token amount
    /// @param amount The amount of the ERC20 token
    /// @return The equivalent TPFT amount
    function calculateTPFTAmountViaERC20(
        address token,
        address oracle,
        uint256 amount
    ) external view returns (int256) {
        int tokeninUSD = convertTokentoUSD(amount, oracle);

        int _tpftAmount = tokeninUSD * tpftRateforOneDollar;
        uint multiplier = 10 ** IERC20Metadata(token).decimals();
        return _tpftAmount / int(multiplier);
    }

    /// @notice Converts the token amount to USD value
    /// @param _quantity The quantity of the token
    /// @return The equivalent USD value
    /// @dev Uses an oracle to fetch the latest price
    function convertTokentoUSD(
        uint256 _quantity,
        address oracle
    ) public view returns (int) {
        AggregatorV3Interface dataFeed = AggregatorV3Interface(oracle);
        (, int answer, , , ) = dataFeed.latestRoundData();
        uint256 multiplier = uint(10 ** dataFeed.decimals());
        return (answer * int(_quantity)) / int(multiplier);
    }

    /// @notice Validates distributor data for rewards
    /// @param _amount The amount for reward calculation
    /// @dev Ensures the reward amount does not exceed the distribution limit
    function validateDistributorData(
        uint256 _amount,
        uint256 distributionId
    ) external view {
        (
            ,
            uint256 rate,
            uint256 amountFilled,
            uint256 multiplier
        ) = distController.getDistributionData(distributionId);
        uint256 amountForRewards = ((tpftToken.getTotalSupplyCap()) * (rate)) /
            (multiplier * 100);
        require((amountForRewards >= (_amount + amountFilled)), "PFO:10");
    }

    /// @notice Checks the KYC for a user if not done the approves
    /// @param _user The address to check KYC for
    /// @param expiresAt Time Limit till the dataHash is valid
    /// @param dataHash for approving the KYC
    function kycCheck(
        address _user,
        uint256 expiresAt,
        bytes32 dataHash
    ) external onlyManagers {
        bool kycStatus = getKycStatusOfUser(_user);
        if (!kycStatus) {
            KYCcontract.validateKYC(_user, expiresAt, dataHash);
            kycStatus = getKycStatusOfUser(_user);
        }
        require(kycStatus, "PFO:KYC");
    }

    /// @notice Validates the condition for staking
    /// @param _goalAmt The goal amount of a campaign
    /// @param stakingPercent minPercent of the goalAmount that should be staked
    /// @param creator address of the campaign creator
    function validateStakingCondition(
        uint256 _goalAmt,
        uint256 stakingPercent,
        address creator
    ) external view {
        uint256 stakedAmount = (_goalAmt * stakingPercent) / 100;
        require(
            stakingContract.checkStakedBalance(creator) >= stakedAmount,
            "PFO:05"
        );
    }

    /// @notice Gets the total Aave rewards available
    /// @return uint256 The total Aave rewards available
    /// @dev Calculates the total Aave rewards by subtracting the scaled balance from the actual balance
    function getAaveRewards(address _pfContract) public view returns (uint256) {
        uint256 scaledBalance = aToken.scaledBalanceOf(_pfContract);
        return IERC20(aToken).balanceOf(_pfContract) - scaledBalance;
    }

    /// @notice Deposits tokens to Aave lending pool
    /// @param mintAmount The amount to deposit
    /// @dev Internal function to deposit tokens into Aave lending pool
    function _depositToAave(uint256 mintAmount, address behalfOf) internal {
        _lendingPool().deposit(
            address(paymentToken),
            mintAmount,
            behalfOf,
            REFERRAL_CODE
        );
    }

    /// @notice Sponsors an amount by depositing it to Aave
    /// @param amount The amount to sponsor
    /// @dev Calls the internal function to deposit tokens into Aave lending pool
    function sponsor(uint256 amount, address behalfOf) external onlyManagers {
        _depositToAave(amount, behalfOf);
    }

    /// @notice Redeems tokens from Aave lending pool
    /// @param redeemAmount The amount to redeem
    /// @dev Withdraws the specified amount of tokens from Aave lending pool
    function redeemToken(
        uint256 redeemAmount,
        address behalfOf
    ) external onlyManagers {
        _lendingPool().withdraw(address(paymentToken), redeemAmount, behalfOf);
    }

    /// @notice Returns the Aave lending pool interface
    /// @return ILendingPool The Aave lending pool interface
    /// @dev Gets the Aave lending pool instance using the addresses provider
    function _lendingPool() public view returns (ILendingPool) {
        return
            ILendingPool(
                IPoolAddressesProvider(
                    lendingPoolAddressesProviderRegistry
                        .getAddressesProvidersList()[ADDRESSES_PROVIDER_ID]
                ).getPool()
            );
    }
}