// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20Permit} from "./openzeppelin_contracts_token_ERC20_extensions_ERC20Permit.sol";
import {IERC20} from "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import {DataTypes} from "./majora-finance_libraries_contracts_DataTypes.sol";
import {IPermit2} from "./majora-finance_libraries_contracts_interfaces_IPermit2.sol";
import "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";

/**
 * @title LibPermit
 * @author Majora Development Association
 * @notice A library to handle permit usage.
 */
library LibPermit {
    using SafeERC20 for IERC20;

    /**
     * @dev execute a transfer with permit or permit2
     * @param _permit2 permit2 contract address
     * @param _asset asset address
     * @param _from departure address
     * @param _to arrival address
     * @param _amount amount of token to transfer
     * @param _permitParams encoded permit parameters
     */
    function executeTransfer(
        address _permit2,
        address _asset, 
        address _from, 
        address _to, 
        uint256 _amount, 
        bytes memory _permitParams
    ) internal {

        DataTypes.PermitParameters memory p = abi.decode(_permitParams, (DataTypes.PermitParameters));

        if(p.permitType == DataTypes.PermitType.PERMIT) {
            executePermit(_asset, _from, _to, _amount, p.parameters);
            IERC20(_asset).safeTransferFrom(_from, _to, _amount);
        }

        if(p.permitType == DataTypes.PermitType.PERMIT2) {
            executeTransferFromPermit2( _permit2, _asset, _from,  _to, _amount, p.parameters);
        }
    }

    /**
     * @dev execute a permit allowance
     * @param _asset asset address
     * @param _from user address who signed the typed message
     * @param _to user address who signed the typed message
     * @param _amount amount of token to transfer
     * @param _permitParams encoded permit parameters
     */
    function executePermit(address _asset, address _from, address _to, uint256 _amount, bytes memory _permitParams) internal {
        DataTypes.PermitParams memory p = abi.decode(_permitParams, (DataTypes.PermitParams));
        try ERC20Permit(_asset).permit(_from, _to, _amount, p.deadline, p.v, p.r, p.s) {} catch {}
    }

    /**
     * @dev execute a permit2 transfer from
     * @param _permit2 permit2 contract address
     * @param _asset asset address
     * @param _from departure address
     * @param _to arrival address
     * @param _amount amount of token to transfer
     * @param _permitParams encoded permit parameters
     */
    function executeTransferFromPermit2(
        address _permit2,
        address _asset, 
        address _from, 
        address _to, 
        uint256 _amount, 
        bytes memory _permitParams
    ) internal {
        DataTypes.Permit2Params memory p = abi.decode(_permitParams, (DataTypes.Permit2Params));

        IPermit2(_permit2).permitTransferFrom(
            // The permit message.
            IPermit2.PermitTransferFrom({
                permitted: IPermit2.TokenPermissions({
                    token: IERC20(_asset),
                    amount: _amount
                }),
                nonce: p.nonce,
                deadline: p.deadline
            }),
            // The transfer recipient and amount.
            IPermit2.SignatureTransferDetails({
                to: _to,
                requestedAmount: _amount
            }),
            // The owner of the tokens, which must also be
            // the signer of the message, otherwise this call
            // will fail.
            _from,
            // The packed signature that was the result of signing
            // the EIP712 hash of `permit`.
            p.signature
        );
    }
}