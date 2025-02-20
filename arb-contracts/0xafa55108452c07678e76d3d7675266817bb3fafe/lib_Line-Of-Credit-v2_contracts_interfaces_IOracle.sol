pragma solidity ^0.8.25;

interface IOracle {
    error InvalidToken();

    error InvalidInput();

    error NotOwner();

    error NullPrice(address);

    /**
     * Readonly function providing the current price for token asset. denominated in USD
     */
    function getLatestAnswer(address token) external view returns (int256);

    function setOwner(address _owner) external;

    function setPriceFeed(address token, address feed) external;
}