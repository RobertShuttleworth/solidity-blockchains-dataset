// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import "./contracts_interfaces_IDataHub.sol";
import "./contracts_interfaces_IInterestData.sol";

library EVO_LIBRARY {
    function createArray(address user) public pure returns (address[] memory) {
        address[] memory users = new address[](1);
        users[0] = user;
        return users;
    }

    // function createNumberArray(
    //     uint256 amount
    // ) public pure returns (uint256[] memory) {
    //     uint256[] memory amounts = new uint256[](1);
    //     amounts[0] = amount;
    //     return amounts;
    // }

    function calculateTotal(
        uint256[] memory amounts
    ) external pure returns (uint256) {
        uint256 total;
        for (uint256 i = 0; i < amounts.length; i++) {
            total += amounts[i];
        }
        return total;
    }

    // function calculateAverage(
    //     uint256[] memory values
    // ) public pure returns (uint256) {
    //     // console.log("length", values.length);
    //     if (values.length == 0) {
    //         return 0;
    //     }
    //     uint256 total;
    //     uint256 value = 0;
    //     for (uint256 i = 0; i < values.length; i++) {
    //         total += values[i];
    //     }
    //     value = total / values.length;
    //     // console.log("average value", value);
    //     return value;
    // }

    // function calculateAverageOfValue(
    //     uint256 value,
    //     uint divisor
    // ) public pure returns (uint256) {
    //     if (value / divisor == 0) {
    //         return 0;
    //     }
    //     if (divisor == 0) {
    //         return 0;
    //     }
    //     if (value == 0) {
    //         return 0;
    //     }
    //     uint256 total = value / divisor;
    //     return total;
    // }

    // function normalize(
    //     uint256 x
    // ) public pure returns (uint256 base, int256 exp) {
    //     exp = 0;
    //     base = x;

    //     while (base > 1e18) {
    //         base = base / 10;
    //         exp = exp + 1;
    //     }
    // }

    function calculateInterestRate(
        IDataHub.AssetData memory assetlogs
    ) public pure returns (uint256) {
        // uint256 manipulatedBorrowedAmount = assetlogs.assetInfo[3];
        // uint256 compoundedInterestMultiplier = assetlogs
        //     .compoundedInterestMultiplier;
        // uint256 actualTotalBorrowedAmount = (manipulatedTotalBorrowedAmount *
        //     compoundedInterestMultiplier) / (10 ** 18);

        uint256 actualTotalBorrowedAmount = (assetlogs.assetInfo[3] *
            assetlogs.compoundedInterestMultiplier) / (10 ** 18);

        uint256 borrowProportion;
        if (actualTotalBorrowedAmount != 0) {
            borrowProportion =
                (actualTotalBorrowedAmount * 10 ** 18) /
                assetlogs.assetInfo[2]; /// assetInfo[2] = lendingPoolSupply
        } else {
            borrowProportion = 0;
        }

        uint256 optimalBorrowProportion = assetlogs.borrowProportion[0]; // 0 -> optimalBorrowProportion

        uint256 minimumInterestRate = assetlogs.rateInfo[0];
        uint256 optimalInterestRate = assetlogs.rateInfo[1];
        uint256 maximumInterestRate = assetlogs.rateInfo[2];

        if (borrowProportion <= optimalBorrowProportion) {
            uint256 rate = optimalInterestRate - minimumInterestRate; // 0.145
            return
                min(
                    optimalInterestRate,
                    minimumInterestRate +
                        (rate * borrowProportion) /
                        optimalBorrowProportion
                );
        } else {
            uint256 rate = maximumInterestRate - optimalInterestRate;
            return
                min(
                    maximumInterestRate,
                    optimalInterestRate +
                        (rate * (borrowProportion - optimalBorrowProportion)) /
                        (1e18 - optimalBorrowProportion)
                );
        }
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    // function calculatedepositLiabilityRatio(
    //     uint256 liabilities,
    //     uint256 deposit_amount
    // ) public pure returns (uint256) {
    //     return ((deposit_amount * 10 ** 18) / liabilities); /// fetch decimals integration?
    // }

    function calculateinitialMarginFeeAmount(
        IDataHub.AssetData memory assetdata,
        uint256 liabilities
    ) public pure returns (uint256) {
        return (assetdata.feeInfo[0] * liabilities) / 10 ** 18; // 0 -> initialMarginFee
    }

    // function calculateInitialRequirementForTrade(
    //     IDataHub.AssetData memory assetdata,
    //     uint256 amount
    // ) public pure returns (uint256) {
    //     uint256 initial = assetdata.marginRequirement[0]; // 0 -> InitialMarginRequirement
    //     return (initial * (amount)) / 10 ** 18;
    // }

    // function calculateMaintenanceRequirementForTrade(
    //     IDataHub.AssetData memory assetdata,
    //     uint256 amount
    // ) public pure returns (uint256) {
    //     uint256 maintenance = assetdata.marginRequirement[1]; // 1 -> MaintenanceMarginRequirement
    //     return (maintenance * (amount)) / 10 ** 18;
    // } // 13 deimcals to big

    // function calculateBorrowProportion(
    //     IDataHub.AssetData memory assetdata
    // ) public pure returns (uint256) {
    //     if (assetdata.assetInfo[2] == 0) {
    //         return 0;
    //     }
    //     return (assetdata.assetInfo[1] * 10 ** 18) / assetdata.assetInfo[2]; // 0 -> totalAssetSupply, 1 -> totalBorrowedAmount, 2 -> lendingPoolSupply
    // }

    // function calculateFee(
    //     uint256 _amount,
    //     uint256 _fee
    // ) public pure returns (uint256) {
    //     if (_fee == 0) return 0;
    //     return (_amount * (_fee)) / (10 ** 4);
    // }

    // // This function doesn't compound shit who wrote this? Delete all logic here and remake
    // function calculateCompoundedAssets(
    //     uint256 currentIndex,
    //     uint256 AverageCumulativeDepositInterest,
    //     uint256 userLedingPoolAmount,
    //     uint256 usersOriginIndex
    // ) public pure returns (uint256, uint256, uint256) {
    //     uint256 averageHourly = AverageCumulativeDepositInterest / 8736;
    //     uint256 cumulativeCharge = (userLedingPoolAmount * averageHourly) /
    //         10 ** 18;
    //     uint256 earningsCharge = cumulativeCharge *
    //         (currentIndex - usersOriginIndex);
    //     uint256 earningsToAddToAssets = (earningsCharge * 80) / 100;
    //     uint256 DaoCharge = (earningsCharge * 18) / 100;
    //     uint256 OrderBookProviderCharge = earningsCharge -
    //         earningsToAddToAssets -
    //         DaoCharge;
    //     return (earningsToAddToAssets, OrderBookProviderCharge, DaoCharge);
    // }

    // function calculateCompoundedLiabilities(
    //     uint256 currentIndex, // token index
    //     uint256 AverageCumulativeInterest,
    //     IDataHub.AssetData memory assetdata,
    //     IInterestData.interestDetails memory interestRateInfo,
    //     uint256 newLiabilities,
    //     uint256 usersLiabilities,
    //     uint256 usersOriginIndex
    // ) public pure returns (uint256) {
    //     uint256 amountOfBilledHours = currentIndex - usersOriginIndex;
    //     uint256 adjustedNewLiabilities = (newLiabilities *
    //         (1e18 +
    //             (calculateInterestRate(
    //                 newLiabilities,
    //                 assetdata,
    //                 interestRateInfo
    //             ) / 8736))) / (10 ** 18);
    //     uint256 initalMarginFeeAmount;

    //     if (newLiabilities == 0) {
    //         initalMarginFeeAmount = 0;
    //     } else {
    //         initalMarginFeeAmount = calculateinitialMarginFeeAmount(
    //             assetdata,
    //             newLiabilities
    //         );
    //     }
    //     if (newLiabilities != 0) {
    //         return
    //             (adjustedNewLiabilities + initalMarginFeeAmount) -
    //             newLiabilities;
    //     } else {
    //         uint256 interestCharge;

    //         uint256 averageHourly = 1e18 + AverageCumulativeInterest / 8736;

    //         (uint256 averageHourlyBase, int256 averageHourlyExp) = normalize(
    //             averageHourly
    //         );
    //         averageHourlyExp = averageHourlyExp - 18;

    //         uint256 hourlyChargesBase = 1;
    //         int256 hourlyChargesExp = 0;

    //         while (amountOfBilledHours > 0) {
    //             if (amountOfBilledHours % 2 == 1) {
    //                 (uint256 _base, int256 _exp) = normalize(
    //                     (hourlyChargesBase * averageHourlyBase)
    //                 );

    //                 hourlyChargesBase = _base;
    //                 hourlyChargesExp =
    //                     hourlyChargesExp +
    //                     averageHourlyExp +
    //                     _exp;
    //             }
    //             (uint256 _bases, int256 _exps) = normalize(
    //                 (averageHourlyBase * averageHourlyBase)
    //             );
    //             averageHourlyBase = _bases;
    //             averageHourlyExp = averageHourlyExp + averageHourlyExp + _exps;

    //             amountOfBilledHours /= 2;
    //         }
    //         uint256 compoundedLiabilities = usersLiabilities *
    //             hourlyChargesBase;
    //         unchecked {
    //             if (hourlyChargesExp >= 0) {
    //                 compoundedLiabilities =
    //                     compoundedLiabilities *
    //                     (10 ** uint256(hourlyChargesExp));
    //             } else {
    //                 compoundedLiabilities =
    //                     compoundedLiabilities /
    //                     (10 ** uint256(-hourlyChargesExp));
    //             }
    //             interestCharge =
    //                 (compoundedLiabilities +
    //                     adjustedNewLiabilities +
    //                     initalMarginFeeAmount) -
    //                 (usersLiabilities + newLiabilities);
    //         }
    //         return interestCharge;
    //     }
    // }

    function calculateBorrowProportionAfterTrades(
        IDataHub.AssetData memory assetdata,
        uint256 new_liabilities
    ) public pure returns (bool) {
        if (assetdata.assetInfo[2] == 0) {
            return false;
        }
        uint256 scaleFactor = 1e18; // Scaling factor, e.g., 10^18 for wei

        // here we add the current borrowed amount and the new liabilities to be issued, and scale it
        uint256 scaledTotalBorrowed = (assetdata.assetInfo[1] +
            new_liabilities) * scaleFactor; // 1 -> totalBorrowedAmount

        // Calculate the new borrow proportion
        uint256 newBorrowProportion = (scaledTotalBorrowed /
            assetdata.assetInfo[2]); // totalLendingPoolSupply

        // Compare with maximumBorrowProportion
        return newBorrowProportion <= assetdata.borrowProportion[1]; // 1 -> maximumBorrowProportion
    }
}