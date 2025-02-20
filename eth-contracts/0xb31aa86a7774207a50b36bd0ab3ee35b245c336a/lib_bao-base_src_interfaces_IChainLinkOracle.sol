// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title IChainLinkOracle
 * @notice Interface for the Chainlink Oracle contract, defining the structure and functions for accessing price data.
 * @dev This interface outlines the core functionality for retrieving price feeds and historical round data.
 */
interface IChainLinkOracle {
    /*//////////////////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * @notice Emitted when an answer is updated in the oracle
     * @param current The updated answer value
     * @param roundId The round ID associated with the update
     * @param updatedAt The timestamp when the update occurred
     */
    event AnswerUpdated(int256 indexed current, uint256 indexed roundId, uint256 updatedAt);

    /**
     * @notice Emitted when a new round starts in the oracle
     * @param roundId The round ID of the new round
     * @param startedBy The address that started the new round
     * @param startedAt The timestamp when the round started
     */
    event NewRound(uint256 indexed roundId, address indexed startedBy, uint256 startedAt);

    /*//////////////////////////////////////////////////////////////////////////
                                FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * @notice Retrieves the number of decimals used by the oracle
     * @return The number of decimals
     */
    function decimals() external view returns (uint8);

    /**
     * @notice Retrieves the description of the oracle
     * @return A string describing the oracle
     */
    function description() external view returns (string memory);

    /**
     * @notice Retrieves the latest answer reported by the oracle
     * @return The latest answer as an int256
     */
    function latestAnswer() external view returns (int256);

    /**
     * @notice Retrieves the timestamp of the latest round
     * @return The timestamp of the latest round
     */
    function latestTimestamp() external view returns (uint256);

    /**
     * @notice Retrieves the ID of the latest round
     * @return The round ID of the latest round
     */
    function latestRound() external view returns (uint256);

    /**
     * @notice Retrieves the answer for a specific round ID
     * @param roundId The round ID to query
     * @return The answer for the specified round as an int256
     */
    function getAnswer(uint256 roundId) external view returns (int256);

    /**
     * @notice Retrieves the timestamp for a specific round ID
     * @param roundId The round ID to query
     * @return The timestamp for the specified round
     */
    function getTimestamp(uint256 roundId) external view returns (uint256);

    /**
     * @notice Retrieves the version of the oracle
     * @return The version of the oracle
     */
    function version() external view returns (uint256);

    /**
     * @notice Retrieves the data for a specific round ID
     * @param _roundId The round ID to query
     * @return roundId The round ID of the queried data
     * @return answer The answer for the queried round
     * @return startedAt The timestamp when the round started
     * @return updatedAt The timestamp when the round was updated
     * @return answeredInRound The round ID in which the answer was computed
     */
    function getRoundData(uint80 _roundId)
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );

    /**
     * @notice Retrieves the latest round data from the oracle
     * @return roundId The round ID of the latest round
     * @return answer The latest answer
     * @return startedAt The timestamp when the latest round started
     * @return updatedAt The timestamp when the latest round was updated
     * @return answeredInRound The round ID in which the latest answer was computed
     */
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