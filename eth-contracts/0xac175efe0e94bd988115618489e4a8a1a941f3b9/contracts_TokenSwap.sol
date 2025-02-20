//SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import "./openzeppelin_contracts-upgradeable_token_ERC20_IERC20Upgradeable.sol";
import "./openzeppelin_contracts-upgradeable_access_OwnableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";
import "./openzeppelin_contracts-upgradeable_proxy_utils_UUPSUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_security_ReentrancyGuardUpgradeable.sol";
import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";



/**
* @title TokenSwap
* @dev Contract to swap USDC for Peaw tokens at a fixed rate
*/

contract TokenSwap is Initializable, OwnableUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable {

    using SafeERC20 for IERC20;

    
    uint256 public swapRate; //Swap rate (default 5 peaq per 1 usdc)
    IERC20Upgradeable public usdc; // USDC token contract
    uint256 public precisionFactor;

    /**
     * @dev Emitted when a swap occurs.
     * @param user The address performing the swap.
     * @param usdcAmount The amount of USDC swapped.
     * @param peaqAmount The amount of Peaq tokens received.
     */
    event Swapped(address indexed user, uint256 usdcAmount, uint256 peaqAmount);

    /**
     * @dev Emitted when the USDC contract address is updated.
     * @param newAddress The new USDC contract address.
     */
    event UsdcAddressUpdate(address indexed newAddress);

    /**
     * @dev Emitted when the swap rate is updated.
     * @param newSwapRate The new swap rate.
     */
    event SwapRateUpdate(uint256 newSwapRate);

    /**
     * @dev Emitted when tokens are withdrawn from the contract.
     * @param account The address performing the withdrawal.
     * @param token The address of the token being withdrawn.
     * @param amount The amount of tokens withdrawn.
     */
    event TokenWithdraw(address indexed account, address indexed token, uint256 amount);

    event UpdatePrecisionFactor(address indexed owner, uint256 precision);

    /**
     * @dev Initializes the contract with the USDC address and swap rate.
     * @param _usdc The address of the USDC token contract.
     * @param _swapRate The initial swap rate (e.g., 5 for 1 USDC = 5 Peaq).
     */
    function initialize(address _usdc, uint256 _swapRate) public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        usdc = IERC20Upgradeable(_usdc);
        swapRate = _swapRate; //Default swap rate: 1 USDC = 5 Peaq
    }

    /**
     * @dev Authorizes the upgrade of the contract implementation.
     * @param newImplementation The address of the new implementation.
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner{}

   /** 
    * @dev Swaps USDC for Peaq tokens at a fixed rate.
    * @param amount The amount of USDC to swap.
    * @notice The amount must be greater than 0.
    */
    function swap(uint256 amount) external nonReentrant{
        require(amount>0, "Amount must be greater than 0");

        //Calculate amount of Peaq tokens
        uint256 peaqAmount = (amount * swapRate) / precisionFactor;

        //Transfer USDC from user to contract
        usdc.transferFrom(msg.sender, address(this), amount);

        //Emit the swap event with details of the transaction
        emit Swapped(msg.sender, amount, peaqAmount);
    }

    /**
     * @dev Allows the owner to update the swap rate.
     * @param newRate The new swap rate (e.g., 5 for 1 USDC = 5 Peaq tokens).
     * @notice The new rate must be greater than 0.
     */
    function updateSwapRate(uint256 newRate) external onlyOwner {
        require(newRate > 0, "Swap rate must be greater than 0");
        swapRate = newRate;
        
        //Emit the SwapRateUpdate
        emit SwapRateUpdate(newRate);
    }

    /**
     * @dev Allows the owner to update the USDC token address.
     * @param newUsdcAddress The new address of the USDC token contract.
     * @notice The new address cannot be the zero address.
     */
    function updateUsdcAddress(address newUsdcAddress) external onlyOwner {
        require(newUsdcAddress != address(0), "New USDC address cannot be zero address");
        usdc = IERC20Upgradeable(newUsdcAddress);
        emit UsdcAddressUpdate(newUsdcAddress);
    }

    /**
     * @dev Allows the owner to withdraw tokens from the contract.
     * @param _tokenContract The address of the token to withdraw.
     * @param amount The amount of tokens to withdraw.
     * @notice The token contract address cannot be the zero address.
     */
    function withdrawToken(
        address _tokenContract,
        uint256 amount
    )external onlyOwner nonReentrant {
        require(_tokenContract != address(0), "Address cant be zero address");
        IERC20 tokenContract = IERC20(_tokenContract);
        tokenContract.safeTransfer(msg.sender, amount);

        emit TokenWithdraw(_tokenContract, msg.sender, amount);
    }

    /**
     * @dev Disables the renouncement of ownership.
     * @notice This function cannot be called.
     */   
    function renounceOwnership() public view override onlyOwner {
        revert("Renouncing ownership is disabled.");
    }

    /**
     * @notice Updates the precision factor used in calculations.
     * @dev This function is restricted to the owner of the contract. 
     *      Ensure the provided precision factor is appropriate for the use case.
     * @param _precision The new precision factor to be set.
     * @custom:access Only callable by the contract owner.
     * @custom:emit Emits an {UpdatePrecisionFactor} event upon successful execution.
     */
    function updaatePrecisionFactor(uint256 _precision) external onlyOwner {
        precisionFactor = _precision;
        emit UpdatePrecisionFactor(msg.sender, _precision);
    }
}