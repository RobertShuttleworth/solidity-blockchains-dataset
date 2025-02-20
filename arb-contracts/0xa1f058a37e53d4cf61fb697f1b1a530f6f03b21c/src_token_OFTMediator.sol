// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Ownable} from "./openzeppelin_contracts_access_Ownable.sol";
import {IERC20Metadata, IERC20} from "./openzeppelin_contracts_token_ERC20_extensions_IERC20Metadata.sol";
import {SafeERC20} from "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";
import {OFTCore} from "./layerzerolabs_lz-evm-oapp-v2_contracts_oft_OFTCore.sol";
import {Abra} from "./src_token_Abra.sol";

/**
 * @title OFTMediator Contract (basically a non-default OFTAdapter)
 * @dev OFTMediator is a contract that can turn a regular ERC-20 token into an OFT. It's similar to the default OFTAdapter,
 * but unlike the default adapter, this mediator has to be deployed on each chain and for each respective ERC-20 token.
 * The token must trust this mediator to mint new tokens. This is done to decouple the token from the cross-chain token
 * transfer mechanism.
 */
contract OFTMediator is OFTCore {

    Abra internal immutable innerToken;

    /**
     * @dev Constructor for the OFTMediator contract.
     * @param _token The address of the ERC-20 token to be adapted.
     * @param _lzEndpoint The LayerZero endpoint address.
     * @param _delegate The delegate capable of making OApp configurations inside of the endpoint.
     */
    constructor(
        address _token,
        address _lzEndpoint,
        address _delegate
    ) 
        OFTCore(IERC20Metadata(_token).decimals(), _lzEndpoint, _delegate) 
        Ownable(_delegate)
    {
        innerToken = Abra(_token);
    }

    /**
     * @dev Retrieves the address of the underlying ERC20 implementation.
     * @return The address of the adapted ERC-20 token.
     *
     * @dev In the case of OFTMediator, address(this) and erc20 are NOT the same contract.
     */
    function token() public view returns (address) {
        return address(innerToken);
    }

    /**
     * @notice Indicates whether the OFT contract requires approval of the 'token()' to send.
     * @return requiresApproval Needs approval of the underlying token implementation.
     *
     * @dev In the case of default OFTAdapter, approval is required.
     * @dev In non-default OFTAdapter contracts with something like mint and burn privileges, it would NOT need approval.
     */
    function approvalRequired() external pure virtual returns (bool) {
        return true;
    }

    function removeDust(uint256 _amountLD) external view returns (uint256 amountLD) {
        return _removeDust(_amountLD);
    }

    /**
     * @dev Burns tokens from the sender's specified balance, ie. pull method.
     * @param _from The address to debit from.
     * @param _amountLD The amount of tokens to send in local decimals.
     * @param _minAmountLD The minimum amount to send in local decimals.
     * @param _dstEid The destination chain ID.
     * @return amountSentLD The amount sent in local decimals.
     * @return amountReceivedLD The amount received in local decimals on the remote.
     *
     * @dev msg.sender will need to approve this _amountLD of tokens to be locked inside of the contract.
     * @dev WARNING: The default OFTAdapter implementation assumes LOSSLESS transfers, ie. 1 token in, 1 token out.
     * IF the 'innerToken' applies something like a transfer fee, the default will NOT work...
     * a pre/post balance check will need to be done to calculate the amountReceivedLD.
     */
    function _debit(
        address _from,
        uint256 _amountLD,
        uint256 _minAmountLD,
        uint32 _dstEid
    ) internal virtual override returns (uint256 amountSentLD, uint256 amountReceivedLD) {
        (amountSentLD, amountReceivedLD) = _debitView(_amountLD, _minAmountLD, _dstEid);
        // @dev Lock tokens by moving them into this contract from the caller.
        innerToken.transferFrom(_from, address(this), amountSentLD);
        innerToken.burn(amountSentLD);
    }

    /**
     * @dev Credits tokens to the specified address.
     * @param _to The address to credit the tokens to.
     * @param _amountLD The amount of tokens to credit in local decimals.
     * @dev _srcEid The source chain ID.
     * @return amountReceivedLD The amount of tokens ACTUALLY received in local decimals.
     *
     * @dev WARNING: The default OFTAdapter implementation assumes LOSSLESS transfers, ie. 1 token in, 1 token out.
     * IF the 'innerToken' applies something like a transfer fee, the default will NOT work...
     * a pre/post balance check will need to be done to calculate the amountReceivedLD.
     */
    function _credit(
        address _to,
        uint256 _amountLD,
        uint32 /*_srcEid*/
    ) internal virtual override returns (uint256 amountReceivedLD) {
        // @dev Mint new tokens to the recipient. Inner token must trust this adapter to mint new tokens.
        innerToken.mint(_to, _amountLD);
        // @dev In the case of NON-default OFTAdapter, the amountLD MIGHT not be == amountReceivedLD.
        return _amountLD;
    }
}