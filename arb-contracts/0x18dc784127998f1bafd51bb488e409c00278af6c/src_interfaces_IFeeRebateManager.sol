// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/// @title Interface for FeeRebateManager
/// @notice This contract is used to manage the fee rebates for the users
interface IFeeRebateManager {
    struct TradeDetails {
        uint256 monthlyVolume;
        uint256 monthlyFee;
        bool isClaimed;
    }

    struct RebateTier {
        uint256 monthlyVolumeThreshold;
        uint256 rebatePercentage;
    }

    struct DiscountTier {
        uint256 stakedAmountThreshold;
        uint256 discountPercentage;
    }

    function initialize(address _comptroller) external;

    function epochStartTime() external view returns (uint256);
    function isFeeRebateEnabled() external view returns (bool);
    function rebateTiers(uint256) external view returns (uint256, uint256);
    function discountTiers(uint256) external view returns (uint256, uint256);
    function userTradeDetails(
        address,
        uint256
    )
        external
        view
        returns (uint256, uint256, bool);

    function setIsFeeRebateEnabled(bool _isFeeRebateEnabled) external;

    function setRebateTier(
        uint256 tier,
        uint256 monthlyVolumeThreshold,
        uint256 rebatePercentage
    )
        external;
    function setDiscountTier(
        uint256 tier,
        uint256 stakedAmountThreshold,
        uint256 discountPercentage
    )
        external;

    function setFactory(address factory, bool isFactory) external;

    function getCurrentMonthId() external view returns (uint256);
    function calculateFeeDiscount(address _user)
        external
        view
        returns (uint256);
    function calculateFeeRebate(uint256 totalVolume)
        external
        view
        returns (uint256);

    function updateTradeDetails(
        address _user,
        uint256 _volume,
        uint256 _fee
    )
        external;
    function claimRebate(uint256 monthId) external;
}