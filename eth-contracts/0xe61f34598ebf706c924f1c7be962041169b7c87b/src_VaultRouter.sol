//SPDX-License-Identifier: MIT
pragma solidity 0.8.26;



import { Ownable2Step, Ownable } from "./lib_openzeppelin-contracts-upgradeable_lib_openzeppelin-contracts_contracts_access_Ownable2Step.sol";
import { Pausable } from "./lib_openzeppelin-contracts-upgradeable_lib_openzeppelin-contracts_contracts_utils_Pausable.sol";
import { SafeERC20 } from "./lib_openzeppelin-contracts-upgradeable_lib_openzeppelin-contracts_contracts_token_ERC20_utils_SafeERC20.sol";
import { IERC20 } from "./lib_openzeppelin-contracts-upgradeable_lib_openzeppelin-contracts_contracts_token_ERC20_ERC20.sol";
import { WrappedDollarVault } from "./src_WrappedDollarVault.sol";
import { ERC20Permit } from "./lib_openzeppelin-contracts-upgradeable_lib_openzeppelin-contracts_contracts_token_ERC20_extensions_ERC20Permit.sol";
import { Address } from "./lib_openzeppelin-contracts-upgradeable_lib_openzeppelin-contracts_contracts_utils_Address.sol";
import { ReentrancyGuard } from "./lib_openzeppelin-contracts-upgradeable_lib_openzeppelin-contracts_contracts_utils_ReentrancyGuard.sol";

import { IUSD0ppMinter } from "./src_interfaces_IUSD0ppMinter.sol";
import { IParaSwapAugustus } from "./src_interfaces_IParaSwapAugustus.sol";
import { IParaSwapAugustusRegistry } from "./src_interfaces_IParaSwapAugustusRegistry.sol";

struct PermitParams {
    uint256 value;
    uint256 deadline;
    uint8 v;
    bytes32 r;
    bytes32 s;
}

contract VaultRouter is Ownable2Step, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Address for address payable;

    /*
     * ##########
     * # STATE #
     * ##########
     */
    WrappedDollarVault public immutable VAULT;
    IERC20 public immutable USD0PP;
    IERC20 public immutable USD0;
    IERC20 public immutable SUSDE;
    IUSD0ppMinter public immutable MINTER_USD0PP;
    IParaSwapAugustusRegistry public immutable AUGUSTUS_REGISTRY;

    /*
     * ########################
     * # EVENTS #
     * ########################
     */
    /// @notice event emitted when a user redeems shares from the vault
    event Redeem(
        address indexed user, uint256 amountSUSDe, uint256 amountUSD0pp
    );
    /// @notice event emitted when a user deposits an ERC20 token into the vault
    event Deposit(
        address indexed user, uint256 amountTokenIn, uint256 amountSUSDe
    );

    /*
     * ########################
     * # ERRORS #
     * ########################
     */
    /// @notice error thrown when permit fails
    error PermitFailed();
    /// @notice error thrown when slippage is experienced on sUSDe
    error NoSlippageAllowedForSUSDe();
    /// @notice error thrown when the balance before the swap is insufficient
    error InsufficientBalanceBeforeSwap();
    /// @notice error thrown when the amount received is insufficient
    error InsufficientAmountReceived();
    /// @notice error thrown when the augustus contract is invalid
    error InvalidAugustus();

    /*
     * ########################
     * # CONSTRUCTOR #
     * ########################
     */
    constructor(
        address _augustusRegistry,
        address _vault,
        address _owner
    )
        Ownable(_owner)
        ReentrancyGuard()
        Pausable()
    {
        SUSDE = IERC20(0x9D39A5DE30e57443BfF2A8307A4256c8797A3497);
        USD0 = IERC20(0x73A15FeD60Bf67631dC6cd7Bc5B6e8da8190aCF5);
        USD0PP = IERC20(0x35D8949372D46B7a3D5A56006AE77B215fc69bC0);
        MINTER_USD0PP =
            IUSD0ppMinter(0x35D8949372D46B7a3D5A56006AE77B215fc69bC0);
        VAULT = WrappedDollarVault(_vault);
        AUGUSTUS_REGISTRY = IParaSwapAugustusRegistry(_augustusRegistry);
        SUSDE.approve(address(VAULT), type(uint256).max);
        USD0.approve(address(MINTER_USD0PP), type(uint256).max);
    }

    /*
     * ########################
     * # OWNER #
     * ########################
     */

    /**
     * @dev Rescue ERC20 tokens mistakenly sent in, as this contract should
     * not hold any tokens.
     * @param token the token to rescue
     */
    function rescueToken(IERC20 token) external onlyOwner nonReentrant {
        token.safeTransfer(_msgSender(), token.balanceOf(address(this)));
    }

    /**
     * @dev Rescue ETH mistakenly sent in, as this contract should
     * not hold any ETH
     */
    function rescueNativeToken() external onlyOwner nonReentrant {
        payable(_msgSender()).sendValue(address(this).balance);
    }

    /// @dev Disables most contract functionality.
    function pause() external onlyOwner nonReentrant {
        _pause();
    }

    /// @dev Enables most contract functionality.
    function unpause() external onlyOwner nonReentrant {
        _unpause();
    }

    /*
     * ########################
     * # PUBLIC #
     * ########################
     */

    /// @dev Redeems shares from the vault and converts them to USD0PP.
    /// @param augustus the paraswap augustus to use for the swap
    /// @param shares the shares to redeem
    /// @param minAmountToReceive the minimum amount of USD0PP to receive
    /// @param swapData the swap data to use for the swap
    function redeem(
        IParaSwapAugustus augustus,
        uint256 shares,
        uint256 minAmountToReceive,
        bytes calldata swapData
    )
        public
        whenNotPaused
        nonReentrant
    {
        // Get initial balance to track received amount
        uint256 initialTokenOutBalance =
            IERC20(VAULT.asset()).balanceOf(address(this));

        // Redeem shares directly from vault
        uint256 amountSUSDe = VAULT.redeem(shares, address(this), msg.sender);

        // Verify received amount
        if (
            IERC20(VAULT.asset()).balanceOf(address(this))
                - initialTokenOutBalance != amountSUSDe
        ) {
            revert InsufficientAmountReceived();
        }

        // Convert sUSDe to USD0PP and send to user
        uint256 amountUSD0pp = _convertSUSDeToUSD0pp(
            augustus, amountSUSDe, minAmountToReceive, swapData
        );

        USD0PP.safeTransfer(msg.sender, amountUSD0pp);
        emit Redeem(msg.sender, amountSUSDe, amountUSD0pp);
    }

    /// @dev Deposits an ERC20 token into the vault and converts it to sUSDe.
    /// @param augustus the paraswap augustus to use for the swap
    /// @param tokenIn the token to deposit
    /// @param amountIn the amount of tokenIn to deposit
    /// @param minAmountToDeposit the minimum amount of sUSDe to receive
    /// @param swapData the swap data to use for the swap
    function deposit(
        IParaSwapAugustus augustus,
        IERC20 tokenIn,
        uint256 amountIn,
        uint256 minAmountToDeposit,
        bytes calldata swapData
    )
        public
        payable
        whenNotPaused
        nonReentrant
    {
        // Convert input token to sUSDe
        uint256 sUSDeAmount = _convertToSUSDe(
            augustus, tokenIn, amountIn, minAmountToDeposit, swapData
        );

        // Deposit directly into vault
        VAULT.deposit(sUSDeAmount, msg.sender);
        emit Deposit(msg.sender, amountIn, sUSDeAmount);
    }

    /// @dev Executes a permit, converts an ERC20 token to sUSDe,
    /// and deposits it into the vault.
    /// @param augustus the paraswap augustus to use for the swap
    /// @param tokenIn the token to deposit
    /// @param amount the amount of tokenIn to deposit
    /// @param minAmountToDeposit the minimum amount of sUSDe to receive
    /// @param swapData the swap data to use for the swap
    /// @param permitParams the permit parameters to use for the permit
    function depositWithPermit(
        IParaSwapAugustus augustus,
        IERC20 tokenIn,
        uint256 amount,
        uint256 minAmountToDeposit,
        bytes calldata swapData,
        PermitParams calldata permitParams
    )
        public
        whenNotPaused
    {
        if (tokenIn.allowance(msg.sender, address(this)) < amount) {
            _execPermit(tokenIn, msg.sender, address(this), permitParams);
        }
        deposit(augustus, tokenIn, amount, minAmountToDeposit, swapData);
    }

    /*
     * ########################
     * # INTERNAL #
     * ########################
     */

    /**
     * @notice convert any token to sUSDe
     * @param augustus the paraswap augustus to use for the swap
     * @param tokenIn the token to convert
     * @param amountIn the amount of tokenIn to convert
     * @param minAmountToReceive the minimum amount of sUSDe to receive
     * @param swapData the swap data to use for the swap
     */
    function _convertToSUSDe(
        IParaSwapAugustus augustus,
        IERC20 tokenIn,
        uint256 amountIn,
        uint256 minAmountToReceive,
        bytes calldata swapData
    )
        internal
        returns (uint256)
    {
        // Special handling for USD0PP
        if (tokenIn == USD0PP) {
            return _convertUSD0ppToSUSDe(
                augustus, amountIn, minAmountToReceive, swapData
            );
        }

        // Direct transfer for sUSDe
        if (tokenIn == SUSDE) {
            if (amountIn != minAmountToReceive) {
                revert NoSlippageAllowedForSUSDe();
            }
            SUSDE.safeTransferFrom(
                _msgSender(), address(this), minAmountToReceive
            );
            return minAmountToReceive;
        }

        // For any other token, use ParaSwap
        tokenIn.safeTransferFrom(msg.sender, address(this), amountIn);
        return _executeParaswap(
            augustus, swapData, tokenIn, SUSDE, amountIn, minAmountToReceive
        );
    }

    /**
     * convert USD0++ to sUSDe
     */
    function _convertUSD0ppToSUSDe(
        IParaSwapAugustus augustus,
        uint256 amountUSD0ppIn,
        uint256 minAmountToReceive,
        bytes calldata swapData
    )
        internal
        returns (uint256)
    {
        // sender usd0Balance
        uint256 initialUSD0Balance = USD0.balanceOf(address(this));

        // transfer user USD0PP to the zapper
        IERC20(USD0PP).safeTransferFrom(
            msg.sender, address(this), amountUSD0ppIn
        );

        // unwrap usd0pp to usd0
        MINTER_USD0PP.unwrapPegMaintainer(amountUSD0ppIn);

        uint256 amountUSD0 = USD0.balanceOf(address(this)) - initialUSD0Balance;
        // check how much usd0 I received
        if (amountUSD0 < amountUSD0ppIn) {
            revert InsufficientAmountReceived();
        }

        // execute paraswap from usd0 to sUSDe
        return _executeParaswap(
            augustus, swapData, USD0, SUSDE, amountUSD0, minAmountToReceive
        );
    }

    /// @notice convert sUSDe to USD0PP
    /// @param augustus the paraswap augustus to use for the swap
    /// @param amountsUSDeIn the amount of sUSDe to convert
    /// @param minAmountToReceive the minimum amount of USD0PP to receive
    /// @param swapData the swap data to use for the swap
    function _convertSUSDeToUSD0pp(
        IParaSwapAugustus augustus,
        uint256 amountsUSDeIn,
        uint256 minAmountToReceive,
        bytes calldata swapData
    )
        internal
        returns (uint256)
    {
        // initial us0++ balance
        uint256 initialUSD0ppBalance = USD0PP.balanceOf(address(this));

        // swap from sUSDe to usd0
        uint256 amountUSD0 = _executeParaswap(
            augustus, swapData, SUSDE, USD0, amountsUSDeIn, minAmountToReceive
        );

        // mint usd0++ using usd0
        MINTER_USD0PP.mint(amountUSD0);

        uint256 amountUSD0pp =
            USD0PP.balanceOf(address(this)) - initialUSD0ppBalance;
        if (amountUSD0pp < amountUSD0) {
            revert InsufficientAmountReceived();
        }

        return amountUSD0pp;
    }

    /// @notice execute paraswap
    /// @param augustus the paraswap augustus to use for the swap
    /// @param data the swap data to use for the swap
    /// @param assetToSwapFrom the asset to swap from
    /// @param assetToSwapTo the asset to swap to
    /// @param amountToSwap the amount of assetToSwapFrom to swap
    /// @param minAmountToReceive the minimum amount of assetToSwapTo to receive
    function _executeParaswap(
        IParaSwapAugustus augustus,
        bytes calldata data,
        IERC20 assetToSwapFrom,
        IERC20 assetToSwapTo,
        uint256 amountToSwap,
        uint256 minAmountToReceive
    )
        internal
        returns (uint256 amountReceived)
    {
        if (!AUGUSTUS_REGISTRY.isValidAugustus(address(augustus))) {
            revert InvalidAugustus();
        }

        uint256 balanceBeforeAssetFrom =
            assetToSwapFrom.balanceOf(address(this));
        if (balanceBeforeAssetFrom < amountToSwap) {
            revert InsufficientBalanceBeforeSwap();
        }

        uint256 balanceBeforeAssetTo = assetToSwapTo.balanceOf(address(this));

        address tokenTransferProxy = augustus.getTokenTransferProxy();
        // for tokens requiring approval reset such as USDT
        assetToSwapFrom.approve(tokenTransferProxy, 0);
        assetToSwapFrom.approve(tokenTransferProxy, amountToSwap);

        // solhint-disable-next-line avoid-low-level-calls
        (bool success,) = address(augustus).call(data);
        if (!success) {
            // Copy revert reason from call
            // solhint-disable-next-line no-inline-assembly
            assembly {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }

        if (
            assetToSwapFrom.balanceOf(address(this))
                != balanceBeforeAssetFrom - amountToSwap
        ) {
            revert InsufficientAmountReceived();
        }

        amountReceived =
            assetToSwapTo.balanceOf(address(this)) - balanceBeforeAssetTo;

        if (amountReceived < minAmountToReceive) {
            revert InsufficientAmountReceived();
        }
    }

    /// @notice execute a permit
    /// @param token the token to permit
    /// @param owner the owner of the permit
    /// @param spender the spender of the permit
    /// @param permitParams the permit parameters to use for the permit
    function _execPermit(
        IERC20 token,
        address owner,
        address spender,
        PermitParams calldata permitParams
    )
        internal
    {
        ERC20Permit(address(token)).permit(
            owner,
            spender,
            permitParams.value,
            permitParams.deadline,
            permitParams.v,
            permitParams.r,
            permitParams.s
        );
        if (token.allowance(owner, spender) != permitParams.value) {
            revert PermitFailed();
        }
    }
}