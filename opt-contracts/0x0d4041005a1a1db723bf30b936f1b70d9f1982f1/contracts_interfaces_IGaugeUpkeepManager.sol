// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

interface IGaugeUpkeepManager {
    event GaugeUpkeepRegistered(address indexed gauge, uint256 indexed upkeepId);
    event GaugeUpkeepCancelled(address indexed gauge, uint256 indexed upkeepId);
    event GaugeUpkeepWithdrawn(uint256 indexed upkeepId);
    event NewUpkeepGasLimitSet(uint32 newUpkeepGasLimit);
    event NewUpkeepFundAmountSet(uint96 newUpkeepFundAmount);
    event TrustedForwarderSet(address indexed trustedForwarder, bool isTrusted);
    event LinkBalanceWithdrawn(address indexed receiver, uint256 amount);

    error InvalidPerformAction();
    error AutoApproveDisabled();
    error UnauthorizedSender();
    error AddressZeroNotAllowed();
    error NoLinkBalance();
    error NotGauge(address gauge);
    error CrosschainGaugeNotAllowed(address gauge);
    error GaugeUpkeepExists(address gauge);
    error GaugeUpkeepNotFound(address gauge);

    enum PerformAction {
        REGISTER_UPKEEP,
        CANCEL_UPKEEP
    }

    /// @notice LINK token address
    function linkToken() external view returns (address);

    /// @notice Keeper registry address
    function keeperRegistry() external view returns (address);

    /// @notice Automation registrar address
    function automationRegistrar() external view returns (address);

    /// @notice Cron upkeep factory address
    function cronUpkeepFactory() external view returns (address);

    /// @notice Voter address
    function voter() external view returns (address);

    /// @notice Factory registry address
    function factoryRegistry() external view returns (address);

    /// @notice Amount of LINK to transfer to upkeep on registration
    function newUpkeepFundAmount() external view returns (uint96);

    /// @notice Gas limit for new upkeeps
    function newUpkeepGasLimit() external view returns (uint32);

    /// @notice Whether an address is a trusted forwarder
    /// @param _forwarder Forwarder address
    /// @return True if set as trusted forwarder, false otherwise
    function trustedForwarder(address _forwarder) external view returns (bool);

    /// @notice Whether a gauge factory is a crosschain factory
    /// @param _gaugeFactory Gauge factory address
    /// @return True if the gauge factory is a crosschain factory
    function crosschainGaugeFactory(address _gaugeFactory) external view returns (bool);

    /// @notice Upkeep ID for a gauge
    /// @param _gauge Gauge address
    /// @return Upkeep ID
    function gaugeUpkeepId(address _gauge) external view returns (uint256);

    /// @notice Get an upkeep ID from the list of active upkeeps
    /// @param _index Active upkeep IDs array index
    /// @return Upkeep ID
    function activeUpkeepIds(uint256 _index) external view returns (uint256);

    /// @notice Get the total number of active gauge upkeeps
    /// @return Active upkeeps array length
    function activeUpkeepsCount() external view returns (uint256);

    /// @notice Withdraw remaining upkeep LINK balance to contract balance
    /// @param _upkeepId Gauge upkeep ID owned by the contract
    /// @dev Upkeep must be cancelled before withdrawing
    function withdrawUpkeep(uint256 _upkeepId) external;

    /// @notice Transfer contract LINK balance to owner
    function withdrawLinkBalance() external;

    /// @notice Update the gas limit for new gauge upkeeps
    /// @param _newUpkeepGasLimit New upkeep gas limit
    function setNewUpkeepGasLimit(uint32 _newUpkeepGasLimit) external;

    /// @notice Update the LINK amount to transfer to new gauge upkeeps
    /// @param _newUpkeepFundAmount New upkeep fund amount
    function setNewUpkeepFundAmount(uint96 _newUpkeepFundAmount) external;

    /// @notice Set the automation trusted forwarder address
    /// @param _trustedForwarder Upkeep trusted forwarder address
    /// @param _isTrusted True to enable trusted forwarder, false to disable
    function setTrustedForwarder(address _trustedForwarder, bool _isTrusted) external;

    /// @notice Register gauge upkeeps
    /// @param _gauges Array of gauge addresses
    /// @return Array of registered upkeep IDs
    function registerGaugeUpkeeps(address[] calldata _gauges) external returns (uint256[] memory);

    /// @notice Deregister gauge upkeeps
    /// @param _gauges Array of gauge addresses
    /// @return Array of deregistered upkeep IDs
    function deregisterGaugeUpkeeps(address[] calldata _gauges) external returns (uint256[] memory);
}