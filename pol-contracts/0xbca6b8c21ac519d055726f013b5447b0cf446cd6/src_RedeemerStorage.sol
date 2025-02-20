// (c) 2024 Primex.finance
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IERC20} from "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import {ERC20Burnable} from "./openzeppelin_contracts_token_ERC20_extensions_ERC20Burnable.sol";
import {IRedeemerStorage} from "./src_IRedeemerStorage.sol";
import {IAccessControl} from "./openzeppelin_contracts_access_IAccessControl.sol";
import {ReentrancyGuardUpgradeable} from "./openzeppelin_contracts-upgradeable_utils_ReentrancyGuardUpgradeable.sol";


abstract contract RedeemerStorage is IRedeemerStorage, ReentrancyGuardUpgradeable {
    ERC20Burnable public override epmx;
    IERC20 public override pmx;
    IAccessControl public override registry;
    address public override treasury;
    VestingParams public override vestingParams;
    mapping(address => bool) public override isBlackListed;
    mapping(address => bool) public override isWhiteListed;


    bool internal whiteListingEnabled;
    bytes32[] internal vestingSchedulesIds;
    mapping(bytes32 => VestingSchedule) internal vestingSchedules;
    uint256 internal vestingSchedulesTotalAmount;
    uint256 internal vestingReleasedTotalAmount;
    mapping(address => uint256) internal holdersVestingCount;
}