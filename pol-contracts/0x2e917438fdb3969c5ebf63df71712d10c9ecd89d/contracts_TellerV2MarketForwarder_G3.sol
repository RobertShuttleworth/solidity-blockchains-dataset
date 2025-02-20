pragma solidity >=0.8.0 <0.9.0;
// SPDX-License-Identifier: MIT

import "./contracts_interfaces_ITellerV2.sol";

import "./contracts_interfaces_IMarketRegistry.sol";
import "./contracts_interfaces_ITellerV2MarketForwarder.sol";
import "./contracts_interfaces_ILoanRepaymentCallbacks.sol";

import "./contracts_TellerV2MarketForwarder_G2.sol";

import "./openzeppelin_contracts-upgradeable_utils_AddressUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC20_IERC20Upgradeable.sol";

import "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";

import "./openzeppelin_contracts-upgradeable_utils_ContextUpgradeable.sol";

/**
 * @dev Simple helper contract to forward an encoded function call to the TellerV2 contract. See {TellerV2Context}
 */
abstract contract TellerV2MarketForwarder_G3 is TellerV2MarketForwarder_G2 {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address _protocolAddress, address _marketRegistryAddress)
        TellerV2MarketForwarder_G2(_protocolAddress, _marketRegistryAddress)
    {}

    /**
     * @notice Accepts a new loan using the TellerV2 lending protocol.
     * @param _bidId The id of the new loan.
     * @param _lender The address of the lender who will provide funds for the new loan.
     */
    function _acceptBidWithRepaymentListener(
        uint256 _bidId,
        address _lender,
        address _listener
    ) internal virtual returns (bool) {
        // Approve the borrower's loan
        _forwardCall(
            abi.encodeWithSelector(ITellerV2.lenderAcceptBid.selector, _bidId),
            _lender
        );

        _forwardCall(
            abi.encodeWithSelector(
                ILoanRepaymentCallbacks.setRepaymentListenerForBid.selector,
                _bidId,
                _listener
            ),
            _lender
        );

        //ITellerV2(getTellerV2()).setRepaymentListenerForBid(_bidId, _listener);

        return true;
    }

    //a gap is inherited from g2  so this is actually not necessary going forwards ---leaving it to maintain upgradeability
    uint256[50] private __gap;
}