// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.11;

// ============ Internal Imports ============
import {IMailbox} from "./contracts_interfaces_IMailbox.sol";
import {IPostDispatchHook} from "./contracts_interfaces_hooks_IPostDispatchHook.sol";
import {IInterchainSecurityModule} from "./contracts_interfaces_IInterchainSecurityModule.sol";
import {Message} from "./contracts_libs_Message.sol";

// ============ External Imports ============
import {Address} from "./openzeppelin_contracts_utils_Address.sol";
import {OwnableUpgradeable} from "./openzeppelin_contracts-upgradeable_access_OwnableUpgradeable.sol";

abstract contract MailboxClient is OwnableUpgradeable {
    using Message for bytes;

    IMailbox public immutable mailbox;

    uint32 public immutable localDomain;

    IPostDispatchHook public hook;

    IInterchainSecurityModule public interchainSecurityModule;

    uint256[48] private __GAP; // gap for upgrade safety

    // ============ Modifiers ============
    modifier onlyContract(address _contract) {
        require(
            Address.isContract(_contract),
            "MailboxClient: invalid mailbox"
        );
        _;
    }

    modifier onlyContractOrNull(address _contract) {
        require(
            Address.isContract(_contract) || _contract == address(0),
            "MailboxClient: invalid contract setting"
        );
        _;
    }

    /**
     * @notice Only accept messages from an Hyperlane Mailbox contract
     */
    modifier onlyMailbox() {
        require(
            msg.sender == address(mailbox),
            "MailboxClient: sender not mailbox"
        );
        _;
    }

    constructor(address _mailbox) onlyContract(_mailbox) {
        mailbox = IMailbox(_mailbox);
        localDomain = mailbox.localDomain();
        _transferOwnership(msg.sender);
    }

    /**
     * @notice Sets the address of the application's custom hook.
     * @param _hook The address of the hook contract.
     */
    function setHook(address _hook) public onlyContractOrNull(_hook) onlyOwner {
        hook = IPostDispatchHook(_hook);
    }

    /**
     * @notice Sets the address of the application's custom interchain security module.
     * @param _module The address of the interchain security module contract.
     */
    function setInterchainSecurityModule(
        address _module
    ) public onlyContractOrNull(_module) onlyOwner {
        interchainSecurityModule = IInterchainSecurityModule(_module);
    }

    // ======== Initializer =========
    function _MailboxClient_initialize(
        address _hook,
        address _interchainSecurityModule,
        address _owner
    ) internal onlyInitializing {
        __Ownable_init();
        setHook(_hook);
        setInterchainSecurityModule(_interchainSecurityModule);
        _transferOwnership(_owner);
    }

    function _isLatestDispatched(bytes32 id) internal view returns (bool) {
        return mailbox.latestDispatchedId() == id;
    }

    function _isDelivered(bytes32 id) internal view returns (bool) {
        return mailbox.delivered(id);
    }
}