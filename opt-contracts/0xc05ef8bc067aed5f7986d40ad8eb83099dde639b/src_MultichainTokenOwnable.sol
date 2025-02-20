// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Initializable} from "./lib_openzeppelin-contracts-upgradeable_contracts_proxy_utils_Initializable.sol";
import {UUPSUpgradeable} from "./lib_openzeppelin-contracts-upgradeable_contracts_proxy_utils_UUPSUpgradeable.sol";
import {ERC20Upgradeable} from "./lib_openzeppelin-contracts-upgradeable_contracts_token_ERC20_ERC20Upgradeable.sol";
import {OwnableUpgradeable} from "./lib_openzeppelin-contracts-upgradeable_contracts_access_OwnableUpgradeable.sol";
import {IMultichainSender} from "./src_interfaces_IMultichainSender.sol";

contract MultichainTokenOwnable is Initializable, ERC20Upgradeable, UUPSUpgradeable, OwnableUpgradeable {
    event MessengerSet(address Messenger, bool allowed);
    event MetadataSet(string metadata);
    event SetLzChainEnabled(uint32 indexed chain, bool enabled);
    event MintingAllowanceSet(address indexed minter, uint256 allowance);

    error InvalidMessenger();
    error InvalidFee();
    error InvalidChain();

    /// @notice Mapping of allowed messengers. These are accounts that will relay cross-chain messages.
    mapping(address messenger => bool allowed) public messengers;

    /// @notice Allowance for minting tokens. This is useful for allowing a specific account to mint tokens.
    mapping(address minter => uint256 mintingAllowance) public mintingAllowance;

    /// @notice Token metadata.
    string public tokenMetadata;

    function initialize(
        string memory name,
        string memory symbol,
        address owner,
        address messenger,
        string memory _tokenMetadata
    ) public initializer {
        __ERC20_init(name, symbol);
        __Ownable_init(owner);
        __UUPSUpgradeable_init();
        messengers[messenger] = true;
        emit MessengerSet(messenger, true);
        tokenMetadata = _tokenMetadata;
        emit MetadataSet(_tokenMetadata);
    }

    /// @notice Gives a quote for a LZ call to set the token metadata.
    function quoteSetTokenMetadata(
        address messenger,
        uint32[] memory destinations,
        string memory metadata,
        bytes[] memory options
    ) public view returns (uint256[] memory fees, uint256 totalFee) {
        if (!messengers[messenger]) revert InvalidMessenger();
        bytes memory callData = abi.encodeWithSelector(this.setTokenMetadataLocally.selector, metadata);
        (fees, totalFee) = IMultichainSender(messenger).quoteCall(destinations, callData, options);
    }

    /// @notice Gives a quote for a LZ call to bridge tokens.
    function quoteSend(address messenger, uint32 destination, uint256 amount, bytes memory option)
        public
        view
        returns (uint256 fee)
    {
        if (!messengers[messenger]) revert InvalidMessenger();
        uint32[] memory destinations = new uint32[](1);
        destinations[0] = destination;
        bytes[] memory options = new bytes[](1);
        options[0] = option;
        bytes memory callData = abi.encodeWithSelector(this.receiveTokens.selector, msg.sender, amount);
        (, fee) = IMultichainSender(messenger).quoteCall(destinations, callData, options);
    }

    /// @notice Bridge tokens.
    function sendTokens(address messenger, uint32 destination, uint256 amount, bytes memory option, uint256 fee)
        public
        payable
    {
        if (fee != msg.value) revert InvalidFee();
        if (!messengers[messenger]) revert InvalidMessenger();
        _burn(msg.sender, amount);
        uint32[] memory destinations = new uint32[](1);
        destinations[0] = destination;
        bytes[] memory options = new bytes[](1);
        options[0] = option;
        uint256[] memory fees = new uint256[](1);
        fees[0] = fee;
        bytes memory callData = abi.encodeWithSelector(this.receiveTokens.selector, msg.sender, amount);
        IMultichainSender(messenger).transmitCallMessage{value: msg.value}(
            destinations, callData, options, fees, payable(msg.sender), false
        );
    }

    /// @notice Mint tokens when bridging.
    function receiveTokens(address to, uint256 amount) public {
        require(messengers[msg.sender], "MultichainToken: messenger not allowed");
        _mint(to, amount);
    }

    /// @notice Enables or disables bridging to a specific chains.
    function setTokenMetadata(
        address messenger,
        uint32[] memory destinations,
        string memory metadata,
        bytes[] memory options,
        uint256[] memory fees
    ) public payable onlyOwner {
        if (!messengers[messenger]) revert InvalidMessenger();
        bytes memory callData = abi.encodeWithSelector(this.setTokenMetadataLocally.selector, metadata);
        IMultichainSender(messenger).transmitCallMessage{value: msg.value}(
            destinations, callData, options, fees, payable(msg.sender), true
        );
    }

    /// @notice Sets tokenMetadata locally.
    function setTokenMetadataLocally(string memory metadata) public {
        if (msg.sender != owner() && !messengers[msg.sender]) revert InvalidMessenger();
        tokenMetadata = metadata;
        emit MetadataSet(metadata);
    }

    /// @notice Sets allowed messengers.
    function setMessenger(address messenger, bool allowed) public onlyOwner {
        messengers[messenger] = allowed;
        emit MessengerSet(messenger, allowed);
    }

    /// @notice Allows only the owner to upgrade the contract.
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /// @notice Sets minting allowance for a specific account.
    function setMintingAllowance(address minter, uint256 amount) public onlyOwner {
        mintingAllowance[minter] = amount;
        emit MintingAllowanceSet(minter, amount);
    }

    /// @notice Mints tokens to the specified address. Callable by the owner or by an account with minting allowance.
    function mint(address to, uint256 amount) public {
        if (msg.sender != owner()) {
            require(mintingAllowance[msg.sender] >= amount, "MultichainToken: minting allowance exceeded");
            mintingAllowance[msg.sender] -= amount;
        }
        _mint(to, amount);
    }
}