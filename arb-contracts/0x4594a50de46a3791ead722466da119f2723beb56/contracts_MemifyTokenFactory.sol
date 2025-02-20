// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import './openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol';
import './openzeppelin_contracts-upgradeable_access_OwnableUpgradeable.sol';
import './openzeppelin_contracts-upgradeable_security_ReentrancyGuardUpgradeable.sol';
import './openzeppelin_contracts-upgradeable_security_PausableUpgradeable.sol';
import './contracts_interfaces_IERC20Decimals.sol';
import './contracts_interfaces_IMemifyMachine.sol';
import './contracts_MemifyMachine.sol';

/// @title MemifyTokenFactory
/// @notice Factory contract to create and manage MemifyMachine instances.
contract MemifyTokenFactory is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable {
    /// @notice Emitted when a new MemifyMachine is created.
    /// @param creator Address of the creator/owner of the MemifyMachine.
    /// @param baseToken Address of the base token used in the MemifyMachine.
    /// @param memifyMachine Address of the deployed MemifyMachine contract.
    /// @param conversionRatio Conversion ratio between base token and meme token.
    event MemifyMachineCreated(
        address indexed creator,
        address indexed baseToken,
        address indexed memifyMachine,
        uint256 conversionRatio
    );

    /// @notice Address of the treasury where fees will be sent.
    address public treasury;

    /// @notice Fee required to create a new MemifyMachine, denominated in USD (converted from ETH).
    uint256 public creationFee;

    /// @notice Fee percentage (in basis points) for token swaps in MemifyMachine contracts.
    uint256 public swapFee;

    mapping(address => bool) public isMemeToken;

    /// @dev Initializes the contract with the specified parameters.
    /// @param _treasury Address of the treasury to receive fees.
    /// @param _creationFee Fee (in USD, converted from ETH) required for creating a new MemifyMachine.
    /// @param _swapFee Fee percentage (in basis points) for token swaps.
    function initialize(address _treasury, uint256 _creationFee, uint256 _swapFee) public initializer {
        // Initialize inherited OpenZeppelin contracts.
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        // Set initial values for state variables.
        treasury = _treasury;
        creationFee = _creationFee;
        swapFee = _swapFee;
    }

    /// @notice Creates a new MemifyMachine contract.
    /// @dev Requires the caller to pay the creation fee in ETH. The ETH is converted to USD using Chainlink price feed.
    /// @param _baseToken Address of the base token for the MemifyMachine (use `address(0)` for native ETH).
    /// @param _name Name of the MemifyMachine token.
    /// @param _symbol Symbol of the MemifyMachine token.
    /// @param _ratio Conversion ratio between base token and MemifyMachine token.
    /// @return Address of the newly created MemifyMachine contract.
    function createMemifyMachine(
        address _baseToken,
        string memory _name,
        string memory _symbol,
        uint256 _ratio
    ) external payable whenNotPaused nonReentrant returns (address) {
        // Ensure the conversion ratio is valid.
        require(_ratio > 0, 'Invalid conversion ratio');

        // Ensure the ETH sent is sufficient to cover the creation fee.
        require(msg.value >= creationFee, 'Insufficient fee');

        // Transfer the ETH fee to the treasury.
        (bool success, ) = payable(treasury).call{ value: msg.value }('');
        require(success, 'Failed');

        // Deploy a new MemifyMachine contract with the specified parameters.
        MemifyMachine newMachine = new MemifyMachine(_baseToken, _name, _symbol, _ratio, msg.sender, treasury, swapFee);

        address memeToken = IMemifyMachine(address(newMachine)).memeToken();

        isMemeToken[memeToken] = true;

        // Emit an event to signify the creation of the MemifyMachine.
        emit MemifyMachineCreated(msg.sender, _baseToken, address(newMachine), _ratio);

        // Return the address of the new MemifyMachine contract.
        return address(newMachine);
    }

    /// @notice Updates the treasury address.
    /// @dev Can only be called by the contract owner.
    /// @param _newTreasury New treasury address.
    function setTreasury(address _newTreasury) external onlyOwner {
        treasury = _newTreasury;
    }

    /// @notice Updates the creation fee.
    /// @dev Can only be called by the contract owner.
    /// @param _newCreationFee New creation fee (in USD, converted from ETH).
    function setCreationFee(uint256 _newCreationFee) external onlyOwner {
        creationFee = _newCreationFee;
    }

    /// @notice Updates the swap fee.
    /// @dev Can only be called by the contract owner.
    /// @param _newSwapFee New swap fee percentage (in basis points).
    function setSwapFee(uint256 _newSwapFee) external onlyOwner {
        swapFee = _newSwapFee;
    }

    /// @notice Pauses the contract, disabling certain functions.
    /// @dev Can only be called by the contract owner.
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpauses the contract, re-enabling certain functions.
    /// @dev Can only be called by the contract owner.
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Fallback function to receive Ether.
    /// @dev Allows the contract to receive ETH directly.
    receive() external payable {}
}