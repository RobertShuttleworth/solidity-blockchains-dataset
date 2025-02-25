//SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.20;

import "./contracts_v1-cmtat-tokenization_modules_security_AuthorizationModule.sol";
import "./contracts_v1-cmtat-tokenization_modules_internal_ValidationModuleInternal.sol";
import "./contracts_v1-cmtat-tokenization_modules_wrapper_core_PauseModule.sol";
import "./contracts_v1-cmtat-tokenization_modules_wrapper_core_EnforcementModule.sol";

import "./contracts_v1-cmtat-tokenization_libraries_Errors.sol";

/**
 * @dev Validation module.
 *
 * Useful for to restrict and validate transfers
 */
abstract contract ValidationModule is
    ValidationModuleInternal,
    PauseModule,
    EnforcementModule,
    IERC1404Wrapper
{
    /* ============ State Variables ============ */
    string constant TEXT_TRANSFER_OK = "No restriction";
    string constant TEXT_UNKNOWN_CODE = "Unknown code";

    /* ============  Initializer Function ============ */
    function __ValidationModule_init_unchained() internal onlyInitializing {
        // no variable to initialize
    }


    /*//////////////////////////////////////////////////////////////
                            PUBLIC/EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /*
    * @notice set a RuleEngine
    * @param ruleEngine_ the call will be reverted if the new value of ruleEngine is the same as the current one
    */
    function setRuleEngine(
        IRuleEngine ruleEngine_
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        ValidationModuleInternalStorage storage $ = _getValidationModuleInternalStorage();
        if ($._ruleEngine == ruleEngine_){
             revert Errors.CMTAT_ValidationModule_SameValue();
        }
        $._ruleEngine = ruleEngine_;
        emit RuleEngine(ruleEngine_);
    }

    /**
     * @dev ERC1404 returns the human readable explaination corresponding to the error code returned by detectTransferRestriction
     * @param restrictionCode The error code returned by detectTransferRestriction
     * @return message The human readable explaination corresponding to the error code returned by detectTransferRestriction
     */
    function messageForTransferRestriction(
        uint8 restrictionCode
    ) external view override returns (string memory message) {
          ValidationModuleInternalStorage storage $ = _getValidationModuleInternalStorage();
        if (restrictionCode == uint8(REJECTED_CODE_BASE.TRANSFER_OK)) {
            return TEXT_TRANSFER_OK;
        } else if (
            restrictionCode ==
            uint8(REJECTED_CODE_BASE.TRANSFER_REJECTED_PAUSED)
        ) {
            return TEXT_TRANSFER_REJECTED_PAUSED;
        } else if (
            restrictionCode ==
            uint8(REJECTED_CODE_BASE.TRANSFER_REJECTED_FROM_FROZEN)
        ) {
            return TEXT_TRANSFER_REJECTED_FROM_FROZEN;
        } else if (
            restrictionCode ==
            uint8(REJECTED_CODE_BASE.TRANSFER_REJECTED_TO_FROZEN)
        ) {
            return TEXT_TRANSFER_REJECTED_TO_FROZEN;
        } else if (address($._ruleEngine) != address(0)) {
            return _messageForTransferRestriction(restrictionCode);
        } else {
            return TEXT_UNKNOWN_CODE;
        }
    }
    
    /**
     * @dev ERC1404 check if _value token can be transferred from _from to _to
     * @param from address The address which you want to send tokens from
     * @param to address The address which you want to transfer to
     * @param amount uint256 the amount of tokens to be transferred
     * @return code of the rejection reason
     */
    function detectTransferRestriction(
        address from,
        address to,
        uint256 amount
    ) public view override returns (uint8 code) {
        ValidationModuleInternalStorage storage $ = _getValidationModuleInternalStorage();
        if (paused()) {
            return uint8(REJECTED_CODE_BASE.TRANSFER_REJECTED_PAUSED);
        } else if (frozen(from)) {
            return uint8(REJECTED_CODE_BASE.TRANSFER_REJECTED_FROM_FROZEN);
        } else if (frozen(to)) {
            return uint8(REJECTED_CODE_BASE.TRANSFER_REJECTED_TO_FROZEN);
        } else if (address($._ruleEngine) != address(0)) {
            return _detectTransferRestriction(from, to, amount);
        } else {
            return uint8(REJECTED_CODE_BASE.TRANSFER_OK);
        }
    }

    function validateTransfer(
        address from,
        address to,
        uint256 amount
    ) public view override returns (bool) {
        if (!_validateTransferByModule(from, to, amount)) {
            return false;
        }
        ValidationModuleInternalStorage storage $ = _getValidationModuleInternalStorage();
        if (address($._ruleEngine) != address(0)) {
            return _validateTransfer(from, to, amount);
        }
        return true;
    }


    /*//////////////////////////////////////////////////////////////
                            INTERNAL/PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function _validateTransferByModule(
        address from,
        address to,
        uint256 /*amount*/
    ) internal view returns (bool) {
        if (paused() || frozen(from) || frozen(to)) {
            return false;
        }
        return true;
    }

    function _operateOnTransfer(address from, address to, uint256 amount) override internal returns (bool){
        if (!_validateTransferByModule(from, to, amount)){
            return false;
        }
        ValidationModuleInternalStorage storage $ = _getValidationModuleInternalStorage();
        if (address($._ruleEngine) != address(0)) {
            return ValidationModuleInternal._operateOnTransfer(from, to, amount);
        }
        return true;
    }
}