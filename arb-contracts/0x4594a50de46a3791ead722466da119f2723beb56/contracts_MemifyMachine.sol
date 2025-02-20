// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import './openzeppelin_contracts_token_ERC20_IERC20.sol';
import './openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol';
import './openzeppelin_contracts_access_Ownable.sol';
import './openzeppelin_contracts_security_ReentrancyGuard.sol';
import './contracts_MemeToken.sol';

/// @title MemifyMachine
/// @notice A contract for minting and burning meme tokens based on a base token.
/// @dev Supports both ERC20 tokens and native cryptocurrency (e.g., ETH).
contract MemifyMachine is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Address of the base token (ERC20 or native token). `address(0)` indicates native currency (e.g., ETH).
    address public baseToken;

    /// @notice Address of the MemeToken contract deployed by this MemifyMachine.
    address public memeToken;

    /// @notice Conversion ratio between the base token and the meme token.
    uint256 public conversionRatio;

    /// @notice Address of the treasury to collect fees from token swaps.
    address public treasury;

    /// @notice Fee percentage (in basis points) applied to swaps (minting and burning).
    uint256 public swapFee;

    /// @notice Emitted when a new MemifyMachine is created.
    /// @param creator Address of the creator/owner of the MemifyMachine.
    /// @param baseToken Address of the base token used in the MemifyMachine.
    /// @param memeToken Address of the deployed MemeToken contract.
    /// @param conversionRatio Conversion ratio between base token and meme token.
    /// @param isVerified Indicates whether the machine is verified (always true in this implementation).
    event MachineInfo(
        address indexed creator,
        address indexed baseToken,
        address indexed memeToken,
        uint256 conversionRatio,
        bool isVerified
    );

    /// @notice Emitted when meme tokens are minted.
    /// @param machine Address of the MemifyMachine.
    /// @param user Address of the user minting the meme tokens.
    /// @param baseTokenAmount Amount of base tokens used for minting.
    /// @param memeTokenAmount Amount of meme tokens minted (after fees).
    /// @param feeAmount Fee amount deducted in meme tokens.
    event MemeTokenMinted(
        address indexed machine,
        address indexed user,
        uint256 baseTokenAmount,
        uint256 memeTokenAmount,
        uint256 feeAmount
    );

    /// @notice Emitted when meme tokens are burned.
    /// @param machine Address of the MemifyMachine.
    /// @param user Address of the user burning the meme tokens.
    /// @param baseTokenAmount Amount of base tokens returned to the user.
    /// @param memeTokenAmount Amount of meme tokens burned.
    /// @param feeAmount Fee amount deducted in meme tokens.
    event MemeTokenBurned(
        address indexed machine,
        address indexed user,
        uint256 baseTokenAmount,
        uint256 memeTokenAmount,
        uint256 feeAmount
    );

    /// @notice Constructor to initialize the MemifyMachine.
    /// @param _baseToken Address of the base token (use `address(0)` for native currency).
    /// @param _name Name of the MemeToken.
    /// @param _symbol Symbol of the MemeToken.
    /// @param _conversionRatio Conversion ratio between base token and meme token.
    /// @param _creator Address of the creator/owner of the MemifyMachine.
    /// @param _treasury Address of the treasury to collect fees.
    /// @param _swapFee Fee percentage (in basis points) applied to swaps.
    constructor(
        address _baseToken,
        string memory _name,
        string memory _symbol,
        uint256 _conversionRatio,
        address _creator,
        address _treasury,
        uint256 _swapFee
    ) {
        baseToken = _baseToken;
        conversionRatio = _conversionRatio;
        treasury = _treasury;
        swapFee = _swapFee;

        // Deploy a new MemeToken contract and set its address.
        MemeToken memeTokenContract = new MemeToken(_name, _symbol, address(this));
        memeToken = address(memeTokenContract);

        // Transfer ownership of the MemifyMachine to the creator.
        transferOwnership(_creator);

        // Emit an event to signify the creation of the MemifyMachine.
        emit MachineInfo(_creator, _baseToken, address(memeToken), _conversionRatio, true);
    }

    /// @notice Mints meme tokens by depositing base tokens or native currency.
    /// @param _memeTokenAmount Desired amount of meme tokens to mint.
    function mint(uint256 _memeTokenAmount) external payable nonReentrant {
        // Ensure a valid amount is provided.
        require(_memeTokenAmount > 0, 'Amount must be greater than zero');

        // Calculate the required base token amount and the fee.
        uint256 baseTokenAmount = _memeTokenAmount / conversionRatio;
        uint256 fee = (_memeTokenAmount * swapFee) / 10000;

        // Check if the user has sent enough native currency (ETH) if baseToken is address(0).
        if (baseToken == address(0)) {
            require(msg.value >= baseTokenAmount, 'Insufficient ETH sent');
        }

        // If the base token is an ERC20 token, transfer the required amount from the user.
        if (baseToken != address(0)) {
            IERC20(baseToken).safeTransferFrom(msg.sender, address(this), baseTokenAmount);
        }

        // Mint the net meme tokens (after deducting fees) to the user.
        MemeToken(memeToken).mint(msg.sender, _memeTokenAmount - fee);

        // Mint the fee amount of meme tokens to the treasury.
        MemeToken(memeToken).mint(treasury, fee);

        // Emit an event for the minting operation.
        emit MemeTokenMinted(address(this), msg.sender, baseTokenAmount, _memeTokenAmount - fee, fee);
    }

    /// @notice Burns meme tokens to redeem base tokens or native currency.
    /// @param _memeTokenAmount Amount of meme tokens to burn.
    function burn(uint256 _memeTokenAmount) external nonReentrant {
        // Ensure a valid amount is provided.
        require(_memeTokenAmount > 0, 'Amount must be greater than zero');

        uint256 fee;

        if (msg.sender != treasury) {
            fee = (_memeTokenAmount * swapFee) / 10000;

            // Transfer the fee amount of meme tokens to the treasury.
            IERC20(memeToken).safeTransferFrom(msg.sender, treasury, fee);
        }

        // Burn the net meme tokens (after fees) from the user.
        MemeToken(memeToken).burnFrom(msg.sender, _memeTokenAmount - fee);

        uint256 baseTokenAmount = (_memeTokenAmount - fee) / conversionRatio;

        // If the base token is native currency (e.g., ETH), transfer it to the user.
        if (baseToken == address(0)) {
            (bool success, ) = payable(msg.sender).call{ value: baseTokenAmount }('');
            require(success, 'Failed to send ETH');
        } else {
            // Transfer the base tokens to the user.
            IERC20(baseToken).safeTransfer(msg.sender, baseTokenAmount);
        }

        // Emit an event for the burning operation.
        emit MemeTokenBurned(address(this), msg.sender, baseTokenAmount, _memeTokenAmount, fee);
    }

    /// @notice Updates the conversion ratio between base tokens and meme tokens.
    /// @dev Can only be called by the owner of the MemifyMachine.
    /// @param _newRatio New conversion ratio.
    function setConversionRatio(uint256 _newRatio) external onlyOwner {
        conversionRatio = _newRatio;
    }

    /// @notice Fallback function to receive Ether.
    /// @dev Allows the contract to receive native currency (e.g., ETH) directly.
    receive() external payable {}
}