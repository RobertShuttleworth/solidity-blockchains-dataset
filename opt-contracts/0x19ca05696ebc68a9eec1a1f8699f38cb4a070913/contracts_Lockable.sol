// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 * @title A contract that provides modifiers to prevent reentrancy to state-changing and view-only methods. This contract
 * is inspired by https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/ReentrancyGuard.sol
 * and https://github.com/balancer-labs/balancer-core/blob/master/contracts/BPool.sol.
 * @dev The reason why we use this local contract instead of importing from uma/contracts is because of the addition
 * of the internal method `functionCallStackOriginatesFromOutsideThisContract` which doesn't exist in the one exported
 * by uma/contracts.
 * @custom:security-contact bugs@across.to
 */
contract Lockable {
    bool internal _notEntered;

    constructor() {
        // Storing an initial non-zero value makes deployment a bit more expensive, but in exchange the refund on every
        // call to nonReentrant will be lower in amount. Since refunds are capped to a percentage of the total
        // transaction's gas, it is best to keep them low in cases like this one, to increase the likelihood of the full
        // refund coming into effect.
        _notEntered = true;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a nonReentrant function from another nonReentrant function is not supported. It is possible to
     * prevent this from happening by making the nonReentrant function external, and making it call a private
     * function that does the actual state modification.
     */
    modifier nonReentrant() {
        _preEntranceCheck();
        _preEntranceSet();
        _;
        _postEntranceReset();
    }

    /**
     * @dev Designed to prevent a view-only method from being re-entered during a call to a nonReentrant() state-changing method.
     */
    modifier nonReentrantView() {
        _preEntranceCheck();
        _;
    }

    /**
     * @dev Returns true if the contract is currently in a non-entered state, meaning that the origination of the call
     * came from outside the contract. This is relevant with fallback/receive methods to see if the call came from ETH
     * being dropped onto the contract externally or due to ETH dropped on the contract from within a method in this
     * contract, such as unwrapping WETH to ETH within the contract.
     */
    function functionCallStackOriginatesFromOutsideThisContract() internal view returns (bool) {
        return _notEntered;
    }

    // Internal methods are used to avoid copying the require statement's bytecode to every nonReentrant() method.
    // On entry into a function, _preEntranceCheck() should always be called to check if the function is being
    // re-entered. Then, if the function modifies state, it should call _postEntranceSet(), perform its logic, and
    // then call _postEntranceReset().
    // View-only methods can simply call _preEntranceCheck() to make sure that it is not being re-entered.
    function _preEntranceCheck() internal view {
        // On the first call to nonReentrant, _notEntered will be true
        require(_notEntered, "ReentrancyGuard: reentrant call");
    }

    function _preEntranceSet() internal {
        // Any calls to nonReentrant after this point will fail
        _notEntered = false;
    }

    function _postEntranceReset() internal {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _notEntered = true;
    }
}