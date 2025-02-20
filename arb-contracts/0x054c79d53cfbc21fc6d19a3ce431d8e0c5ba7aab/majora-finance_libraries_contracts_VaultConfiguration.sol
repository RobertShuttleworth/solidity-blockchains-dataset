// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {DataTypes} from "./majora-finance_libraries_contracts_DataTypes.sol";

/**
 * @title Vault configuration library
 * @author Majora Development Association
 * @notice Implements the bitmap logic to handle the vault configuration
 */
library VaultConfiguration {

    /// @notice Error triggered when the middleware strategy is not within the valid range
    error INVALID_MIDDLEWARE_STRATEGY();
    /// @notice Error triggered when the limit mode is not within the valid range
    error INVALID_LIMIT_MODE();
    /// @notice Error triggered when the timelock duration is not within the valid range
    error INVALID_TIMELOCK_DURATION();
    /// @notice Error triggered when the creator fee is not within the valid range
    error INVALID_CREATOR_FEE();
    /// @notice Error triggered when the harvest fee is not within the valid range
    error INVALID_HARVEST_FEE();
    /// @notice Error triggered when the protocol fee is not within the valid range
    error INVALID_PROTOCOL_FEE();
    /// @notice Error triggered when the buffer size is not within the valid range
    error INVALID_BUFFER_SIZE();
    /// @notice Error triggered when the buffer derivation is not within the valid range
    error INVALID_BUFFER_DERIVATION();
    /// @notice Error triggered when the last harvest index is not within the valid range
    error INVALID_LAST_HARVEST_INDEX();
    

    uint256 internal constant MIN_TIMELOCK_DURATION = 0;
    uint256 internal constant MIN_CREATOR_FEE = 100;
    uint256 internal constant MIN_HARVEST_FEE = 50;
    uint256 internal constant MIN_PROTOCOL_FEE = 0;
    uint256 internal constant MAX_CREATOR_FEE = 2500;
    uint256 internal constant MAX_HARVEST_FEE = 500;
    uint256 internal constant MAX_PROTOCOL_FEE = 10001;

    uint256 internal constant MIDDLEWARE_STRATEGY_MASK      = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00;
    uint256 internal constant LIMIT_MODE_MASK               = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00FF;
    uint256 internal constant TIMELOCK_DURATION_MASK        = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00000000FFFF;
    uint256 internal constant CREATOR_FEE_MASK              = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000FFFFFFFFFFFF;
    uint256 internal constant HARVEST_FEE_MASK              = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000FFFFFFFFFFFFFFFF;
    uint256 internal constant PROTOCOL_FEE_MASK             = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000FFFFFFFFFFFFFFFFFFFF;
    uint256 internal constant BUFFER_SIZE_MASK              = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000FFFFFFFFFFFFFFFFFFFFFFFF;
    uint256 internal constant BUFFER_DERIVATION_MASK        = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000FFFFFFFFFFFFFFFFFFFFFFFFFFFF;
    uint256 internal constant LAST_HARVEST_INDEX_MASK       = 0xFFFFFFFFFFFFFFFF0000000000000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

    /// @dev For the MIDDLEWARE_STRATEGY, the start bit is 0 (up to 7), hence no bitshifting is needed
    uint256 internal constant MIDDLEWARE_STRATEGY_START_BIT_POSITION = 0;
    uint256 internal constant LIMIT_MODE_START_BIT_POSITION = 8;
    uint256 internal constant TIMELOCK_DURATION_START_BIT_POSITION = 16;
    uint256 internal constant CREATOR_FEE_START_BIT_POSITION = 48;
    uint256 internal constant HARVEST_FEE_START_BIT_POSITION = 64;
    uint256 internal constant PROTOCOL_FEE_START_BIT_POSITION = 80;
    uint256 internal constant BUFFER_SIZE_START_BIT_POSITION = 96;
    uint256 internal constant BUFFER_DERIVATION_START_BIT_POSITION = 112;
    uint256 internal constant LAST_HARVEST_INDEX_START_BIT_POSITION = 128;

    uint256 internal constant MAX_VALID_MIDDLEWARE_STRATEGY = 255;
    uint256 internal constant MAX_VALID_LIMIT_MODE = 255;
    uint256 internal constant MAX_VALID_TIMELOCK_DURATION = 180 days; // 4294967295 uint32 max 
    uint256 internal constant MAX_VALID_CREATOR_FEE = 65535;
    uint256 internal constant MAX_VALID_HARVEST_FEE = 65535;
    uint256 internal constant MAX_VALID_PROTOCOL_FEE = 65535;
    uint256 internal constant MAX_VALID_BUFFER_SIZE = 65535;
    uint256 internal constant MAX_VALID_BUFFER_DERIVATION = 65535;
    uint256 internal constant MAX_VALID_LAST_HARVEST_INDEX = 18446744073709551615;

    /**
     * @notice Sets the middleware strategy configuration
     * @param self The vault configuration
     * @param middlewareStrategy The new middleware strategy id
     */
    function setMiddlewareStrategy(DataTypes.VaultConfigurationMap memory self, uint256 middlewareStrategy)
        internal
        pure
    {
        if (middlewareStrategy > MAX_VALID_MIDDLEWARE_STRATEGY) {
            revert INVALID_MIDDLEWARE_STRATEGY();
        }
        self.data = (self.data & MIDDLEWARE_STRATEGY_MASK) | middlewareStrategy;
    }

    /**
     * @notice Gets the middleware strategy configuration
     * @param self The vault configuration
     * @return The middleware strategy id
     */
    function getMiddlewareStrategy(DataTypes.VaultConfigurationMap memory self) internal pure returns (uint256) {
        return self.data & ~MIDDLEWARE_STRATEGY_MASK;
    }

    /**
     * @notice Sets the limit mode configuration
     * @param self The vault configuration
     * @param limitMode The new limit mode value
     */
    function setLimitMode(DataTypes.VaultConfigurationMap memory self, uint256 limitMode) internal pure {
        if (limitMode > MAX_VALID_LIMIT_MODE) revert INVALID_LIMIT_MODE();

        self.data = (self.data & LIMIT_MODE_MASK) | (limitMode << LIMIT_MODE_START_BIT_POSITION);
    }

    /**
     * @notice Gets the limit mode configuration
     * @param self The vault configuration
     * @return The limit mode value
     */
    function getLimitMode(DataTypes.VaultConfigurationMap memory self) internal pure returns (uint256) {
        return (self.data & ~LIMIT_MODE_MASK) >> LIMIT_MODE_START_BIT_POSITION;
    }

    /**
     * @notice Sets the timelock duration
     * @param self The vault configuration
     * @param timelockDuration The new timelock duration
     */
    function setTimelockDuration(DataTypes.VaultConfigurationMap memory self, uint256 timelockDuration) internal pure {
        if (timelockDuration > MAX_VALID_TIMELOCK_DURATION || timelockDuration < MIN_TIMELOCK_DURATION) {
            revert INVALID_TIMELOCK_DURATION();
        }

        self.data = (self.data & TIMELOCK_DURATION_MASK) | (timelockDuration << TIMELOCK_DURATION_START_BIT_POSITION);
    }

    /**
     * @notice Gets the timelock duration
     * @param self The vault configuration
     * @return The timelock duration
     */
    function getTimelockDuration(DataTypes.VaultConfigurationMap memory self) internal pure returns (uint256) {
        return (self.data & ~TIMELOCK_DURATION_MASK) >> TIMELOCK_DURATION_START_BIT_POSITION;
    }

    /**
     * @notice Sets the creator fee
     * @param self The vault configuration
     * @param creatorFee The new creator fee
     */
    function setCreatorFee(DataTypes.VaultConfigurationMap memory self, uint256 creatorFee) internal pure {
        if (creatorFee > MAX_VALID_CREATOR_FEE || creatorFee < MIN_CREATOR_FEE || creatorFee > MAX_CREATOR_FEE) {
            revert INVALID_CREATOR_FEE();
        }

        self.data = (self.data & CREATOR_FEE_MASK) | (creatorFee << CREATOR_FEE_START_BIT_POSITION);
    }

    /**
     * @notice Gets the creator fee
     * @param self The vault configuration
     * @return The creator fee
     */
    function getCreatorFee(DataTypes.VaultConfigurationMap memory self) internal pure returns (uint256) {
        return (self.data & ~CREATOR_FEE_MASK) >> CREATOR_FEE_START_BIT_POSITION;
    }

    /**
     * @notice Sets the harvest fee
     * @param self The vault configuration
     * @param harvestFee The new harvest fee
     */
    function setHarvestFee(DataTypes.VaultConfigurationMap memory self, uint256 harvestFee) internal pure {
        if (harvestFee > MAX_VALID_HARVEST_FEE || harvestFee < MIN_HARVEST_FEE || harvestFee > MAX_HARVEST_FEE) {
            revert INVALID_HARVEST_FEE();
        }

        self.data = (self.data & HARVEST_FEE_MASK) | (harvestFee << HARVEST_FEE_START_BIT_POSITION);
    }

    /**
     * @notice Gets the harvest fee
     * @param self The vault configuration
     * @return The harvest fee
     */
    function getHarvestFee(DataTypes.VaultConfigurationMap memory self) internal pure returns (uint256) {
        return (self.data & ~HARVEST_FEE_MASK) >> HARVEST_FEE_START_BIT_POSITION;
    }

    /**
     * @notice Sets the protocol fee
     * @param self The vault configuration
     * @param protocolFee The new protocol fee
     */
    function setProtocolFee(DataTypes.VaultConfigurationMap memory self, uint256 protocolFee) internal pure {
        if (protocolFee > MAX_VALID_PROTOCOL_FEE || protocolFee < MIN_PROTOCOL_FEE || protocolFee > MAX_PROTOCOL_FEE) {
            revert INVALID_PROTOCOL_FEE();
        }

        self.data = (self.data & PROTOCOL_FEE_MASK) | (protocolFee << PROTOCOL_FEE_START_BIT_POSITION);
    }

    /**
     * @notice Gets the protocol fee
     * @param self The vault configuration
     * @return The protocol fee
     */
    function getProtocolFee(DataTypes.VaultConfigurationMap memory self) internal pure returns (uint256) {
        return (self.data & ~PROTOCOL_FEE_MASK) >> PROTOCOL_FEE_START_BIT_POSITION;
    }

    /**
     * @notice Sets the buffer size
     * @param self The vault configuration
     * @param bufferSize The new buffer size
     */
    function setBufferSize(DataTypes.VaultConfigurationMap memory self, uint256 bufferSize) internal pure {
        if (bufferSize > MAX_VALID_BUFFER_SIZE) revert INVALID_BUFFER_SIZE();

        self.data = (self.data & BUFFER_SIZE_MASK) | (bufferSize << BUFFER_SIZE_START_BIT_POSITION);
    }

    /**
     * @notice Gets the buffer size
     * @param self The vault configuration
     * @return The buffer size
     */
    function getBufferSize(DataTypes.VaultConfigurationMap memory self) internal pure returns (uint256) {
        return (self.data & ~BUFFER_SIZE_MASK) >> BUFFER_SIZE_START_BIT_POSITION;
    }

    /**
     * @notice Sets the tolerated buffer derivation percent
     * @param self The vault configuration
     * @param bufferDerivation The new buffer derivation
     */
    function setBufferDerivation(DataTypes.VaultConfigurationMap memory self, uint256 bufferDerivation) internal pure {
        if (bufferDerivation > MAX_VALID_BUFFER_DERIVATION) {
            revert INVALID_BUFFER_DERIVATION();
        }

        self.data = (self.data & BUFFER_DERIVATION_MASK) | (bufferDerivation << BUFFER_DERIVATION_START_BIT_POSITION);
    }

    /**
     * @notice Gets the tolerated buffer derivation percent
     * @param self The vault configuration
     * @return The buffer derivation 
     */
    function getBufferDerivation(DataTypes.VaultConfigurationMap memory self) internal pure returns (uint256) {
        return (self.data & ~BUFFER_DERIVATION_MASK) >> BUFFER_DERIVATION_START_BIT_POSITION;
    }

    /**
     * @notice Sets the vault index during the last harvest 
     * @param self The reserve configuration
     * @param lastHarvestIndex The last harvest vault index
     */
    function setLastHarvestIndex(DataTypes.VaultConfigurationMap memory self, uint256 lastHarvestIndex) internal pure {
        if (lastHarvestIndex > MAX_VALID_LAST_HARVEST_INDEX) {
            revert INVALID_LAST_HARVEST_INDEX();
        }

        self.data = (self.data & LAST_HARVEST_INDEX_MASK) | (lastHarvestIndex << LAST_HARVEST_INDEX_START_BIT_POSITION);
    }

    /**
     * @notice Gets the last harvest vault index
     * @param self The reserve configuration
     * @return The last harvest vault index
     */
    function getLastHarvestIndex(DataTypes.VaultConfigurationMap memory self) internal pure returns (uint256) {
        return (self.data & ~LAST_HARVEST_INDEX_MASK) >> LAST_HARVEST_INDEX_START_BIT_POSITION;
    }
}