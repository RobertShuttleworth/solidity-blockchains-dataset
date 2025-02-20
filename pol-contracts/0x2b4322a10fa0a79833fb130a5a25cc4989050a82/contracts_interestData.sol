// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import "./contracts_interfaces_IDataHub.sol";
import "./contracts_interfaces_IDepositVault.sol";
import "./contracts_interfaces_IExecutor.sol";
import "./contracts_interfaces_IUtilityContract.sol";
import "./contracts_libraries_EVO_LIBRARY.sol";
import "./contracts_interfaces_IStorkOracle.sol";

contract interestData {
    uint256 internal constant SECONDS_PER_YEAR = 365 days;
    uint256 internal constant RAY = 1e27;
    uint256 internal constant HALF_RAY = 0.5e27;

    /// @notice Keeps track of contract admins
    mapping(address => bool) public admins;

    IDataHub public Datahub;
    IDepositVault public DepositVault;
    IExecutor public Executor;
    IUtilityContract public utils;

    address public owner;

    IStorkOracle public storkOracle;

    event StorkOracleError(
        address indexed sender,
        bytes32 token,
        uint256 timestamp
    );

    modifier checkRoleAuthority() {
        require(admins[msg.sender] == true, "Unauthorized");
        _;
    }

    event LendingPoolDeposit(
        address user,
        string chainId,
        string assetAddress,
        uint256 amount
    );

    event LendingPoolWithdrawal(
        address sender,
        string chainId,
        string assetAddress,
        uint256 amount
    );

    constructor(
        address initialOwner,
        address _executor,
        address _dh,
        address _utils,
        address _dv,
        address _stork_oracle
    ) {
        owner = initialOwner;
        admins[initialOwner] = true;
        admins[address(this)] = true;
        admins[_executor] = true;
        Executor = IExecutor(_executor);
        admins[_dh] = true;
        Datahub = IDataHub(_dh);
        admins[_utils] = true;
        utils = IUtilityContract(_utils);
        admins[_dv] = true;
        DepositVault = IDepositVault(_dv);
        storkOracle = IStorkOracle(_stork_oracle);
    }

    function alterAdminRoles(
        address _dh,
        address _executor,
        address _dv,
        address _utils,
        address _stork_oracle
    ) public checkRoleAuthority {
        require(msg.sender == owner, " you cannot perform this action");

        admins[address(Datahub)] = false;
        admins[_dh] = true;
        Datahub = IDataHub(_dh);

        admins[address(Executor)] = false;
        admins[_executor] = true;
        Executor = IExecutor(_executor);

        delete admins[_dv];
        admins[_dv] = true;

        admins[address(utils)] = false;
        admins[_utils] = true;
        utils = IUtilityContract(_utils);
        storkOracle = IStorkOracle(_stork_oracle);
    }

    /// @notice Sets a new Admin role
    function setAdminRole(address _admin) external checkRoleAuthority {
        require(msg.sender == owner, " you cannot perform this action");
        admins[_admin] = true;
    }

    /// @notice Revokes the Admin role of the contract
    function revokeAdminRole(address _admin) external checkRoleAuthority {
        require(msg.sender == owner, " you cannot perform this action");
        admins[_admin] = false;
    }

    function transferOwnership(address _owner) public {
        require(msg.sender == owner, " you cannot perform this action");
        owner = _owner;
    }

    function rayMul(uint256 a, uint256 b) internal pure returns (uint256 c) {
        // to avoid overflow, a <= (type(uint256).max - HALF_RAY) / b
        assembly {
            if iszero(
                or(iszero(b), iszero(gt(a, div(sub(not(0), HALF_RAY), b))))
            ) {
                revert(0, 0)
            }

            c := div(add(mul(a, b), HALF_RAY), RAY)
        }
    }

    /**
     * @dev Function to calculate the interest using a compounded interest rate formula
     * To avoid expensive exponentiation, the calculation is performed using a binomial approximation:
     *
     *  (1+x)^n = 1+n*x+[n/2*(n-1)]*x^2+[n/6*(n-1)*(n-2)*x^3...
     *
     * The approximation slightly underpays liquidity providers and undercharges borrowers, with the advantage of great
     * gas cost reductions.
     *
     * @param rate The interest rate
     * @param lastUpdateTimestamp The timestamp of the last update of the interest
     * @return The interest rate compounded during the timeDelta
     */
    function calculateCompoundedInterest(
        uint256 rate, // decimal 18     0.1e18 = 10%
        uint256 lastUpdateTimestamp,
        uint256 currentTimestamp
    ) internal pure returns (uint256) {
        if (rate == 0) {
            return 1e18;
        }
        uint256 rate_in_ray = rate * 1e9; // Wad(1e18) -> Ray(1e27)
        uint256 exp = currentTimestamp - lastUpdateTimestamp;

        if (exp == 0) {
            return 1e18;
        }

        uint256 expMinusOne;
        uint256 expMinusTwo;
        uint256 basePowerTwo;
        uint256 basePowerThree;
        unchecked {
            expMinusOne = exp - 1;

            expMinusTwo = exp > 2 ? exp - 2 : 0;

            basePowerTwo =
                rayMul(rate_in_ray, rate_in_ray) /
                (SECONDS_PER_YEAR * SECONDS_PER_YEAR);
            basePowerThree =
                rayMul(basePowerTwo, rate_in_ray) /
                SECONDS_PER_YEAR;
        }

        uint256 secondTerm = exp * expMinusOne * basePowerTwo;
        unchecked {
            secondTerm /= 2;
        }
        uint256 thirdTerm = exp * expMinusOne * expMinusTwo * basePowerThree;
        unchecked {
            thirdTerm /= 6;
        }

        uint256 compoundedInterest_in_ray = RAY +
            (rate_in_ray * exp) /
            SECONDS_PER_YEAR +
            secondTerm +
            thirdTerm;
        return compoundedInterest_in_ray / 1e9; // Ray(1e27) to Wad(1e18)
    }

    // NOTE: I think we might want to take out the input for rawLiabillites here and just grab it from the userData
    function calculateInitialManipulatedLiabilities(
        bytes32 token,
        uint256 rawLiabilities
    ) public view returns (uint256) {
        IDataHub.AssetData memory assetLogs = Datahub.returnAssetLogs(token);
        uint256 compoundedInterestMultiplier = assetLogs
            .compoundedInterestMultiplier;

        uint256 initialManipulatedLiabilities = (rawLiabilities * 10 ** 18) /
            compoundedInterestMultiplier;

        return initialManipulatedLiabilities;
    }

    function calculateActualCurrentLiabilities(
        address user,
        bytes32 token
    ) public view returns (uint256) {
        IDataHub.AssetData memory assetLogs = Datahub.returnAssetLogs(token);

        uint256 initialManipulatedLiabilities = Datahub
            .getInitialManipulatedLiabilities(user, token);

        uint256 compoundedInterestMultiplier = assetLogs
            .compoundedInterestMultiplier;

        uint256 actualCurrentLiabilities = (initialManipulatedLiabilities *
            compoundedInterestMultiplier) / 10 ** 18;

        return actualCurrentLiabilities;
    }

    function calculateManipulatedTotalBorrowedAmount(
        bytes32 token,
        uint256 rawTotalBorrowedAmount // I'm not sure if we need to pass this in here or if we should just get it from the asset logs.
    ) public view returns (uint256) {
        IDataHub.AssetData memory assetLogs = Datahub.returnAssetLogs(token);

        uint256 compoundedInterestMultiplier = assetLogs
            .compoundedInterestMultiplier;

        uint256 manipulatedTotalBorrowedAmount = (rawTotalBorrowedAmount *
            10 ** 18) / compoundedInterestMultiplier;

        return manipulatedTotalBorrowedAmount;
    }

    function calculateActualTotalBorrowedAmount(
        bytes32 token
    ) public view returns (uint256) {
        IDataHub.AssetData memory assetLogs = Datahub.returnAssetLogs(token);

        uint256 compoundedInterestMultiplier = assetLogs
            .compoundedInterestMultiplier;

        uint256 actualTotalBorrowedAmount = (assetLogs.assetInfo[3] *
            compoundedInterestMultiplier) / (10 ** 18);

        return actualTotalBorrowedAmount;
    }

    // NOTE: I think we might want to take out the input for rawLendingPoolAssets here and just grab it from the userData
    function calculateInitialManipulatedLendingPoolAssets(
        bytes32 token,
        uint256 rawLendingPoolAssets
    ) public view returns (uint256) {
        IDataHub.AssetData memory assetLogs = Datahub.returnAssetLogs(token);
        uint256 compoundedLendingMultiplier = assetLogs
            .compoundedLendingMultiplier;

        uint256 initialManipulatedLendingPoolAssets = (rawLendingPoolAssets *
            10 ** 18) / compoundedLendingMultiplier;

        return initialManipulatedLendingPoolAssets;
    }

    function calculateActualCurrentLendingPoolAssets(
        address user,
        bytes32 token
    ) public view returns (uint256) {
        IDataHub.AssetData memory assetLogs = Datahub.returnAssetLogs(token);

        uint256 initialManipulatedLendingPoolAssets = Datahub
            .getInitialManipulatedLendingPoolAssets(user, token);

        uint256 compoundedLendingMultiplier = assetLogs
            .compoundedLendingMultiplier;

        uint256 actualCurrentLendingPoolAssets = (initialManipulatedLendingPoolAssets *
                compoundedLendingMultiplier) / 10 ** 18;

        // Compounded lending rate takes the exchange spread into account, no need to subtract it here. - This needs to be tested
        // uint256 actualCurrentLendingPoolAssets = (currentLendingPoolAssets * (1e18 - Datahub.getExchangeInterestSpread()))/1e18;

        return actualCurrentLendingPoolAssets;
    }

    function calculateInitialManipulatedLendingPoolSupply(
        bytes32 token,
        uint256 rawLendingPoolSupply // I'm not sure if we need to pass this in here or if we should just get it from the asset logs.
    ) public view returns (uint256) {
        IDataHub.AssetData memory assetLogs = Datahub.returnAssetLogs(token);

        uint256 compoundedLendingMultiplier = assetLogs
            .compoundedLendingMultiplier;

        uint256 manipulatedLendingPoolSupply = (rawLendingPoolSupply *
            10 ** 18) / compoundedLendingMultiplier;

        return manipulatedLendingPoolSupply;
    }

    function calculateActualTotalLendingPoolSupply(
        bytes32 token
    ) public view returns (uint256) {
        IDataHub.AssetData memory assetLogs = Datahub.returnAssetLogs(token);

        uint256 compoundedLendingMultiplier = assetLogs
            .compoundedLendingMultiplier;

        uint256 actualTotalLendingPoolSupply = (assetLogs.assetInfo[4] *
            compoundedLendingMultiplier) / (10 ** 18);

        return actualTotalLendingPoolSupply;
    }

    // Brings up to date the compoundedInterestMultiplier and totalBorrowedAmount variables
    // Edited to update all lend and borrow variables
    function updateCIMandTBA(bytes32 token) public checkRoleAuthority {
        IDataHub.AssetData memory assetLogs = Datahub.returnAssetLogs(token);
        uint256 interestRate = EVO_LIBRARY.calculateInterestRate(assetLogs);

        uint256 TBP = calculateActualTotalLendingPoolSupply(token) == 0
            ? 0
            : (calculateActualTotalBorrowedAmount(token) * 1e18) /
                calculateActualTotalLendingPoolSupply(token);
        uint256 lendingRate = (interestRate * TBP) / 1e18;

        // ----------- STEP 1: update the CIM and CLM ------------------------

        // calculate what the current compounded lending rates should be
        uint256 compoundedLending = calculateCompoundedInterest(
            lendingRate,
            assetLogs.lastUpdatedLendingTime,
            block.timestamp
        );

        // update our CLM to be up to date with our new compounded lending rate
        // NOTE: let's make sure that compoundedLending here returns the (rate - 1e18) from that function, if not we can just delete that 1e18 from here
        uint256 compoundedLendingMultiplier = (assetLogs
            .compoundedLendingMultiplier *
            (1e18 +
                ((compoundedLending - 1e18) *
                    (1e18 - Datahub.getExchangeInterestSpread())) /
                1e18)) / 1e18;

        Datahub.alterTokenLendingInfo(
            token,
            compoundedLendingMultiplier,
            block.timestamp
        );

        // calculate what the current compounded interest rates should be
        uint256 compoundedInterest = calculateCompoundedInterest(
            interestRate,
            assetLogs.lastUpdatedInterestTime,
            block.timestamp
        );

        // update our CIM to be up to date with our new compounded interest rate
        // NOTE: let's make sure that compoundedInterest here returns the (rate - 1e18) from that function, if not we can just delete that 1e18 from here
        uint256 compoundedInterestMultiplier = (assetLogs
            .compoundedInterestMultiplier * compoundedInterest) / 1e18;

        Datahub.alterTokenInterestInfo(
            token,
            compoundedInterestMultiplier,
            block.timestamp
        );

        // ----------- STEP 2: Bring TBA up to CIM and TLPS up to CLM-----------------------

        // TLPS was last updated the last time we updated CLM, now that we just updated it, we need to update it again

        // Here we calculate what the rawTLPS should be by getting the old manipulatedTLPS and multiplying by the updated CLM
        // NOTE: we need to check if we want to take the ExchangeInterestSpread up top in the lending rate or here
        uint256 rawTotalLendingPoolSupply = ((assetLogs.assetInfo[4] *
            compoundedLendingMultiplier) / 1e18);

        if (rawTotalLendingPoolSupply >= assetLogs.assetInfo[2]) {
            // Here we are updating the rawTotalLendingPoolSupply so that it is up to date with the current CLM
            Datahub.alterRawLendingPoolSupply(token, rawTotalLendingPoolSupply);

            // Here we scale down the manipulatedTotalLendingPoolSupply to the CLM --
            uint256 manipulatedTotalLendingPoolSupply = calculateInitialManipulatedLendingPoolAssets(
                    token,
                    rawTotalLendingPoolSupply
                );

            // update manipulatedTLPS
            Datahub.alterInitialManipulatedLendingPoolSupply(
                token,
                manipulatedTotalLendingPoolSupply
            );
        }

        // TBA was last updated the last time we updated CIM, now that we just updated it, we need to update it again

        // Here we calculate what the rawTBA should be by getting the old manipulatedTBA and multiplying by the updated CIM
        uint256 rawTotalBorrowedAmount = ((assetLogs.assetInfo[3] *
            compoundedInterestMultiplier) / 1e18);

        if (rawTotalBorrowedAmount >= assetLogs.assetInfo[1]) {
            // Here we are updating the rawTotalBorrow so that it is up to date with the current CIM
            Datahub.alterRawTotalBorrowedAmount(token, rawTotalBorrowedAmount);

            // Here we scale down the manipulatedTotalBorrow to the CIM --
            // honestly not sure if we need the above function or a rawTotalBorrow at all
            // since it seems like we're just dividing and then multiplying by the same number - we're keeping it just in case though
            uint256 manipulatedTotalBorrowedAmount = calculateManipulatedTotalBorrowedAmount(
                    token,
                    rawTotalBorrowedAmount
                );
            // update manipulatedTBA
            Datahub.alterManipulatedTotalBorrowedAmount(
                token,
                manipulatedTotalBorrowedAmount
            );
        }
    }

    function simulateCIMandTBA(
        bytes32 token
    ) public view returns (uint256, uint256, uint256, uint256) {
        IDataHub.AssetData memory assetLogs = Datahub.returnAssetLogs(token);
        uint256 interestRate = EVO_LIBRARY.calculateInterestRate(assetLogs);

        uint256 TBP = calculateActualTotalLendingPoolSupply(token) == 0
            ? 0
            : (calculateActualTotalBorrowedAmount(token) * 1e18) /
                calculateActualTotalLendingPoolSupply(token);
        uint256 lendingRate = (interestRate * TBP) / 1e18;

        // ----------- STEP 1: update the CIM and CLM ------------------------

        // calculate what the current compounded lending rates should be
        uint256 compoundedLending = calculateCompoundedInterest(
            lendingRate,
            assetLogs.lastUpdatedLendingTime,
            block.timestamp
        );

        // update our CLM to be up to date with our new compounded lending rate
        // NOTE: let's make sure that compoundedLending here returns the (rate - 1e18) from that function, if not we can just delete that 1e18 from here
        uint256 compoundedLendingMultiplier = (assetLogs
            .compoundedLendingMultiplier *
            (1e18 +
                ((compoundedLending - 1e18) *
                    (1e18 - Datahub.getExchangeInterestSpread())) /
                1e18)) / 1e18;

        // calculate what the current compounded interest rates should be
        uint256 compoundedInterest = calculateCompoundedInterest(
            interestRate,
            assetLogs.lastUpdatedInterestTime,
            block.timestamp
        );

        // update our CIM to be up to date with our new compounded interest rate
        // NOTE: let's make sure that compoundedInterest here returns the (rate - 1e18) from that function, if not we can just delete that 1e18 from here
        uint256 compoundedInterestMultiplier = (assetLogs
            .compoundedInterestMultiplier * compoundedInterest) / 1e18;

        // ----------- STEP 2: Bring TBA up to CIM and TLPS up to CLM-----------------------

        // TLPS was last updated the last time we updated CLM, now that we just updated it, we need to update it again

        // Here we calculate what the rawTLPS should be by getting the old manipulatedTLPS and multiplying by the updated CLM
        // NOTE: we need to check if we want to take the ExchangeInterestSpread up top in the lending rate or here
        uint256 rawTotalLendingPoolSupply = ((assetLogs.assetInfo[4] *
            compoundedLendingMultiplier) / 1e18);

        // Here we calculate what the rawTBA should be by getting the old manipulatedTBA and multiplying by the updated CIM
        uint256 rawTotalBorrowedAmount = ((assetLogs.assetInfo[3] *
            compoundedInterestMultiplier) / 1e18);

        return (
            compoundedLendingMultiplier,
            rawTotalLendingPoolSupply,
            compoundedInterestMultiplier,
            rawTotalBorrowedAmount
        );
    }

    function returnInterestCharge(
        address user,
        bytes32 token
    ) public view returns (uint256) {
        uint256 rawLiabilities = Datahub.getRawLiabilities(user, token);
        uint256 actualCurrentLiabilities = calculateActualCurrentLiabilities(
            user,
            token
        );
        uint256 interestCharge = actualCurrentLiabilities - rawLiabilities;
        return interestCharge;
    }

    // This function returns the interest earnings of a user's asset in the lending pool taking into account the exchange's spread
    function returnLendingPoolAssetInterestEarnings(
        address user,
        bytes32 token
    ) public view returns (uint256) {
        uint256 rawLendingPoolAssets = Datahub.getRawLendingPoolAssets(
            user,
            token
        );
        uint256 actualCurrentLendingPoolAssets = calculateActualCurrentLendingPoolAssets(
                user,
                token
            );
        uint256 lendingPoolAssetInterestEarnings = actualCurrentLendingPoolAssets -
                rawLendingPoolAssets;
        return lendingPoolAssetInterestEarnings;
    }

    // NOTE: THIS FUNCTION CANNOT BE PUBLIC!!! I CHANGED IT TO checkRoleAuthority IM NOT SURE IF THATS RIGHT
    // @notice This will charge interest to a user if they are accuring new liabilities
    // @param user the address of the user beign confirmed
    // @param token the token being targetted
    // @param liabilitiesAccrued the new liabilities being issued
    // @param minus determines if we are adding to the liability pool or subtracting
    function updateLiabilities(
        address user,
        bytes32 token,
        uint256 liabilityInflowOutflow,
        bool minus
    ) public checkRoleAuthority {
        IDataHub.AssetData memory assetLogs = Datahub.returnAssetLogs(token);
        // uint256 interestRate = EVO_LIBRARY.calculateInterestRate(assetLogs); // we need to pass in actualTBA (manipulatedTBA) * CIM in here? -- NO, the asset logs have this and the interest rate formula gets it itself
        // uint256 lastUpdatedTimeStamp = assetLogs.lastUpdatedInterestTime;

        // Steps 1 and 2 have been consolidated into this function in the Interest Contract
        // Here we are just bringing the CIM and the TBA up to date
        // WE WILL PROBABLY WANT TO TAKE THIS OUT OF HERE AND CALL IT INDEPENDENTLY SINCE THIS FUNCTION WILL BE CALLED PRIOR TO
        // PUTTING THIS IN HERE ON EVERY FUNCTION WE WOULD USE IT
        // interestContract.updateCIMandTBA(token); // Need to delete this after all other functions that call this function have this prior to calling this function

        // ----------- Charge users interest on outstanding liabilities -----------------------
        // This is because the functions in the if/else statements will make their "returnInterestCharge" = 0 since we are updating
        // their raw and manipulated liabilities numbers, which will equal the same number when updated
        // What we basically do here is attribute the spread fees for the exchange for the interest they have accumulated up until this point
        // In a more detailed manner, since their liabilities increase over time, their interest is already technically charged as they
        // accumulate more liabilities via interest. For holders of assets in the lending pool, we give them this interest by seeing
        // what they have in the lending pool and compounding that, however since the exchange does not have assets in the lending
        // pool, we need to add the spread that it makes directly to their assets whenever borrowers interact with this function

        // return what the current outstanding liabilities are for the user, taking compounding into account
        uint256 actualCurrentLiabilities = calculateActualCurrentLiabilities(
            user,
            token
        );

        // return what their total interest payment is out of those total liabilities
        // uint256 interestCharge = interestContract.returnInterestCharge(
        //     user,
        //     token
        // );
        // Here we determine what allocation of those interest payments belongs to the exchange and update the exchange's assets with them
        // uint256 exchangeInterestSpread = Datahub.getExchangeInterestSpread();
        // uint256 fee = (interestCharge * exchangeInterestSpread) / 10 ** 18;
        // divideFee(token, fee);
        Executor.divideFee(
            token,
            (returnInterestCharge(user, token) *
                Datahub.getExchangeInterestSpread()) / 10 ** 18
        );

        // This if statement handles cases when users are adding to their liabilities (i.e. when borrowing)
        if (!minus) {
            // Before even getting into these steps, we need to update our TBA mapping, we need to include a rawTBA and manipulatedTBA
            //  NOTE I just added it to the datahub mapping under assetData assetinfo[3] = manipulatedTBA
            //  we will calculate manipulatedTBA the same way we calculate initialmanipulatedLiabilities for users
            //  Already put this function into the interestData contract as well as the alterManipulatedTotalBorrowedAmount function in the datahub

            // ANOTHER NOTE - We can probably delete the chargeMassInterest function after this

            // ANOTHER NOTE - We might want to put a large part of this functionality above this if statement
            // because it likely pertains to both parts of this function

            // Step 1: Need to update the CIM (compoundedInterestMultiplier) - Need to implement the function I tagged in Slack that Aave uses,
            //         it's very similar to our compound function that Wakaki implemented,
            //         **for actualTBA to use in that function we'll use manipulatedTBA * CIM (? TBD)
            // Step 2: We bring TBA up to CIM - Using the function I already added
            // Step 3: add inflow/outflow to user's raw liabilities and calculate manipulated liabilities with old CIM
            // Step 4: Add liabilityInflowOutflow to manipulatedTBA and recalculate TBA (this is the rawLiabilities value the user is getting added to his account)
            // Step 5: Then we need to re-calculateInterestRate with our new TBA
            // Step 6: Then we need to update the compoundedInterestMultiplier

            // DONT THINK WE NEED THE BELOW, SHOULD ALL BE TAKEN INTO ACCOUNT WITH THE ABOVE
            // ---Then we need to do the interestChargeForNewLiabilities and add it into totalLiabilities ??
            // ---Do we need to add in the interestChargeForNewLiabilities into TBA?
            // ---Then we set new rawLiabilities

            // ----------- STEPS 1 AND 2 DONE ABOVE IF STATEMENT --------------------------------------
            // ----------- STEP 3: Add inflow/outflow to user's raw liabilities -----------------------

            // This step sets the users liabilities to include the new liabilities we are adding
            // We set it to the TBA/CIM that does not include these liabilities so that when we
            // recalculate CIM with them the interest for these liabilities is taken into account

            // Add initial margin fee to liabilities and distribute to exchange
            uint256 initialMarginFee = EVO_LIBRARY
                .calculateinitialMarginFeeAmount(
                    Datahub.returnAssetLogs(token),
                    liabilityInflowOutflow
                );
            liabilityInflowOutflow = liabilityInflowOutflow + initialMarginFee;

            Executor.divideFee(token, initialMarginFee);

            uint256 totalLiabilities = actualCurrentLiabilities +
                liabilityInflowOutflow;

            Datahub.alterRawLiabilities(user, token, totalLiabilities);

            uint256 initialManipulatedLiabilities = calculateInitialManipulatedLiabilities(
                    token,
                    totalLiabilities
                );
            Datahub.alterInitialManipulatedLiabilities(
                user,
                token,
                initialManipulatedLiabilities
            );

            // ----------- STEP 4: Add liabilityInflowOutflow to TBA and recalculate TBA -----------------------

            // TBA was last updated at the top of this function, now that we just added liabilities, we need to update it again
            // To get this rawTBA we can either do this function that we have below or just call it from the datahub
            // since it was just updated - Leaving it like this for uniformity

            uint256 rawTotalBorrowedAmount = assetLogs.assetInfo[1] +
                liabilityInflowOutflow;

            // Here we are updating the rawTotalBorrow so that it is up to date with the current CIM
            Datahub.alterRawTotalBorrowedAmount(token, rawTotalBorrowedAmount);

            // Here we scale down the manipulatedTotalBorrow to the CIM
            uint256 manipulatedTotalBorrowedAmount = calculateManipulatedTotalBorrowedAmount(
                    token,
                    rawTotalBorrowedAmount
                );

            Datahub.alterManipulatedTotalBorrowedAmount(
                token,
                manipulatedTotalBorrowedAmount
            );

            //ADDED PLEASE REVISE
            require(
                rawTotalBorrowedAmount <=
                    calculateActualTotalLendingPoolSupply(token),
                "Borrow amount larger than available lending pool"
            );

            Datahub.updateUserLiabilitiesTokens(user, token);
            require(
                Datahub.calculateAIMRForUser(user) <=
                    Datahub.calculateCollateralValue(user),
                "Collateral insufficient for this position"
            );

            // IM NOT SURE IF WE WANT TO ADD A REQUIRE STATEMENT HERE TO MAKE SURE THAT NEW TBA < LENDINGPOOLSUPPLY

            // ----------- STEP 5: Recalculate Interest Rate with our new TBA -----------------------

            // TOOK THIS OUT FOR THIS REASON BELOW
            // Interest is automatically calculated based on TBA/TBP - we don't need to do this anymore because next time this
            // function runs it will use the updated TBA from above to do the compounding which is done at the start of this
            // function above the if statement

            // uint256 interestRate = EVO_LIBRARY.calculateInterestRate( // we need to pass in actualTBA (manipulatedTBA) * CIM in here?
            //        0,
            //        assetLogs
            //    );

            // ----------- STEP 6: Recalculate CIM with our new Interest Rate -----------------------

            // I DONT THINK WE NEED TO COMPOUND HERE - MIGHT WANT TO DELETE THIS AND REPLACE WITH REGULAR INTEREST FUNCTION

            // TOOK OUT FUNCTIONS BELOW BECAUSE:
            // By updating the TBA above - taking into account that the last interest change pushed was when this function
            // was run at the beginning - the next time the compoundedInterest function runs it will use the interest rate
            // of the updated TBA. Which in turn compounds it from that value, not the old value, and in turn updates the
            // CIM to what it's appropriate compounded value should be

            // uint256 compoundedInterest = interestContract
            //    .calculateCompoundedInterest(
            //        interestRate,
            //        lastUpdatedTimeStamp,
            //        block.timestamp
            //    );

            // NO BECAUSE OF REASON ABOVE
            // update our CIM to be up to date with our new compounded interest rate
            // uint256 compoundedInterestMultiplier = (assetLogs
            //    .compoundedInterestMultiplier * compoundedInterest) /
            //    1e18;

            // Datahub.alterTokenInterestInfo(
            //    token,
            //    compoundedInterestMultiplier,
            //    block.timestamp
            // );

            // TOOK THIS OUT BECAUSE WE ARE CHARGING FOR INTEREST BY THE SECOND VIA COMPOUNDEDINTERESTMULTIPLIER NOW

            //    uint256 interestChargeForNewLiabilities = (liabilityInflowOutflow *
            //       (1 + interestRate / 8760)) / 10 ** 18;

            // TOOK THIS OUT BECAUSE TBA IS CALCULATED VIA CIM NOW

            // Datahub.setAssetInfo(
            //    1, // 1 -> totalBorrowedAmount
            //    token,
            //    liabilityInflowOutflow + interestChargeForNewLiabilities,
            //    true
            // );
        } else {
            // This else statement should probably be a copy of the if-statement above except we take away liabilities instead of add to them

            // ----------- STEPS 1 AND 2 DONE ABOVE IF STATEMENT --------------------------------------

            // ----------- STEP 3: Subtract inflow/outflow to user's raw liabilities -----------------------

            // This step sets the users liabilities to subtract the liabilities that we are paying off
            // We set it to the TBA/CIM that does include these liabilities so that when we
            // recalculate CIM without them the interest without these liabilities is taken into account

            uint256 totalLiabilities = actualCurrentLiabilities -
                liabilityInflowOutflow;

            Datahub.alterRawLiabilities(user, token, totalLiabilities);

            uint256 initialManipulatedLiabilities = calculateInitialManipulatedLiabilities(
                    token,
                    totalLiabilities
                );
            Datahub.alterInitialManipulatedLiabilities(
                user,
                token,
                initialManipulatedLiabilities
            );

            // ----------- STEP 4: Add liabilityInflowOutflow to manipulatedTBA and recalculate TBA -----------------------

            // TBA was last updated the last time we updated CIM, now that we just updated it, we need to update it again

            // uint256 rawTotalBorrowedAmount = ((assetLogs.assetInfo[3] *
            //     assetLogs.compoundedInterestMultiplier) / 1e18) -
            //     liabilityInflowOutflow;
            uint256 rawTotalBorrowedAmount = assetLogs.assetInfo[1] -
                liabilityInflowOutflow;

            // Here we are updating the rawTotalBorrow so that it is up to date with the current CIM
            Datahub.alterRawTotalBorrowedAmount(token, rawTotalBorrowedAmount);

            // Here we scale down the manipulatedTotalBorrow to the CIM --
            // honestly not sure if we need the above function or a rawTotalBorrow at all
            // since it seems like we're just dividing and then multiplying by the same number, can look into it later
            uint256 manipulatedTotalBorrowedAmount = calculateManipulatedTotalBorrowedAmount(
                    token,
                    rawTotalBorrowedAmount
                );

            Datahub.alterManipulatedTotalBorrowedAmount(
                token,
                manipulatedTotalBorrowedAmount
            );

            Datahub.updateUserLiabilitiesTokens(user, token);

            // ----------- STEP 5: Recalculate Interest Rate with our new TBA -----------------------

            // TOOK THIS OUT FOR THIS REASON BELOW
            // Interest is automatically calculated based on TBA/TBP - we don't need to do this anymore because next time this
            // function runs it will use the updated TBA from above to do the compounding which is done at the start of this
            // function above the if statement

            // uint256 interestRate = EVO_LIBRARY.calculateInterestRate( // we need to pass in actualTBA (manipulatedTBA) * CIM in here?
            //        0,
            //        assetLogs
            //    );

            // ----------- STEP 6: Recalculate CIM with our new Interest Rate -----------------------

            // TOOK OUT FUNCTIONS BELOW BECAUSE:
            // By updating the TBA above - taking into account that the last interest change pushed was when this function
            // was run at the beginning - the next time the compoundedInterest function runs it will use the interest rate
            // of the updated TBA. Which in turn compounds it from that value, not the old value, and in turn updates the
            // CIM to what it's appropriate compounded value should be

            // I DONT THINK WE NEED TO COMPOUND HERE - MIGHT WANT TO DELETE THIS AND REPLACE WITH REGULAR INTEREST FUNCTION
            // uint256 compoundedInterest = interestContract
            //    .calculateCompoundedInterest(
            //        interestRate,
            //        lastUpdatedTimeStamp,
            //        block.timestamp
            //    );

            // update our CIM to be up to date with our new compounded interest rate
            // uint256 compoundedInterestMultiplier = (assetLogs
            //    .compoundedInterestMultiplier * compoundedInterest) /
            //    1e18;

            // Datahub.alterTokenInterestInfo(
            //    token,
            //    compoundedInterestMultiplier,
            //    block.timestamp
            // );

            // require(
            //     liabilityInflowOutflow <= actualCurrentLiabilities,
            //     "Invalid liabilityInflowOutflow"
            // );

            // uint256 updatedLiabilities = actualCurrentLiabilities -
            //     liabilityInflowOutflow;
            // Datahub.alterRawLiabilities(user, token, updatedLiabilities);

            // uint256 initialManipulatedLiabilities = interestContract
            //     .calculateInitialManipulatedLiabilities(
            //         token,
            //         updatedLiabilities
            //     );
            // Datahub.alterInitialManipulatedLiabilities(
            //     user,
            //     token,
            //     initialManipulatedLiabilities
            // );

            // Datahub.setAssetInfo(1, token, liabilityInflowOutflow, false); // 1 -> totalBorrowedAmount
        }

        Datahub.changeMarginStatus(user);
    }

    /// @notice This function is used to deposit and withdraw from the lendingPool
    /// @dev The updateCIMandTBA function should always be run before this function
    /// @param token the token being targetted
    function updateLendingPoolAssets(
        // NOTE: I THINK THIS NEEDS TO BE CHANGED TO MSG.SENDER FOR SAFETY PLEASE CONFIRM!!!!!
        // address user,
        bytes32 token,
        uint256 amount,
        bool direction
    ) public {
        updateCIMandTBA(token); //This function is called independently so we need this here
        IDataHub.AssetData memory assetLogs = Datahub.returnAssetLogs(token);

        if (direction) {
            // Deposit into lending pool
            // lending pool supply

            require(
                assetLogs.collateralMultiplier > 0,
                "This token cannot be deposited into the lending pool"
            );

            require(
                Datahub.ReadUserData(msg.sender, token).assets >= amount,
                "Insufficient funds"
            );

            // ------------- Step 1: Decrease User's Assets and Increase User's Lending Pool Assets ------------------

            // NOTE PLEASE CHECK IF THIS FUNCTION IS OK TO USE HERE.
            // This was here before, I believe it still works with this usecase? - it should take tokens out of user's assets and conduct safety checks for doing so
            // WE NEED TO MODIFY THIS BECAUSE IT CHANGES THE EXCHANGE TOTAL SUPPLY, WE SHOULD NOT BE ALTERING SUPPLY IN THESE FUNCTIONS
            // TOTAL SUPPLY NEEDS TO REMAIN THE SAME WHEN RUNNING THESE FUNCTIONS BECAUSE THEY JUST MEASURE THE AMOUNT OF TOKENS IN THE EXCHANGE

            // Made new function in the deposit vault to handle the above notes
            DepositVault.lendingPoolDepositProcess(msg.sender, token, amount);

            // From here down we mirror the updateLiabilities function
            uint256 totalLendingPoolAssets = calculateActualCurrentLendingPoolAssets(
                    msg.sender,
                    token
                ) + amount;

            Datahub.alterRawLendingPoolAssets(
                msg.sender,
                token,
                totalLendingPoolAssets
            );

            uint256 initialManipulatedLendingPoolAssets = calculateInitialManipulatedLendingPoolAssets(
                    token,
                    totalLendingPoolAssets
                );
            Datahub.alterInitialManipulatedLendingPoolAssets(
                msg.sender,
                token,
                initialManipulatedLendingPoolAssets
            );

            // ------------- Step 2: Update Lending Pool Supply ------------------

            uint256 rawTotalLendingPoolSupply = ((assetLogs.assetInfo[4] *
                assetLogs.compoundedLendingMultiplier) / 1e18) + amount;

            // Here we are updating the rawTotalBorrow so that it is up to date with the current CIM
            Datahub.alterRawLendingPoolSupply(token, rawTotalLendingPoolSupply);

            // Here we scale down the manipulatedTotalBorrow to the CIM
            uint256 manipulatedTotalLendingPoolSupply = calculateInitialManipulatedLendingPoolSupply(
                    token,
                    rawTotalLendingPoolSupply
                );

            Datahub.alterInitialManipulatedLendingPoolSupply(
                token,
                manipulatedTotalLendingPoolSupply
            );

            //ADDED PLEASE REVISE
            uint256 actualTotalLendingPoolSupply = calculateActualTotalLendingPoolSupply(
                    token
                );

            // REMOVED: Removed because this part of the function is to deposit into the lending pool, if anything we want to be able to do so if the borrow amounts are high, this is probably good for below
            // require(
            //     assetLogs.assetInfo[1] <= //rawTotalBorrowedAmount
            //         actualTotalLendingPoolSupply -
            //             interestContract.calculateActualTotalBorrowedAmount(
            //                 token
            //             ),
            //     "Borrow amount larger than available lending pool"
            // ); // This require makes sure that the borrow does not exceed the lending pool supply
            require(
                Datahub.calculateAIMRForUser(msg.sender) <=
                    Datahub.calculateCollateralValue(msg.sender),
                "This deposit would bring your collateral value below your AIMR"
            );

            require(
                actualTotalLendingPoolSupply <=
                    (assetLogs.assetInfo[0] * (95 * 1e16)) / 1e18,
                "Amount too high"
            ); // 0 -> totalSupply - This require makes sure that there can't be more tokens deposited into the lending pool than there is supply on the exchange.

            emit LendingPoolDeposit(
                msg.sender,
                assetLogs.chainId,
                assetLogs.assetAddress,
                amount
            );
        } else {
            // withdraw

            require(
                calculateActualCurrentLendingPoolAssets(msg.sender, token) >=
                    amount,
                "You do not have enough assets in the lending pool for this withdrawal"
            );
            // START OF MIRRORED LOGIC

            // ------------- Step 1: Decrease User's Lending Pool Assets ------------------

            uint256 totalLendingPoolAssets = calculateActualCurrentLendingPoolAssets(
                    msg.sender,
                    token
                ) - amount;

            Datahub.alterRawLendingPoolAssets(
                msg.sender,
                token,
                totalLendingPoolAssets
            );

            uint256 initialManipulatedLendingPoolAssets = calculateInitialManipulatedLendingPoolAssets(
                    token,
                    totalLendingPoolAssets
                );
            Datahub.alterInitialManipulatedLendingPoolAssets(
                msg.sender,
                token,
                initialManipulatedLendingPoolAssets
            );

            // ------------- Step 2: Update Lending Pool Supply ------------------

            uint256 rawTotalLendingPoolSupply = ((assetLogs.assetInfo[4] *
                assetLogs.compoundedLendingMultiplier) / 1e18) - amount;

            // Here we are updating the rawTotalBorrow so that it is up to date with the current CIM
            Datahub.alterRawLendingPoolSupply(token, rawTotalLendingPoolSupply);

            // Here we scale down the manipulatedTotalBorrow to the CIM
            uint256 manipulatedTotalLendingPoolSupply = calculateInitialManipulatedLendingPoolSupply(
                    token,
                    rawTotalLendingPoolSupply
                );

            Datahub.alterInitialManipulatedLendingPoolSupply(
                token,
                manipulatedTotalLendingPoolSupply
            );

            // ------------- Step 3: Increase User's Assets --------------------
            // THIS IS WHERE WE ADD TO USER'S ASSETS
            // WE NEED TO MODIFY THIS BECAUSE IT CHANGES THE EXCHANGE TOTAL SUPPLY, WE SHOULD NOT BE ALTERING SUPPLY IN THESE FUNCTIONS
            // TOTAL SUPPLY NEEDS TO REMAIN THE SAME WHEN RUNNING THESE FUNCTIONS BECAUSE THEY JUST MEASURE THE AMOUNT OF TOKENS IN THE EXCHANGE
            DepositVault.lendingPoolWithdrawalProcess(
                msg.sender,
                token,
                amount
            );

            require(
                assetLogs.assetInfo[1] <= rawTotalLendingPoolSupply, //rawTotalBorrowedAmount
                "This withdrawal would cause the borrow amount to be greater than the lending pool supply"
            ); // This require makes sure that the borrow does not exceed the lending pool supply

            emit LendingPoolWithdrawal(
                msg.sender,
                assetLogs.chainId,
                assetLogs.assetAddress,
                amount
            );
        }

        Datahub.changeMarginStatus(msg.sender);
    }

    function getStorkOraclePrice(
        bytes32 _token
    ) external view returns (uint256) {
        IDataHub.AssetData memory token_assetlogs = Datahub.returnAssetLogs(
            _token
        );
        try storkOracle.readDataFeed(_token) returns (int224 value) {
            return uint256(uint224(value));
        } catch {
            return token_assetlogs.assetPrice;
        }
    }

    //audit fix bug ID 11 09/05, we have  taken the checkRoleAuthority instade of onlyowner
    function withdrawAll(
        address payable contract_owner
    ) external checkRoleAuthority {
        uint contractBalance = address(this).balance;
        require(contractBalance > 0, "No balance to withdraw");
        payable(contract_owner).transfer(contractBalance);
    }

    receive() external payable {}
}