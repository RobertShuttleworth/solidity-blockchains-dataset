// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title IPendlePtLpOracle
 * @dev Interface for interacting with the Pendle PT LP Oracle.
 */
interface IPendlePtLpOracle {
    /*//////////////////////////////////////////////////////////////////////////
                                FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * @notice Retrieves the PT to asset rate.
     * @param market Address of the market.
     * @param duration Duration for the rate query.
     * @return The PT to asset rate scaled by 1e18.
     */
    function getPtToAssetRate(address market, uint32 duration) external view returns (uint256);

    /**
     * @notice Retrieves the LP to asset rate.
     * @param market Address of the market.
     * @param duration Duration for the rate query.
     * @return The LP to asset rate scaled by 1e18.
     */
    function getLpToAssetRate(address market, uint32 duration) external view returns (uint256);

    /**
     * @notice Retrieves the PT to SY rate.
     * @param market Address of the market.
     * @param duration Duration for the rate query.
     * @return The PT to SY rate scaled by 1e18.
     */
    function getPtToSyRate(address market, uint32 duration) external view returns (uint256);

    /**
     * @notice Retrieves the LP to SY rate.
     * @param market Address of the market.
     * @param duration Duration for the rate query.
     * @return The LP to SY rate scaled by 1e18.
     */
    function getLpToSyRate(address market, uint32 duration) external view returns (uint256);

    /**
     * @notice Retrieves the oracle state for a given market and duration.
     * @param market Address of the market.
     * @param duration Duration for the state query.
     * @return increaseCardinalityRequired Whether cardinality needs to be increased.
     * @return cardinalityRequired The required cardinality.
     * @return oldestObservationSatisfied Whether the oldest observation is satisfied.
     */
    function getOracleState(address market, uint32 duration)
        external
        view
        returns (
            bool increaseCardinalityRequired,
            uint16 cardinalityRequired,
            bool oldestObservationSatisfied
        );
}