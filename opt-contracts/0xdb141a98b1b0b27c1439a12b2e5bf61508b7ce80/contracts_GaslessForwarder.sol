// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.7.6;
pragma abicoder v2;

import "./openzeppelin_contracts_math_SafeMath.sol";
import "./openzeppelin_contracts_cryptography_ECDSA.sol";

import "./contracts_interfaces_IForwarder.sol";

import "./contracts_lib_LibERC20Adapter.sol";

contract GaslessForwarder is IForwarder {

    using SafeMath for uint256;


    /// @dev controller
    address public controller;

    /// @dev relayers
    mapping(address => bool) public trustedForwarders;

    /// @dev validators
    mapping(address => bool) public validators;

    /// @dev seen message
    mapping(bytes32 => bool) public messageDelivered;

    uint256 public chainId;


    constructor() {
        controller = msg.sender;

        uint256 _chainId;
        assembly {
            _chainId := chainid()
        }
        chainId = _chainId;
    }


    function changeChainId() public { 
        isAuthorizedController();

        uint256 _chainId;
        assembly {
            _chainId := chainid()
        }
        chainId = _chainId;
    }


    function executeCall(
        ForwardRequest calldata request,
        bytes calldata validatorSignature
    ) external override payable {

        uint256 initialGas = gasleft();

        require(validators[request.validator], 'GF_VAUTH');
        require(request.validTo == 0 || block.timestamp + 20 <= request.validTo, 'GF_VD');

        address sender = _msgSender();  // trusted forwader 
        bytes32 digest = keccak256(abi.encodePacked(
                    chainId,
                    sender,
                    this,
                    request.validator,
                    request.paymentToken,
                    request.paymentFees,
                    request.tokenGasPrice,
                    request.validTo,
                    request.nonce,
                    request.targetAddress,
                    request.data
                )
            );

        address signer = ECDSA.recover(
            ECDSA.toEthSignedMessageHash(digest), validatorSignature
        );

        require(signer != address(0) && signer == request.validator, 'GF_NV');
        require(!messageDelivered[digest], 'GF_MD');
        messageDelivered[digest] = true;

        (bool success, bytes memory result) = request.targetAddress.call{ value: msg.value }(
            abi.encodePacked(request.data, sender)
        );
        if (!success) {
            // Next 5 lines from https://ethereum.stackexchange.com/a/83577
            if (result.length < 68) revert();
            assembly {
                result := add(result, 0x04)
            }
            revert(abi.decode(result, (string)));
        }

        // check payment fees validity
        require(request.tokenGasPrice.mul(initialGas.sub(gasleft())) <= request.paymentFees, 'GF_OC');
    }

    function isTrustedForwarder(address forwarder) internal view returns(bool) {
        return trustedForwarders[forwarder];
    }

    function _msgSender() internal virtual view returns (address payable ret) {
        if (msg.data.length >= 24 && isTrustedForwarder(msg.sender)) {
            // At this point we know that the sender is a trusted forwarder,
            // so we trust that the last bytes of msg.data are the verified sender address.
            // extract sender address from the end of msg.data
            assembly {
                ret := shr(96,calldataload(sub(calldatasize(),20)))
            }
        } else {
            return msg.sender;
        }
    }

    function toggleForwarder(address _forwarder, bool _toggle) external {
        isAuthorizedController();
        trustedForwarders[_forwarder] = _toggle;
    }

    function changeController(address _controller) external {
        isAuthorizedController();
        require(address(0) != _controller, 'Address is address(0)');

        controller = _controller;
    }

    function toggleValidator(address _validator, bool _toggle) external {
        isAuthorizedController();
        validators[_validator] = _toggle;
    }

    function versionRecipient() external pure returns (string memory) {
        return "1";
    }

    function isAuthorizedController() internal view {
        require(msg.sender == controller, "KR_AC");
    }
}