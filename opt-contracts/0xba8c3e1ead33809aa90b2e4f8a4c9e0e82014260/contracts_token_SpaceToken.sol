// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./openzeppelin_contracts-upgradeable_token_ERC20_ERC20Upgradeable.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC20_extensions_ERC20SnapshotUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_access_OwnableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_security_PausableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";
import "./openzeppelin_contracts_utils_math_Math.sol";

import './contracts_token_ISpaceToken.sol';
import './contracts_roles_TokenManagerRole.sol';
import './contracts_settings_RevLimiter.sol';

contract SpaceToken is 
    Initializable, 
    TokenManagerRole, 
    ERC20Upgradeable, 
    ERC20SnapshotUpgradeable,
    PausableUpgradeable,
    ISpaceToken {

    using Math for uint256;
    
    uint256 internal _currentMultiplier;
    uint256 internal _defaultMintAmount;
    uint256 internal _currentMultiplierStartDate;
    uint256 internal _multiplierDuration;
    uint256 public MULTIPLIER_DECREASE_RATE; 
    uint256 public MAX_MULTIPLIER_EPOCS; 
    uint256 public CURRENT_MULTIPLIER_EPOC;
    uint256 public MULTIPLIER_AFTER_EPOC_EXPIRY;
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }  

    modifier UpdateMultiplier() {
        if(shouldUpdateMultiplier()) {
            if(CURRENT_MULTIPLIER_EPOC == MAX_MULTIPLIER_EPOCS) {
                _currentMultiplier = MULTIPLIER_AFTER_EPOC_EXPIRY;
            } else { 
                CURRENT_MULTIPLIER_EPOC += 1;
                _currentMultiplier -= MULTIPLIER_DECREASE_RATE;
                _currentMultiplierStartDate = block.timestamp;
            }
        }
        _;
    }

    function initialize() initializer public {
        __SpaceToken_init();
    }
    function __SpaceToken_init() internal onlyInitializing {
        __ERC20_init('Hashtag Space Token', '$SPACE');
        __ERC20Snapshot_init();
        __Pausable_init();
        __TokenManagerRole_init();
        __SpaceToken_init_unchained();
    }

    function __SpaceToken_init_unchained() internal {
        _currentMultiplier = 20000;
        _currentMultiplierStartDate = block.timestamp;
        // _defaultMintAmount = 100 ether;
        _multiplierDuration = 365 days;
        MULTIPLIER_DECREASE_RATE = 1000;
        MAX_MULTIPLIER_EPOCS = 10;
        CURRENT_MULTIPLIER_EPOC = 1;
        MULTIPLIER_AFTER_EPOC_EXPIRY = 10000;
    }
    
    function snapshot() public onlyOwner {
        _snapshot();
    }

    function pause() public onlyTokenManager {
        _pause();        _currentMultiplier = 10000;
        _currentMultiplierStartDate = block.timestamp;
        _defaultMintAmount = 100 ether;
        _multiplierDuration = 365 days;
        MULTIPLIER_DECREASE_RATE = 1000;
        MAX_MULTIPLIER_EPOCS = 10; 
        CURRENT_MULTIPLIER_EPOC = 1;
        MULTIPLIER_AFTER_EPOC_EXPIRY = 100;
    }

    function unpause() public onlyTokenManager {
        _unpause();
    }

    function mint(address to, uint256 amount) external override onlyTokenManager whenNotPaused UpdateMultiplier {
        _mint(to, amount);
    }

    function mintMany(
        address[] memory tos,  
        uint256[] memory amounts
    ) external override onlyTokenManager UpdateMultiplier {
        for(uint256 i = 0; i < tos.length; i++) {
            _mint(tos[i], amounts[i]);
        }
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        whenNotPaused
        override(ERC20Upgradeable, ERC20SnapshotUpgradeable)
    {
        super._beforeTokenTransfer(from, to, amount);
    }

    function currentMultiplier() public view override returns (uint256) {
        return _currentMultiplier;
    }

    function shouldUpdateMultiplier() public view returns (bool) {
        return (block.timestamp >= nextMultiplierUpdate()) && (_currentMultiplier != MULTIPLIER_AFTER_EPOC_EXPIRY);
    }

    function nextMultiplierUpdate() public view returns (uint256) {
        return _currentMultiplierStartDate + _multiplierDuration;
    } 

    function timeBeforeNextMultiplier() public view override returns (uint256) {
        return nextMultiplierUpdate() - block.timestamp;
    }

    uint256[50] private __gap;
}