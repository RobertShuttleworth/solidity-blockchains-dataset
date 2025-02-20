// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
import {MailboxClient} from "./contracts_client_MailboxClient.sol";
import {IPostDispatchHook} from "./contracts_interfaces_hooks_IPostDispatchHook.sol";
import {Message} from "./contracts_libs_Message.sol";
import {TokenMessage} from "./contracts_token_libs_TokenMessage.sol";
import {RateLimited} from "./contracts_libs_RateLimited.sol";

contract RateLimitedHook is IPostDispatchHook, MailboxClient, RateLimited {
    using Message for bytes;
    using TokenMessage for bytes;

    mapping(bytes32 messageId => bool validated) public messageValidated;

    modifier validateMessageOnce(bytes calldata _message) {
        bytes32 messageId = _message.id();
        require(!messageValidated[messageId], "MessageAlreadyValidated");
        _;
        messageValidated[messageId] = true;
    }

    constructor(
        address _mailbox,
        uint256 _maxCapacity
    ) MailboxClient(_mailbox) RateLimited(_maxCapacity) {}

    /// @inheritdoc IPostDispatchHook
    function hookType() external pure returns (uint8) {
        return uint8(IPostDispatchHook.Types.Rate_Limited_Hook);
    }

    /// @inheritdoc IPostDispatchHook
    function supportsMetadata(bytes calldata) external pure returns (bool) {
        return false;
    }

    /**
     * Verify a message, rate limit, and increment the sender's limit.
     * @dev ensures that this gets called by the Mailbox
     */
    function postDispatch(
        bytes calldata,
        bytes calldata _message
    ) external payable validateMessageOnce(_message) {
        require(_isLatestDispatched(_message.id()), "InvalidDispatchedMessage");

        uint256 newAmount = _message.body().amount();
        validateAndConsumeFilledLevel(newAmount);
    }

    /// @inheritdoc IPostDispatchHook
    function quoteDispatch(
        bytes calldata,
        bytes calldata
    ) external pure returns (uint256) {
        return 0;
    }
}