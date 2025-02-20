// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import {Abra} from "./src_token_Abra.sol";
import {AbraStaking} from "./src_token_AbraStaking.sol";

import {IERC20} from "./lib_openzeppelin-contracts-upgradeable_lib_openzeppelin-contracts_contracts_token_ERC20_IERC20.sol";
import {AccessManagedUpgradeable} from "./lib_openzeppelin-contracts-upgradeable_contracts_access_manager_AccessManagedUpgradeable.sol";
import {UUPSUpgradeable} from "./lib_openzeppelin-contracts-upgradeable_contracts_proxy_utils_UUPSUpgradeable.sol";

import {IEpochController} from './src_interfaces_IEpochController.sol';
import {currentEpoch, previousEpoch, WEEK} from "./src_libraries_EpochMath.sol";

error MinterUpgradeable_AlreadyMinted();
error MinterUpgradeable_AccessDenied();
error MinterUpgradeable_InvalidDate();

contract MinterUpgradeable is AccessManagedUpgradeable, UUPSUpgradeable, IEpochController {

    /// Represents 1% decrease in emission each week
    uint256 constant RETENTION_RATE = 990;
    uint256 constant PRECISION = 1000;

    Abra private immutable ABRA;

    address public master;
    /// Weekly emission. Decreased each week
    uint   public weeklyEmission;
    uint32 public openEpoch;
    uint32 public firstEpoch;

    event FirstEpoch(uint256 firstEpoch);

    constructor(Abra _abra) {
        ABRA = _abra;
        _disableInitializers();
    }

    function initialize(uint _weeklyEmission, address _authority, uint32 _firstEpoch) public initializer {
        uint remainder = (_firstEpoch - currentEpoch()) % WEEK;
        if (remainder > 0) revert MinterUpgradeable_InvalidDate();

        __AccessManaged_init(_authority);
        __UUPSUpgradeable_init();

        weeklyEmission = _weeklyEmission;
        firstEpoch = _firstEpoch;
        openEpoch  = _firstEpoch;

        emit FirstEpoch(_firstEpoch);
    }

    /// @dev intentionally using `restricted` for internal function
    function _authorizeUpgrade(address) internal override restricted {
    }

    function mint(address recevier) external returns (uint minted) {
        if (msg.sender != master)        revert MinterUpgradeable_AccessDenied();
        if (openEpoch >= currentEpoch()) revert MinterUpgradeable_AlreadyMinted();

        openEpoch += WEEK;
        uint emission;
        if (_isCruise()) {
            emission = weeklyEmission;
            weeklyEmission = emission * RETENTION_RATE / PRECISION;
        } else {
            emission = _takeoffEmission();
        }

        ABRA.mint(recevier, emission);
        return emission;
    }

    function abra() external view returns (Abra) {
        return ABRA;
    }

    function setMaster(address _master) external restricted {
        master = _master;
    }

    function _isCruise() internal view returns(bool) {
        uint epochNumber = (openEpoch - firstEpoch) / WEEK;
        return epochNumber > 5;
    }

    /// @dev must be called after `openEpoch` was incremented
    function _takeoffEmission() internal view returns (uint emission) {
        uint epochNumber = (openEpoch - firstEpoch) / WEEK;
        if (epochNumber == 1) return 18_000e18; // 18k for starting week;        
        if (epochNumber == 2) return 34_000e18; // 34k  
        if (epochNumber == 3) return 28_000e18; // 28k  
        if (epochNumber == 4) return 24_000e18; // 24k  
        if (epochNumber == 5) return 22_000e18; // 22k  

        revert MinterUpgradeable_InvalidDate();
    }
}