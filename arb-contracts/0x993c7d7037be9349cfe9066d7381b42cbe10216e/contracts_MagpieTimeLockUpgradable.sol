import "./node_modules_openzeppelin_contracts-upgradeable_governance_TimelockControllerUpgradeable.sol";

contract MagpieTimeLockUpgradable is TimelockControllerUpgradeable {
    
    function initialize(
        uint256 minDelay,
        address[] memory proposers,
        address[] memory executors
    ) external initializer {
        __TimelockController_init(minDelay, proposers, executors);
    }
}