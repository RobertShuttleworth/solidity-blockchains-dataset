// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.19;

import {OwnableUpgradeable} from "./lib_openzeppelin-contracts-upgradeable_contracts_access_OwnableUpgradeable.sol";
import {EnumerableSet} from "./lib_openzeppelin-contracts-upgradeable_lib_openzeppelin-contracts_contracts_utils_structs_EnumerableSet.sol";
import {ERC20Upgradeable} from "./lib_openzeppelin-contracts-upgradeable_contracts_token_ERC20_ERC20Upgradeable.sol";
import {UUPSUpgradeable} from "./lib_openzeppelin-contracts-upgradeable_contracts_proxy_utils_UUPSUpgradeable.sol";

import {currentEpoch, WEEK} from "./src_libraries_EpochMath.sol";
import {AbraStorageLayoutCompatibility} from "./src_token_AbraStorageLayoutCompatibility.sol";

error Abra_NotMinter(address sender);
error Abra_MaxMintersReached();

contract Abra is AbraStorageLayoutCompatibility, ERC20Upgradeable, OwnableUpgradeable, UUPSUpgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;

    uint public immutable MAX_MINTERS;

    /// @custom:oz-renamed-from supplyChekpoints
    mapping(uint32 epoch => uint112) public supplyCheckpoints;
    EnumerableSet.AddressSet private minters;

    constructor(uint maxMinters) {
        MAX_MINTERS = maxMinters;
    }

    function initialize(uint _initialSupply, string memory _name, string memory _symbol) public initializer {
        __ERC20_init(_name, _symbol);
        __Ownable_init_unchained(msg.sender);
        __UUPSUpgradeable_init();
        _mint(_msgSender(), _initialSupply);
        supplyCheckpoints[currentEpoch()] = uint112(_initialSupply);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}


    function mint(address account, uint amount) external {
        if (!minters.contains(msg.sender)) {
            revert Abra_NotMinter(msg.sender);
        }
        _mint(account, amount);
        supplyCheckpoints[currentEpoch()] = uint112(totalSupply()); // uint112 should be enough for ABRA
    }

    function burn(uint amount) external {
        _burn(msg.sender, amount);
        supplyCheckpoints[currentEpoch()] = uint112(totalSupply()); // uint112 should be enough for ABRA
    }

    // NOTE: This function must be timelocked
    function setMinter(address minter) external onlyOwner {
        if (minters.length() >= MAX_MINTERS) {
            revert Abra_MaxMintersReached();
        }
        minters.add(minter);
    }

    function removeMinter(address minter) external onlyOwner {
        minters.remove(minter);
    }

    function mintersLength() external view returns (uint) {
        return minters.length();
    }

    function minterAt(uint index) external view returns (address) {
        return minters.at(index);
    }

    function makeupEpoch(uint32 epoch) external onlyOwner {
        // make up for only past epochs
        if (epoch < currentEpoch() && supplyCheckpoints[epoch] == 0) {
            uint32 prevEpoch = epoch - WEEK;
            supplyCheckpoints[epoch] = supplyCheckpoints[prevEpoch];
        }
    }
}