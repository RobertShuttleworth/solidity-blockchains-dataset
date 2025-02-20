// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title IERC20 Interface
 * @notice Interface for ERC20 token standard used for token interactions within the contract.
 * @dev Defines functions to retrieve balances, approve allowances, transfer tokens, and retrieve decimals.
 */
interface IERC20 {
    /**
     * @notice Returns the balance of a given account.
     * @param account The address of the account to query.
     * @return The balance of the specified account in the smallest token units.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @notice Approves a spender to use a specified amount of tokens from the caller's account.
     * @param spender The address authorized to spend tokens.
     * @param amount The amount of tokens to approve.
     * @return True if the operation is successful.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @notice Transfers tokens from one address to another on behalf of the sender.
     * @param sender The address of the token sender.
     * @param recipient The address of the token recipient.
     * @param amount The amount of tokens to transfer.
     * @return True if the operation is successful.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /**
     * @notice Transfers tokens from the caller's address to the recipient.
     * @param recipient The address of the token recipient.
     * @param amount The amount of tokens to transfer.
     * @return True if the operation is successful.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @notice Returns the number of decimals used by the token.
     * @return The number of decimals the token uses.
     */
    function decimals() external view returns (uint8);
}

/**
 * @title IWMATIC Interface
 * @notice Interface for interacting with the WMATIC (Wrapped Polygon) token contract to deposit Polygon Token (POL) and mint WMATIC.
 */
interface IWMATIC {
    /**
     * @notice Deposits Polygon Token (POL) and mints WMATIC.
     * @dev The amount of Polygon Token (POL) sent with the transaction determines the amount of WMATIC minted.
     */
    function deposit() external payable;
}

/**
 * @title IAggregatorV3 Interface
 * @notice Interface for fetching price data from Chainlink Aggregators.
 * @dev Provides the latest price data, including metadata about the price round.
 */
interface IAggregatorV3 {
    /**
     * @notice Retrieves the latest round data for the price feed.
     * @return roundId The ID of the round.
     * @return answer The latest price as an int256.
     * @return startedAt The timestamp when the round started.
     * @return updatedAt The timestamp of the latest update.
     * @return answeredInRound The round in which the price was answered.
     */
    function latestRoundData() external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    );

    /**
     * @notice Returns the number of decimals used by the aggregator price feed.
     * @dev This value indicates how many decimal places the `answer` field in
     *      `latestRoundData()` is scaled by. For example, a value of `8` would
     *      mean the price is scaled by 10^8.
     * @return The number of decimals the aggregator uses, typically 8.
     */
    function decimals() external view returns (uint8);
}

/**
 * @title IUniswapV2Router Interface
 * @notice Interface for interacting with Uniswap V2 Router for token swaps.
 */
interface IUniswapV2Router {
    /**
     * @notice Swaps an exact amount of tokens for another token along a predefined path.
     * @param amountIn The amount of input tokens to swap.
     * @param amountOutMin The minimum amount of output tokens required for the swap.
     * @param path The sequence of token addresses for the swap route.
     * @param to The recipient address for the output tokens.
     * @param deadline The timestamp after which the transaction will revert if not executed.
     * @return amounts The array of token amounts involved in the swap.
     */
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

/**
 * @title IUniswapV3Router Interface
 * @notice Interface for interacting with Uniswap V3 Router for token swaps using exact input parameters.
 */
interface IUniswapV3Router {
    /**
     * @title ExactInputParams Struct
     * @notice Defines the parameters for an exact input swap in Uniswap V3.
     * @param path The encoded path for the swap, including the token addresses and the fee tiers for each pair.
     * @param recipient The address that will receive the output tokens from the swap.
     * @param amountIn The exact amount of input tokens that will be swapped.
     * @param amountOutMinimum The minimum amount of output tokens required for the swap to succeed.
     */
    struct ExactInputParams {
        bytes path;               
        address recipient;        
        uint256 amountIn;         
        uint256 amountOutMinimum; 
    }

    /**
     * @notice Executes a token swap using exact input parameters.
     * @param params The ExactInputParams struct defining the swap details.
     * @return amountOut The amount of output tokens received.
     */
    function exactInput(ExactInputParams calldata params) external payable returns (uint256 amountOut);
}

/**
 * @title LeveraBetTokenPreSale
 * @notice A comprehensive and modular presale contract enabling seamless token deposits, dynamic USD conversions,
 *         and secure validation mechanisms through advanced cryptographic tools and DeFi integrations.
 * @dev This contract incorporates the following key features:
 *      - Token Deposits: Supports deposits in various ERC20 tokens and Polygon Token (POL) (converted to WMATIC),
 *        with robust validation to ensure supported tokens are properly configured.
 *      - USD Conversion: Dynamically calculates the USD value of deposits using Chainlink price feeds,
 *        ensuring accurate and real-time conversion based on current market data.
 *      - Uniswap Integration: Supports both Uniswap V2 and V3 for token swaps, providing flexibility
 *        in liquidity pool interactions and optimized swap paths.
 *      - Merkle Tree Validation: Constructs a Merkle tree from deposit data for proof-of-inclusion
 *        purposes, enabling efficient and secure data validation.
 *      - Security Features: Implements reentrancy protection, Safe Mode for ensuring minimum swap
 *        efficiency, and owner restrictions to safeguard against misuse.
 *      - Governance and Access Control: Allows the owner to configure supported tokens, update system
 *        parameters (e.g., Safe Mode, Oracle settings), and manage emergency states (e.g., pausing contract functions).
 *      - Event Logging: Provides detailed event logs for transparency and monitoring, covering every
 *        significant action such as token configuration updates, deposits, and ownership transfers.
 *      - More Information: For in-depth technical documentation, detailed presale mechanics, and governance updates,
 *        please refer to the official platform website at [leverabet.com](https://www.leverabet.com).
 *        Additionally, for real-time discussions, announcements, and community support, join our Telegram channel at 
 *        [t.me/leverabet](https://www.t.me/leverabet).
 */
contract LeveraBetTokenPreSale {
    /**
     * @title TokenConfig Struct
     * @notice Configuration details for a token supported in the presale.
     * @dev Includes routing information, token swap paths, and a price feed aggregator.
     * @param useV3 Boolean indicating whether Uniswap V3 is used for swaps.
     * @param router The address of the Uniswap router (V2 or V3).
     * @param v2Path The token swap path for Uniswap V2.
     * @param v3Path The encoded token swap path for Uniswap V3.
     * @param aggregator The address of the Chainlink price feed aggregator for USD conversion.
     */
    struct TokenConfig {
        bool useV3;
        address router;
        address[] v2Path;
        bytes v3Path;
        address aggregator;
    }

    /**
     * @title DepositInfo Struct
     * @notice Information related to a user's token deposit.
     * @param user The address of the depositor.
     * @param tokenDeposited The address of the token deposited.
     * @param tokenAmount The amount of tokens deposited.
     * @param usdcAmountReceived The amount of USDC received after conversion.
     * @param blockNumber The block number at the time of deposit.
     * @param timestamp The timestamp of the deposit.
     * @param depositId A unique ID for the deposit.
     * @param depositHash A hash representing the deposit details.
     */
    struct DepositInfo {
        address user; 
        address tokenDeposited;
        uint256 tokenAmount;
        uint256 usdcAmountReceived; 
        uint256 blockNumber;
        uint256 timestamp;
        uint256 depositId;
        bytes32 depositHash;
    }

    /**
     * @notice A constant defining the lock period for withdrawal-related actions.
     * @dev 
     *  - The lock period is set to 72 hours (259200 seconds).
     *  - This value is used by the contract to enforce a mandatory waiting period 
     *    before certain withdrawal-related operations can be executed.
     */
    uint256 constant LOCK_PERIOD = 72 hours;

    /**
     * @notice The address of the current owner of the contract.
     * @dev 
     *  - Automatically returns the owner's address via the public getter generated by Solidity.
     *  - Initially set during contract deployment.
     *  - Can only be updated by invoking the `transferOwnership` function, 
     *    typically enforcing a delay or lock period as defined in the contract.
     */
    address public owner;

    /**
     * @notice The address of the USDC token used for deposits and conversions.
     * @dev 
     *  - Automatically returns the USDC token address via the public getter.
     *  - Must be explicitly set by the contract owner using the `setUSDC` function.
     *  - The contract relies on this address to identify and interact with USDC 
     *    during deposit and conversion operations.
     */
    address public usdcToken;

    /**
     * @notice The address of the WMATIC (Wrapped Polygon) token used for handling Polygon Token (POL) deposits.
     * @dev
     *  - Automatically returns the WMATIC token address via the public getter.
     *  - Must be configured by the contract owner using the `setWMATIC` function.
     *  - When users send native Polygon Token (POL) to the contract, it is converted to WMATIC using this address 
     *    to facilitate standardized token-based transactions and integrations.
     */
    address public wmaticToken;

    /**
     * @notice The minimum acceptable percentage for Safe Mode checks, scaled by 1000.
     *         For example:
     *           50.123% -> 50123
     *           100.000% -> 100000
     */
    uint256 public safeModeMinPercentage;

    /**
     * @notice Returns the total USD value of all deposits made globally in the contract,
     *         aggregated across all users.
     * @dev This value is incremented whenever a new deposit is finalized,
     *      providing an up-to-date overview of the contract's deposit volume in USD.
     */
    uint256 public totalGlobalUSDDeposits;

    /**
     * @notice Returns the ID of the most recent deposit.
     * @dev Each new deposit increments this value to ensure that all deposit IDs are unique.
     */
    uint256 public currentDepositId;

    /**
     * @notice Returns the timestamp of the last ownership transfer action.
     * @dev Used to enforce delayed ownership transfers, preventing immediate repeat changes.
     */
    uint256 public lastOwnershipTransferTimestamp;

    /**
     * @notice Returns the timestamp at which the new ownership lock period began.
     * @dev During this lock period, certain owner actions may be restricted
     *      to enhance security around ownership changes.
     */
    uint256 public newOwnerLockTimestamp;

    /**
     * @notice Returns the timestamp of the last time the contract was paused.
     * @dev Useful for determining how long the contract has been unpaused 
     *      and for enforcing pause-related restrictions.
     */
    uint256 public lastPauseTimestamp;

    /**
     * @notice Stores the maximum allowable time interval (in seconds) for Oracle data to remain valid.
     * @dev This value can be updated by the contract owner to adjust how quickly
     *      price feed data might become considered stale.
     */
    uint256 public maximumUpdateTime;

    /**
     * @notice A numeric flag indicating whether deposits are allowed.
     *         0 => deposits NOT allowed
     *         1 => deposits allowed
     * @dev 
     *  - This variable is private, but a public getter is provided via `getIsDepositAllowed()`.
     */
    uint256 private _isDepositAllowed;

    /**
     * @notice A numeric flag indicating whether Safe Mode is enabled.
     *         0 => Safe Mode disabled
     *         1 => Safe Mode enabled
     * @dev 
     *  - This variable is private, and a public getter `isSafeModeEnabled()` is provided 
     *    to return its boolean equivalent.
     */
    uint256 private _safeModeEnabled;

    /**
     * @notice Reentrancy guard variable to prevent nested calls to certain contract functions.
     * @dev 
     *  - This variable is initialized to `1` by default.
     *  - During the execution of functions protected by a reentrancy modifier, 
     *    it may be set to `2` to indicate an ongoing call.
     *  - After the function finishes, it is reset back to `1`.
     */
    uint256 private _reentrancyGuard = 1;

    /**
     * @notice Pause state variable for emergency stops.
     * @dev 
     *  - A value of `0` means the contract is not paused.
     *  - A value of `1` means the contract is paused.
     *  - Can be updated via dedicated functions (e.g., `pause()`, `unpause()`) to prevent critical operations.
     */
    uint256 private paused;

    /**
     * @notice An array storing the hashes of all deposits.
     * @dev 
     *  - Each element is a unique `bytes32` hash representing a deposit.
     *  - Used to build a Merkle tree for proof-of-inclusion checks.
     *  - Accessible publicly, allowing external systems or users to verify deposit data.
     */
    bytes32[] public allDepositHashes;

    /**
     * @notice A mapping that associates a token address with its swap and pricing configuration.
     * @dev 
     *  - The `TokenConfig` structure may include, for example, whether Uniswap V3 is used, 
     *    the router address, and a Chainlink price aggregator for USD conversion.
     *  - Allows the contract to handle multiple tokens, each with different swap parameters.
     */
    mapping(address => TokenConfig) public tokenConfigs;

    /**
     * @notice A mapping of unique deposit IDs to detailed deposit info.
     * @dev 
     *  - Each `DepositInfo` struct contains information about a single deposit, 
     *    including the depositor address, the token deposited, the amount, and the timestamp.
     *  - Ensures that every deposit can be referenced and verified using its unique ID.
     */
    mapping(uint256 => DepositInfo) public deposits;

    /**
     * @notice Maps user addresses to an array of deposit IDs.
     * @dev 
     *  - Facilitates quick lookups of all deposits made by a given user.
     *  - Useful for front-end applications to retrieve a list of deposit IDs and then
     *    fetch each deposit’s details from the `deposits` mapping.
     */
    mapping(address => uint256[]) public userDeposits;

    /**
     * @notice Mapping of user addresses to the total USD value of their deposits.
     * @dev 
     *  - Each user's deposit amount is tracked in USD.
     *  - The values here aggregate all deposits made by a particular user.
     *  - This mapping is updated whenever the user makes a deposit or if the deposit
     *    is converted to or from another asset as part of the deposit logic.
     */
    mapping(address => uint256) public userTotalUSDDeposits;

    /**
     * @notice Mapping of deposit IDs to their associated ratio values.
     * @dev 
     *  - Each deposit ID corresponds to a specific deposit event.
     *  - The ratio is calculated based on the total global USD deposits
     *    at the moment this particular deposit is finalized.
     *  - This value may be used to calculate user rewards, staking benefits,
     *    or other platform-specific incentives that depend on deposit ratios.
     */
    mapping(uint256 => uint256) public depositRatios;

    // Event triggered when the WMATIC (Wrapped Polygon) token address is updated. 
    // Provides the new address of the WMATIC token.
    event WMATICAddressUpdated(address wmaticToken);

    // Event triggered when the USDC token address is updated. 
    // Provides the new address of the USDC token.
    event USDCAddressUpdated(address usdcToken);

    // Event emitted when the Safe Mode configuration is updated. 
    // Indicates whether Safe Mode is enabled and the new minimum percentage.
    event SafeModeUpdated(bool enabled, uint256 minPercentage);

    // Event emitted when the contract is paused. 
    // Records the timestamp of the pause action.
    event ContractPaused(uint256 timestamp);

    // Event emitted when the contract is unpaused. 
    // Records the timestamp of the unpause action.
    event ContractUnpaused(uint256 timestamp);

    // Event emitted when the deposit allowance is changed. 
    // Indicates whether deposits are allowed and provides the timestamp.
    event DepositAllowedChanged(bool allowed, uint256 timestamp);

    // Event triggered when a token configuration is removed. 
    // Logs the address of the removed token.
    event TokenConfigRemoved(address indexed token);

    // Event emitted when ownership of the contract is transferred. 
    // Provides the addresses of the previous and new owners.
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // Event triggered when Polygon Token (POL) is received without being associated with a deposit. 
    // Logs the sender's address and the amount of Polygon Token (POL) received.
    event POLReceivedWithoutDeposit(address indexed sender, uint256 amount);

    // Event triggered when Polygon Token (POL) is successfully deposited into the contract. 
    // Logs the depositor's address and the amount of Polygon Token (POL) deposited.
    event POLDeposited(address indexed depositor, uint256 amount);

    // Event emitted after a low-level call is executed by the owner. 
    // Logs the target address, value sent, call data, and whether the call succeeded.
    event OwnerCallExecuted(address indexed target, uint256 value, bytes data, bool success);

    // Event emitted when an ERC20 token is withdrawn by the owner. 
    // Logs the token address, amount withdrawn, and the recipient's address.
    event ERC20Withdrawn(address indexed token, uint256 amount, address indexed recipient);

    // Event triggered when a Uniswap V3 token configuration is updated. 
    // Logs the token address, router address, encoded V3 path, and Chainlink aggregator address.
    event TokenConfigUpdatedV3(
        address indexed token,
        address router,
        bytes v3Path,
        address aggregator
    );

    // Event triggered when a Uniswap V2 token configuration is updated. 
    // Logs the token address, router address, V2 path, and Chainlink aggregator address.
    event TokenConfigUpdatedV2(
        address indexed token,
        address router,
        address[] v2Path,
        address aggregator
    );

    // Event emitted when the maximum update time for Oracle data is updated.
    // Logs the new maximum allowable update time in seconds, as set by the contract owner.
    event MaximumOracleUpdateTime(uint256 newUpdateTime);

    // Event emitted after a token is converted into USDC. 
    // Logs the depositor's address, token, amount deposited, calculated USD value, and USDC received.
    event TokenConversion(address indexed depositor, address token, uint256 amount, uint256 usdValue, uint256 usdcReceived);

    // Event emitted when a deposit is finalized. 
    // Logs depositor details, deposit ID, USDC received, USD value, deposit hash, and the calculated ratio.
    event DepositFinalized(
        address indexed depositor,
        uint256 depositId,
        uint256 usdcReceived,
        uint256 usdValue,
        bytes32 depositHash,
        uint256 ratio
    );

    // Event emitted when a deposit hash is added to the global list. 
    // Logs the added deposit hash and the total number of deposits.
    event DepositHashAdded(bytes32 depositHash, uint256 totalDeposits);

    // Event emitted when the global ratio for deposits is updated. 
    // Logs the new total global USD deposits and the updated ratio.
    event RatioUpdated(uint256 totalGlobalUSDDeposits, uint256 newRatio);

    /**
     * @notice Modifier that restricts function access to the contract owner.
     * @dev 
     * - Loads the stored owner address from `owner.slot` using assembly.
     * - Compares the caller (msg.sender) with the stored owner.
     * - If the caller is not the owner, it reverts using a standard Error(string) encoding.
     * 
     * Detailed encoding steps for revert reason "NotOwner":
     * - The standard error selector for Error(string) is `0x08c379a0`.
     * - Store this selector at memory position 0x00.
     * - At memory position 0x20, store the offset to the string data (0x20).
     * - The string "NotOwner" consists of 8 characters:
     *   // String "NotOwner" is 8 bytes: "N" "o" "t" "O" "w" "n" "e" "r"
     *   // Length: 8 → 0x08
     *   // Store the string length (0x08) at memory position 0x40.
     *   // At memory position 0x60, store the ASCII-encoded string "NotOwner" padded to 32 bytes.
     * - Finally, revert with 128 bytes of data containing the error selector, offset, length, and the string itself.
     */
    modifier onlyOwner {
        assembly {
            let _owner := sload(owner.slot)        // Load the owner from storage
            if xor(caller(), _owner) {             // Compare caller with owner, if not equal:
                // Encoding revert reason "NotOwner"
                // Memory layout:
                // 0x00: Error selector (0x08c379a0)
                // 0x20: Offset to the string data (0x20)
                // 0x40: String length (0x08 for 8 characters)
                // 0x60: ASCII encoding of "NotOwner" padded to 32 bytes
                mstore(0x00, 0x08c379a000000000000000000000000000000000000000000000000000000000) 
                mstore(0x20, 0x20)
                mstore(0x40, 0x08)
                mstore(0x60, 0x4e6f744f776e6572000000000000000000000000000000000000000000000000)
                revert(0x00, 0x80) // Revert with 128 bytes of encoded error
            }
        }
        _;
    }

    /**
     * @notice Modifier to prevent reentrant calls to a function.
     * @dev 
     * - Checks the reentrancy guard by loading `_reentrancyGuard` from storage.
     * - If `_reentrancyGuard` equals 2, it indicates that a function is already being executed, 
     *   so calling it again would cause reentrancy.
     * - If reentrancy is detected, it reverts using a standard Error(string) encoding with the reason "nonReentrantDetected".
     *
     * Detailed encoding steps for revert reason "nonReentrantDetected":
     * - The standard error selector for Error(string) is `0x08c379a0`.
     * - Store this selector at memory position 0x00.
     * - At memory position 0x20, store the offset to the string data (0x20).
     * - The string "nonReentrantDetected" consists of 20 characters:
     *   // String "nonReentrantDetected" is 20 bytes: "n" "o" "n" "R" "e" "e" "n" "t" "r" "a" "n" "t" "D" "e" "t" "e" "c" "t" "e" "d"
     * - Length: 20 → 0x14 in hexadecimal
     * - Store the string length (0x14) at memory position 0x40.
     * - At memory position 0x60, store the ASCII-encoded string "nonReentrantDetected" padded to 32 bytes.
     * - Finally, revert with 160 bytes of data containing the error selector, offset, length, and the string itself.
     */
    modifier nonReentrant() {
        assembly {
            // If reentrancy guard is set to 2, it means we are already in a function call.
            if eq(sload(_reentrancyGuard.slot), 2) {
                // Encoding revert reason "nonReentrantDetected"
                // Memory layout:
                // 0x00: Error selector (0x08c379a0)
                // 0x20: Offset to the string data (0x20)
                // 0x40: String length (0x14 for 20 characters)
                // 0x60: ASCII encoding of "nonReentrantDetected" padded to 32 bytes
                mstore(0x00, 0x08c379a000000000000000000000000000000000000000000000000000000000) 
                mstore(0x20, 0x20)
                mstore(0x40, 0x14)
                mstore(
                    0x60,
                    0x6e6f6e5265656e7472616e744465746563746564000000000000000000000000
                )
                revert(0x00, 0xa0) // Revert with 160 bytes of encoded error
            }
            // Otherwise, set the guard to 2 to mark the function call as entered
            sstore(_reentrancyGuard.slot, 2)
        }
        _;
        assembly {
            // Reset the guard to 1 after the function finishes
            sstore(_reentrancyGuard.slot, 1)
        }
    }

    /**
     * @notice Modifier to ensure the contract is not paused.
     * @dev 
     * - Loads the `paused` state from storage using assembly.
     * - Checks whether `paused == 1` to determine if the contract is in a paused state.
     * - If the contract is paused, it reverts using a standard Error(string) encoding with the reason "Paused!".
     * 
     * Detailed encoding steps for revert reason "Paused!":
     * - The standard error selector for Error(string) is `0x08c379a0`.
     * - Store this selector at memory position 0x00.
     * - At memory position 0x20, store the offset to the string data (0x20).
     * - The string "Paused!" consists of 7 characters:
     *   // String "Paused!" is 7 bytes: "P" "a" "u" "s" "e" "d" "!"
     * - Length: 7 → 0x07
     * - Store the string length (0x07) at memory position 0x40.
     * - At memory position 0x60, store the ASCII-encoded string "Paused!" padded with zeros.
     * - Finally, revert with 128 bytes of data containing the error selector, offset, length, and the string itself.
     */
    modifier whenNotPaused() {
        assembly {
            let p := sload(paused.slot) // Load paused state
            if eq(p, 1) {
                // Encoding revert reason "Paused!"
                // Memory layout:
                // 0x00: Error selector (0x08c379a0)
                // 0x20: Offset to the string data (0x20)
                // 0x40: String length (0x07 for 7 characters)
                // 0x60: ASCII encoding of "Paused!" padded to 32 bytes
                mstore(0x00, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                mstore(0x20, 0x20)
                mstore(0x40, 0x07)
                mstore(0x60, 0x5061757365642100000000000000000000000000000000000000000000000000)
                revert(0x00, 0x80) // Revert with 128 bytes of encoded error
            }
        }
        _;
    }

    /**
     * @notice Ensures that deposits are currently allowed.
     * @dev
     * - Loads the `_isDepositAllowed` variable (stored as a uint256) using inline assembly.
     * - Interprets `0` as deposits disabled, and `1` as deposits enabled.
     * - If `_isDepositAllowed == 0`, it reverts with a standard Error(string) encoding using
     *   the reason "DepositStopped".
     * 
     * Detailed encoding steps for the "DepositStopped" revert:
     * - The standard error selector for Error(string) is `0x08c379a0`.
     * - This selector is stored at memory position 0x00.
     * - At memory position 0x20, the offset to the string data (0x20) is stored.
     * - "DepositStopped" is a 14-byte string (0x0e).
     * - The length (0x0e) is stored at memory position 0x40.
     * - At memory position 0x60, the ASCII-encoded string "DepositStopped"
     *   is stored, padded to 32 bytes.
     * - Finally, the function reverts with 160 bytes (the error selector, offset,
     *   length, and the string).
     */
    modifier depositsAllowed() {
        assembly {
            // Load the internal _isDepositAllowed (uint256) from storage.
            let currentState := sload(_isDepositAllowed.slot)
            
            // If currentState == 0, it means deposits are not allowed, so revert.
            if iszero(currentState) {
                // Encoding revert reason "DepositStopped"
                // Memory layout:
                // 0x00: Error selector (0x08c379a0)
                // 0x20: Offset to the string data (0x20)
                // 0x40: String length (0x0e for 14 characters)
                // 0x60: ASCII encoding of "DepositStopped" padded to 32 bytes
                mstore(0x00, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                mstore(0x20, 0x20)
                mstore(0x40, 0x0e)
                mstore(0x60, 0x4465706f73697453746f707065640000000000000000000000000000000000)
                revert(0x00, 0x80) // Revert with 128 bytes of encoded error
            }
        }
        _;
    }

    /**
     * @notice Constructor function to initialize the contract.
     * @dev 
     * - Sets the initial owner of the contract to the deployer's address (`msg.sender`).
     * - Configures the USDC and WMATIC token addresses using the provided parameters.
     * @param _usdcToken The address of the USDC token to be used in the contract.
     * @param _wmaticToken The address of the WMATIC token to be used in the contract.
     */
    constructor(address _usdcToken, address _wmaticToken) {
        owner = msg.sender;             // Assign the contract deployer (msg.sender) as the owner
        usdcToken = _usdcToken;         // Assign the provided USDC token address
        wmaticToken = _wmaticToken;     // Assign the provided WMATIC token address
    }

    /**
     * @notice Set the WMATIC token address.
     * @dev 
     * - Can only be called by the owner when the contract is not paused.
     * - The address must be valid, and the token must have a `decimals` function that returns a value greater than 0.
     * - This function ensures that the provided token is a valid WMATIC-compatible token.
     * @param _wmaticToken The address of the WMATIC token.
     */
    function setWMATIC(address _wmaticToken) external whenNotPaused onlyOwner {
        require(_wmaticToken != address(0), "Invalid WMATIC address"); // Ensure address is not zero

        // Check if the token has a valid decimals function
        try IERC20(_wmaticToken).decimals() returns (uint8 tokenDecimals) {
            require(tokenDecimals > 0, "Invalid WMATIC: decimals is zero");
        } catch {
            revert("Invalid WMATIC: no decimals function");
        }

        wmaticToken = _wmaticToken; // Set the WMATIC token address

        emit WMATICAddressUpdated(_wmaticToken); // Emit an event to log the updated WMATIC token address
    }

    /**
     * @notice Set the USDC token address.
     * @dev Can only be called by the owner when the contract is not paused.
     *      The address must be valid, and the token must have a decimals function that returns a value greater than 0.
     *      This function ensures the provided token adheres to the USDC token standard.
     * @param _usdcToken The address of the USDC token.
     */
    function setUSDC(address _usdcToken) external whenNotPaused onlyOwner {
        require(_usdcToken != address(0), "Invalid USDC address"); // Ensure address is not zero

        // Check if the token has a valid decimals function
        try IERC20(_usdcToken).decimals() returns (uint8 tokenDecimals) {
            require(tokenDecimals > 0, "Invalid USDC: decimals is zero");
        } catch {
            revert("Invalid USDC: no decimals function");
        }

        usdcToken = _usdcToken; // Set the USDC token address

        emit USDCAddressUpdated(_usdcToken); // Emit an event to log the updated USDC token address
    }

    /**
     * @notice Sets the Safe Mode configuration, including a minimal acceptable percentage.
     * @dev 
     *  - Can only be called by the owner when the contract is not paused.
     *  - `_percentage` must be within the range (1..100000).
     *  - `_enabled` is stored as `_safeModeEnabled`: 0 => off, 1 => on.
     *  - For example:
     *      50.123% -> _percentage = 50123
     *      100.000% -> _percentage = 100000
     * @param _enabled Boolean to enable (true) or disable (false) Safe Mode.
     * @param _percentage Minimal acceptable percentage, scaled by 1000 (1..100000).
     */
    function setSafeMode(bool _enabled, uint256 _percentage)
        external
        whenNotPaused
        onlyOwner
    {
        require(_percentage > 0 && _percentage <= 100000, "Invalid percentage");

        // Convert bool to uint256
        uint256 newVal = _enabled ? 1 : 0;

        // Store the new Safe Mode state
        _safeModeEnabled = newVal;

        // Update the minimal acceptable percentage for Safe Mode
        safeModeMinPercentage = _percentage;

        // Emit event preserving the original bool `_enabled`
        emit SafeModeUpdated(_enabled, _percentage);
    }

    /**
     * @notice Pauses the contract, preventing certain operations from proceeding.
     * @dev 
     *  - Only callable by the owner.
     *  - Reverts if the contract is already paused.
     *  - Uses inline assembly for direct storage access and revert logic.
     */
    function pause() external onlyOwner {
        assembly {
            // Load the current paused state
            let p := sload(paused.slot)

            // If it is already paused, revert with a properly encoded error "AlreadyPaused"
            if eq(p, 1) {
                // 1) Store the standard Error(string) selector at memory position 0x00
                mstore(0x00, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                // 2) Store the offset to the string data (0x20) at position 0x20
                mstore(0x20, 0x20)
                // 3) Store the string length (13) at position 0x40
                mstore(0x40, 13)
                // 4) Store the ASCII-encoded string "AlreadyPaused" (13 bytes) padded to 32 bytes
                mstore(
                    0x60,
                    0x416c7265616479506175736564000000000000000000000000000000000000
                )

                // Revert with 128 bytes of data (4 words)
                revert(0x00, 0x80)
            }

            // Otherwise, set paused = 1
            sstore(paused.slot, 1)
            // Record the current timestamp in lastPauseTimestamp
            sstore(lastPauseTimestamp.slot, timestamp())
        }

        emit ContractPaused(block.timestamp);
    }

    /**
     * @notice Unpauses the contract, re-enabling normal operations.
     * @dev 
     *  - Only callable by the owner.
     *  - Enforces a 1-hour lock period since the last pause.
     *  - Uses inline assembly for direct storage access and revert logic.
     */
    function unpause() external onlyOwner {
        assembly {
            // Load the current paused state
            let p := sload(paused.slot)

            // Check if already unpaused
            if eq(p, 0) {
                // Encode the error "AlreadyUnpaused"
                mstore(0x00, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                mstore(0x20, 0x20)
                // "AlreadyUnpaused" => 15 characters
                mstore(0x40, 15)
                mstore(
                    0x60,
                    0x416c7265616479556e70617573656400000000000000000000000000000000
                )
                revert(0x00, 0x80)
            }

            // Load last pause timestamp
            let lastPause := sload(lastPauseTimestamp.slot)
            // 1 hour = 3600 seconds
            let lockPeriod := 3600

            // If current time < lastPause + lockPeriod => revert
            if lt(timestamp(), add(lastPause, lockPeriod)) {
                // Encode the error "UnpauseLocked"
                mstore(0x00, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                mstore(0x20, 0x20)
                // "UnpauseLocked" => 13 characters
                mstore(0x40, 13)
                mstore(
                    0x60,
                    0x556e70617573654c6f636b6564000000000000000000000000000000000000
                )
                revert(0x00, 0x80)
            }

            // Set paused to 0 (unpause)
            sstore(paused.slot, 0)
        }

        emit ContractUnpaused(block.timestamp);
    }

    /**
     * @notice Enables or disables the deposit functionality within the contract, 
     *         storing the state as 0 (disabled) or 1 (enabled).
     * @dev
     *  - Uses inline assembly for direct storage manipulation.
     *  - Reverts if no state change occurs, emitting "AlreadyTrue" or "AlreadyFalse."
     * @param allowed A boolean indicating whether deposits are allowed (true) or disallowed (false).
     */
    function setDepositAllowed(bool allowed) external whenNotPaused onlyOwner {
        assembly {
            // 1. Identify the storage slot for _isDepositAllowed
            let slot := _isDepositAllowed.slot

            // 2. Load the current value
            let currentVal := sload(slot)

            // 3. Convert the incoming bool (allowed) to 0 or 1
            //    - "calldataload(4)" reads the entire 32 bytes after the 4-byte selector
            //    - We'll just check if it's nonzero
            let newVal := 0
            if eq(calldataload(4), 1) {
                newVal := 1
            }

            // 4. If there's no change, revert with "AlreadyFalse" or "AlreadyTrue"
            if eq(currentVal, newVal) {
                switch currentVal
                case 0 {
                    // "AlreadyFalse"
                    // Memory layout for revert reason:
                    // 0x00: Error selector (0x08c379a0)
                    // 0x20: Offset to the string data (0x20)
                    // 0x40: String length (0x0c for 12 characters)
                    // 0x60: ASCII encoding "AlreadyFalse"
                    mstore(0x00, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                    mstore(0x20, 0x20)
                    mstore(0x40, 0x0c)
                    mstore(0x60, 0x416c726561647946616c736500000000000000000000000000000000000000)
                    revert(0x00, 0x80)
                }
                default {
                    // "AlreadyTrue"
                    // Memory layout for revert reason:
                    // 0x00: Error selector (0x08c379a0)
                    // 0x20: Offset to the string data (0x20)
                    // 0x40: String length (0x0b for 11 characters)
                    // 0x60: ASCII encoding "AlreadyTrue"
                    mstore(0x00, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                    mstore(0x20, 0x20)
                    mstore(0x40, 0x0b)
                    mstore(0x60, 0x416c7265616479547275650000000000000000000000000000000000000000)
                    revert(0x00, 0x80)
                }
            }

            // 5. Otherwise, store the new value
            sstore(slot, newVal)
        }

        // 6. Emit the event with the external boolean
        emit DepositAllowedChanged(allowed, block.timestamp);
    }

    /**
     * @notice Removes the configuration for a specific token.
     * @dev Can only be called by the owner when the contract is not paused.
     * @param tokenAddress The address of the token whose configuration should be removed.
     */
    function removeTokenConfig(address tokenAddress) external whenNotPaused onlyOwner {
        require(tokenConfigs[tokenAddress].router != address(0), "No config to remove"); // Ensure the token has a configuration

        delete tokenConfigs[tokenAddress]; // Remove the token configuration

        emit TokenConfigRemoved(tokenAddress); // Emit an event to log the removal of the token configuration
    }

    /**
     * @notice Transfers contract ownership to a new address.
     * @dev 
     *  - Only callable by the current owner when not paused.
     *  - Enforces a 72-hour lock period since the last ownership transfer,
     *    preventing immediate repeated changes.
     *  - Uses inline assembly to store the owner slot directly and encode custom errors.
     * @param newOwner The address of the new owner.
     */
    function transferOwnership(address newOwner) external whenNotPaused {
        assembly {
            let _owner := sload(owner.slot)
            
            // Check if msg.sender == owner
            if xor(caller(), _owner) {
                // Encode "Caller is not the owner"
                mstore(0x00, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                mstore(0x20, 0x20)
                // 23 characters: "Caller is not the owner"
                mstore(0x40, 23)
                mstore(
                    0x60,
                    0x43616c6c6572206973206e6f7420746865206f776e65720000000000000000
                )
                revert(0x00, 0x80)
            }

            // Check if newOwner is zero or 0xdead...
            if or(iszero(newOwner), eq(newOwner, 0x000000000000000000000000000000000000dEaD)) {
                // Encode "Invalid new owner address"
                mstore(0x00, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                mstore(0x20, 0x20)
                // 25 characters: "Invalid new owner address"
                mstore(0x40, 25)
                mstore(
                    0x60,
                    0x496e76616c6964206e6577206f776e65722061646472657373000000000000
                )
                revert(0x00, 0x80)
            }

            let lot := sload(lastOwnershipTransferTimestamp.slot)
            let nowTime := timestamp()

            // If lastOwnershipTransferTimestamp is non-zero, require 72h lock
            if gt(lot, 0) {
                let limit := add(lot, 259200) // 72 hours
                if lt(nowTime, limit) {
                    // Encode "Ownership transfer locked"
                    mstore(0x00, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                    mstore(0x20, 0x20)
                    // 25 characters: "Ownership transfer locked"
                    mstore(0x40, 25)
                    mstore(
                        0x60,
                        0x4f776e657273686970207472616e73666572206c6f636b6564000000000000
                    )
                    revert(0x00, 0x80)
                }
            }

            // Set new owner
            sstore(owner.slot, newOwner)
            // Update the lastOwnershipTransferTimestamp
            sstore(lastOwnershipTransferTimestamp.slot, nowTime)
            // Also set newOwnerLockTimestamp to now
            sstore(newOwnerLockTimestamp.slot, nowTime)
        }

        emit OwnershipTransferred(msg.sender, newOwner);
    }

    /**
     * @notice Allows users to deposit supported tokens into the contract.
     * @dev 
     *  - Ensures the token is supported (token == usdcToken or defined in tokenConfigs).
     *  - Requires a non-zero deposit amount.
     *  - Invokes transferFrom(msg.sender, address(this), amount) via a low-level call:
     *      1) Encodes the function selector and arguments correctly in memory.
     *      2) Calls the token contract's transferFrom function.
     *      3) Checks that the call succeeded (callSuccess == true).
     *      4) If the return data is exactly 32 bytes, it must decode to true.
     *      5) Zero-length return data is treated as success (some non-standard ERC20 tokens do not return a value).
     *      6) Any other return data size causes a revert.
     *  - Calls _finalizeDeposit upon successful transfer to handle further processing 
     *    such as recording the deposit details, updating relevant mappings, and emitting events.
     *  - Protected by nonReentrant, whenNotPaused, and depositsAllowed modifiers 
     *    to prevent reentrancy attacks, ensure the contract is active, and confirm deposits are allowed.
     * @param token The address of the token being deposited.
     * @param amount The amount of tokens to deposit.
     */
    function depositTokens(address token, uint256 amount) 
        external 
        nonReentrant 
        whenNotPaused 
        depositsAllowed 
    {
        require(token == usdcToken || tokenConfigs[token].router != address(0), "Token not supported");
        require(amount > 0, "Amount must be greater than zero");

        assembly {
            // -----------------------------------------
            // 1. Prepare calldata in memory
            // -----------------------------------------
            // Get the free memory pointer
            let ptr := mload(0x40)

            // Store the function selector for transferFrom: 0x23b872dd
            // Followed by 28 zero bytes to fill the word (32 bytes total)
            mstore(ptr, 0x23b872dd00000000000000000000000000000000000000000000000000000000)

            // Store msg.sender (caller()) at offset 4
            mstore(add(ptr, 0x04), caller())

            // Store address(this) at offset 36 (0x24)
            mstore(add(ptr, 0x24), address())

            // Store amount at offset 68 (0x44)
            mstore(add(ptr, 0x44), amount)

            // -----------------------------------------
            // 2. Call the token contract
            // -----------------------------------------
            let callSuccess := call(
                gas(),        // Forward all available gas
                token,        // Call the token's address
                0,            // No POL value
                ptr,          // Pointer to start of calldata
                0x64,         // Calldata size (4 + 32 + 32 + 32 = 100 bytes = 0x64)
                0,            // Write return data to memory offset 0 (we'll handle it below)
                0x20          // Expecting up to 32 bytes return data
            )

            // -----------------------------------------
            // 3. Check if call failed
            // -----------------------------------------
            if iszero(callSuccess) {
                // Build the revert data for "TransferFrom call revert"
                mstore(0x00, 0x08c379a000000000000000000000000000000000000000000000000000000000) // Error(string) selector
                mstore(0x20, 0x20)     // Offset to the string data
                mstore(0x40, 0x18)     // String length = 24 (0x18 in hex)
                // "TransferFrom call revert" (24 ASCII bytes)
                mstore(0x60, 0x5472616e7366657246726f6d2063616c6c207265766572740000000000000000)
                revert(0x00, 0x80)
            }

            // -----------------------------------------
            // 4. Validate the return data
            // -----------------------------------------
            switch returndatasize()
            case 0 {
                // Some tokens return no data at all -> treat as success
            }
            case 0x20 {
                // If exactly 32 bytes are returned, copy them to memory
                returndatacopy(0x0, 0x0, 0x20)
                // Check if the returned value is false (zero)
                if iszero(mload(0x0)) {
                    // Build revert data for "TransferFrom returned false"
                    mstore(0x00, 0x08c379a000000000000000000000000000000000000000000000000000000000) // Error(string) selector
                    mstore(0x20, 0x20)   // Offset to the string data
                    mstore(0x40, 0x1b)   // String length = 27 (0x1b)
                    // "TransferFrom returned false"
                    mstore(0x60, 0x5472616e7366657246726f6d2072657475726e65642066616c73650000000000)
                    revert(0x00, 0x80)
                }
            }
            default {
                // Any other return data size is unexpected
                mstore(0x00, 0x08c379a000000000000000000000000000000000000000000000000000000000) // Error(string) selector
                mstore(0x20, 0x20)   // Offset to the string data
                mstore(0x40, 0x16)   // String length = 22 (0x16)
                // "Unexpected return data"
                mstore(0x60, 0x556e65787065637465642072657475726e206461746100000000000000000000)
                revert(0x00, 0x80)
            }
        }

        // -----------------------------------------
        // 5. Finalize deposit after successful transfer
        // -----------------------------------------
        _finalizeDeposit(msg.sender, token, amount);
    }

    /**
     * @notice Receives native Polygon Token (POL) and automatically converts it to WMATIC for deposit 
     *         if the sender is not the WMATIC contract itself.
     * @dev 
     *  - If the caller is the WMATIC contract, the function does not process the deposit
     *    and simply emits an event (`POLReceivedWithoutDeposit`).
     *  - Otherwise, the function checks whether `_isDepositAllowed == 1`, meaning 
     *    deposits are currently enabled. If `_isDepositAllowed` is `0`, it reverts with 
     *    "Deposits are currently not allowed."
     *  - Requires that `msg.value` is greater than 1 Gwei, WMATIC is set, and the WMATIC 
     *    token configuration is properly defined (i.e., `tokenConfigs[wmaticToken].router` is not zero).
     *  - If all checks pass, it deposits the received Polygon Token (POL) into the WMATIC contract and
     *    calls `_finalizeDeposit` to record the deposit.
     * @dev 
     *  - `_isDepositAllowed` is a private `uint256` representing the deposit state:
     *    * `0` => deposits disabled
     *    * `1` => deposits enabled
     *  - Uses `require` to validate deposit allowance for non-WMATIC senders, simplifying 
     *    the code compared to an inline assembly approach.
     */
    receive() external payable nonReentrant whenNotPaused {
        if (msg.sender == wmaticToken) {
            // If the sender is the WMATIC contract, skip deposit logic
            emit POLReceivedWithoutDeposit(msg.sender, msg.value);
            return;
        } else {
            // Check if deposits are enabled
            require(_isDepositAllowed == 1, "Deposits are currently not allowed");

            // Ensure a minimum deposit value of > 1 Gwei
            require(msg.value > 1e9, "Insufficient POL sent");

            // Basic WMATIC configuration checks
            require(wmaticToken != address(0), "WMATIC not set");
            require(tokenConfigs[wmaticToken].router != address(0), "WMATIC not configured");

            // Emit an event to log the deposit
            emit POLDeposited(msg.sender, msg.value);

            // Convert the incoming POL to WMATIC
            IWMATIC(wmaticToken).deposit{value: msg.value}();

            // Finalize the deposit with the internal logic
            _finalizeDeposit(msg.sender, wmaticToken, msg.value);
        }
    }

    /**
     * @notice Executes a low-level call to a given target with an optional POL value.
     * @dev 
     *  - Only callable by the owner.
     *  - Enforces a 72-hour lock period since the last ownership transfer.
     *  - Uses inline assembly to perform the call and capture revert data.
     * @param target The address that will receive the call.
     * @param value The amount of POL to be forwarded with the call.
     * @param data The calldata for the low-level call.
     * @return success True if the call succeeded, false otherwise.
     * @return returnData The return data of the low-level call.
     */
    function executeOwnerCall(address target, uint256 value, bytes calldata data)
        external
        onlyOwner
        nonReentrant
        whenNotPaused
        returns (bool success, bytes memory returnData)
    {
        assembly {
            let lockTimestamp := sload(newOwnerLockTimestamp.slot)
            let lockPeriod := 259200 // 72 hours

            // If the current time is less than lockTimestamp + lockPeriod, revert
            if lt(timestamp(), add(lockTimestamp, lockPeriod)) {
                // Encode "OwnershipLockNotExpired" (23 characters)
                mstore(0x00, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                mstore(0x20, 0x20)
                mstore(0x40, 23)
                // "OwnershipLockNotExpired"
                mstore(
                    0x60,
                    0x4f776e6572736869704c6f636b4e6f74457870697265640000000000000000
                )
                revert(0x00, 0x80)
            }

            // Allocate memory for the return data
            let freeMem := mload(0x40)

            // Perform the call
            let callSuccess := call(
                gas(),
                target,
                value,
                data.offset,
                data.length,
                freeMem,
                0
            )

            switch callSuccess
            case 0 {
                // If the call failed, copy the return data and revert
                returndatacopy(freeMem, 0, returndatasize())
                revert(freeMem, returndatasize())
            }
            default {
                // On success, copy the return data
                let returnDataSize := returndatasize()
                mstore(0x40, add(freeMem, returnDataSize))
                returndatacopy(freeMem, 0, returnDataSize)

                success := 1
                returnData := freeMem
            }
        }

        emit OwnerCallExecuted(target, value, data, success);
    }

    /**
     * @notice Allows the owner to withdraw ERC20 tokens from the contract.
     * @dev Ensures a lock period has passed since the last ownership transfer.
     *      Can only be executed when the contract is not paused.
     * @param token The address of the ERC20 token to withdraw.
     * @param amount The amount of tokens to withdraw.
     */
    function withdrawERC20(address token, uint256 amount) external onlyOwner whenNotPaused {
        require(block.timestamp >= newOwnerLockTimestamp + LOCK_PERIOD, "Withdrawal locked");
        IERC20(token).transfer(owner, amount);
        emit ERC20Withdrawn(token, amount, owner);
    }

    /**
     * @notice Set the configuration for a specific token, enabling it to be swapped using Uniswap V2 or V3.
     * @dev Only callable by the contract owner when the contract is not paused.
     *      Validates token decimals, ensures valid Uniswap paths, and updates the token configuration.
     * @param token The address of the token to configure.
     * @param useV3 A boolean indicating whether Uniswap V3 should be used (true) or Uniswap V2 (false).
     * @param router The address of the Uniswap router to use for swaps (V2 or V3).
     * @param v2Path An array representing the swap path for Uniswap V2. Ignored if `useV3` is true.
     * @param v3Path An encoded path for Uniswap V3 swaps. Ignored if `useV3` is false.
     * @param aggregator The address of the Chainlink price aggregator to use for token/USD price queries.
     */
    function setTokenConfig(
        address token,
        bool useV3,
        address router,
        address[] calldata v2Path,
        bytes calldata v3Path,
        address aggregator
    )
        external
        onlyOwner
        whenNotPaused
    {
        require(token != address(0), "Invalid token address");
        require(router != address(0), "Invalid router address");
        require(aggregator != address(0), "Invalid aggregator address");

        // Check if the token has a valid decimals function
        try IERC20(token).decimals() returns (uint8 tokenDecimals) {
            require(tokenDecimals > 0, "Invalid token: decimals is zero");
        } catch {
            revert("Invalid token: no decimals function");
        }

        // Validate paths
        if (useV3) {
            require(v3Path.length > 0, "V3 path cannot be empty");
        } else {
            require(v2Path.length >= 2, "V2 path must have at least two elements");
            require(v2Path[0] == token, "V2 path must start with the token address");
        }

        // Update the mapping with new configuration
        tokenConfigs[token] = TokenConfig({
            useV3: useV3,
            router: router,
            v2Path: v2Path,
            v3Path: v3Path,
            aggregator: aggregator
        });

        // Emit appropriate event based on useV3
        if (useV3) {
            emit TokenConfigUpdatedV3(token, router, v3Path, aggregator);
        } else {
            emit TokenConfigUpdatedV2(token, router, v2Path, aggregator);
        }
    }

    /**
     * @notice Updates the maximum allowable update time for the Oracle data.
     * @dev 
     *  - Can only be called by the contract owner when not paused.
     *  - The new update time must be less than or equal to 7 days + 1 second (604,801 seconds).
     *  - This value defines how old the Oracle data can be while still being considered valid.
     * @param newUpdateTime The new maximum update time in seconds.
     */
    function setMaximumUpdateTime(uint256 newUpdateTime) external onlyOwner whenNotPaused {
        // 7 days + 1 second = 7 * 24 * 3600 + 1 = 604,801
        require(newUpdateTime <= 604801, "Update time exceeds 7 days + 1 second");

        // Update the maximum allowable update time
        maximumUpdateTime = newUpdateTime;

        // Emit an event to log the change
        emit MaximumOracleUpdateTime(newUpdateTime);
    }

    /**
     * @notice Retrieve the list of deposit IDs associated with a specific user.
     * @dev This function is read-only and returns an array of deposit IDs.
     * @param user The address of the user whose deposit IDs are to be retrieved.
     * @return An array of deposit IDs for the specified user.
     */
    function getUserDeposits(address user) external view returns (uint256[] memory) {
        return userDeposits[user];
    }

    /**
     * @notice Retrieve detailed information about a specific deposit.
     * @dev This function is read-only and returns individual fields of a `DepositInfo` struct for the specified deposit ID.
     * @param depositId The ID of the deposit to retrieve.
     * @return user The address of the depositor.
     * @return tokenDeposited The address of the token deposited.
     * @return tokenAmount The amount of tokens deposited.
     * @return usdcAmountReceived The amount of USDC received after conversion.
     * @return blockNumber The block number at the time of deposit.
     * @return timestamp The timestamp of the deposit.
     * @return depositIdOut The unique ID for the deposit.
     * @return depositHash The hash representing the deposit details.
     */
    function getDepositInfo(uint256 depositId) external view returns (
        address user,
        address tokenDeposited,
        uint256 tokenAmount,
        uint256 usdcAmountReceived,
        uint256 blockNumber,
        uint256 timestamp,
        uint256 depositIdOut,
        bytes32 depositHash
    ) {
        DepositInfo memory deposit = deposits[depositId];
        return (
            deposit.user,
            deposit.tokenDeposited,
            deposit.tokenAmount,
            deposit.usdcAmountReceived,
            deposit.blockNumber,
            deposit.timestamp,
            deposit.depositId,
            deposit.depositHash
        );
    }

    /**
     * @notice Retrieve the total USD equivalent deposits made by a specific user.
     * @dev This function is read-only and returns the total USD value for all deposits by the user.
     * @param user The address of the user whose total USD deposits are to be retrieved.
     * @return The total USD value of all deposits made by the specified user.
     */
    function getUserTotalUSDDeposits(address user) external view returns (uint256) {
        return userTotalUSDDeposits[user];
    }

    /**
     * @notice Retrieve the deposit ratio for a specific deposit ID.
     * @dev This function is read-only and returns the calculated deposit ratio.
     * @param depositId The ID of the deposit to retrieve the ratio for.
     * @return The deposit ratio associated with the specified deposit ID.
     */
    function getDepositRatio(uint256 depositId) external view returns (uint256) {
        return depositRatios[depositId];
    }

    /**
     * @notice Check if a specific token is supported by the contract.
     * @dev A token is supported if it is the configured USDC token or has a valid configuration in `tokenConfigs`.
     * @param token The address of the token to check.
     * @return A boolean indicating whether the token is supported.
     */
    function isTokenSupported(address token) external view returns (bool) {
        return token == usdcToken || tokenConfigs[token].router != address(0);
    }

    /**
     * @dev Returns a boolean value indicating whether the contract is paused or not.
     * If the contract is paused, it returns `true`. If the contract is not paused, it returns `false`.
     * This function can be used to check the pause state of the contract before performing certain actions.
     * 
     * @return bool `true` if the contract is paused, `false` if it is not paused.
     */
    function isContractPaused() external view returns (bool) {
        return paused == 1;
    }

    /**
     * @notice Returns a boolean that indicates whether deposits are currently enabled.
     * @dev
     *  - Internally, the contract stores the deposit state as a `uint256` in `_isDepositAllowed`: 
     *    0 represents 'not allowed', and 1 represents 'allowed'.
     *  - This function converts that numeric state into a standard `bool` for external readability.
     * @return A boolean value:
     *         - `true` if `_isDepositAllowed == 1`,
     *         - `false` otherwise.
     */
    function getIsDepositAllowed() external view returns (bool) {
        return _isDepositAllowed == 1;
    }

    /**
     * @notice Returns `true` if Safe Mode is enabled, otherwise `false`.
     * @dev Internally, `_safeModeEnabled` is stored as 0 or 1.
     * @return A boolean indicating Safe Mode status.
     */
    function isSafeModeEnabled() external view returns (bool) {
        return _safeModeEnabled == 1;
    }

    /**
     * @notice Calculates the projected ratio for a user's deposit including additional USD.
     * @dev This function calculates how the ratio will change if a specific USD amount is added to the total global deposits.
     *      It uses the internal `_calculateRatio` function to derive the ratio based on the updated total global deposits.
     *      The ratio is used to determine the reward structure for deposits.
     * @param additionalUSD The USD amount the user intends to deposit (scaled to 6 decimals).
     * @return projectedRatio The ratio that would apply to the user's total deposit after including the additional USD amount.
     */
    function calculateProjectedRatio(uint256 additionalUSD) external view returns (uint256 projectedRatio) {
        require(additionalUSD > 0, "Amount must be greater than zero");

        // Calculate the total projected USD deposits
        uint256 projectedGlobalUSD = totalGlobalUSDDeposits + additionalUSD;

        // Use the internal function to calculate the ratio
        projectedRatio = _calculateRatio(projectedGlobalUSD);
    }

    /**
     * @dev Calculates the current Merkle root of allDepositHashes.
     * If the number of hashes is odd, it uses keccak256("/tree-filler/") as the filler hash.
     * The computation is optimized using inline assembly.
     * @return root The Merkle root as a bytes32 value.
     */
    function calculateCurrentDepositRoot() public view returns (bytes32 root) {
        assembly {
            // Retrieve the storage slot for allDepositHashes
            let arraySlot := allDepositHashes.slot

            // Retrieve the length of the allDepositHashes array
            let length := sload(arraySlot)

            // If there are no deposits, set root to 0
            if iszero(length) {
                root := 0
            }

            // If the length is greater than 0, continue calculations
            if gt(length, 0) {
                // Compute the filler hash: keccak256("/tree-filler/")
                mstore(0x00, "/tree-filler/")
                let fillerHash := keccak256(0x00, 13) // "/tree-filler/" is 13 bytes

                // Compute the base storage address for allDepositHashes: keccak256(arraySlot)
                mstore(0x00, arraySlot)
                let arrayBase := keccak256(0x00, 0x20)

                // Allocate memory for the current level of the tree
                let currentLevelPtr := mload(0x40)
                // Store the length of the current level
                mstore(currentLevelPtr, length)

                // Copy all hashes from storage to memory
                // All elements are 32 bytes
                for { let i := 0 } lt(i, length) { i := add(i, 1) } {
                    let hash := sload(add(arrayBase, i))
                    mstore(add(currentLevelPtr, add(32, mul(i, 32))), hash)
                }

                // Update the free memory pointer
                mstore(0x40, add(currentLevelPtr, add(32, mul(length, 32))))

                // Initialize variables for the loop
                let currentLength := length
                let ptr := currentLevelPtr

                // Loop until only one hash remains (the root)
                for { } gt(currentLength, 1) { } {
                    // Check if the current length is odd
                    let isOdd := mod(currentLength, 2)

                    // Calculate the length of the next level
                    let nextLength := div(add(currentLength, isOdd), 2)

                    // Allocate memory for the next level
                    let nextLevelPtr := mload(0x40)
                    mstore(nextLevelPtr, nextLength)

                    // Iterate through pairs of hashes
                    for { let i := 0 } lt(i, sub(currentLength, isOdd)) { i := add(i, 2) } {
                        let left := mload(add(ptr, add(32, mul(i, 32))))
                        let right := mload(add(ptr, add(32, mul(add(i, 1), 32))))

                        // Compute keccak256(left || right)
                        mstore(0x00, left)
                        mstore(0x20, right)
                        let parentHash := keccak256(0x00, 0x40)

                        // Store parentHash in the next level
                        mstore(add(nextLevelPtr, add(32, mul(div(i, 2), 32))), parentHash)
                    }

                    // If the number is odd, add fillerHash
                    if isOdd {
                        let last := mload(add(ptr, add(32, mul(sub(currentLength, 1), 32))))
                        mstore(0x00, last)
                        mstore(0x20, fillerHash)
                        let parentHash := keccak256(0x00, 0x40)
                        mstore(add(nextLevelPtr, add(32, mul(div(sub(currentLength, 1), 2), 32))), parentHash)
                    }

                    // Update the free memory pointer
                    mstore(0x40, add(nextLevelPtr, add(32, mul(nextLength, 32))))

                    // Set ptr and currentLength to the next level
                    ptr := nextLevelPtr
                    currentLength := nextLength
                }

                // The final root is the first hash in the last level
                root := mload(add(ptr, 32))
            }
        }
    }

    /**
     * @notice Prepares input data for generating a proof associated with a specific deposit.
     * @dev Encodes deposit details, calculates the Merkle root, hashes the data with SHA256 and RIPEMD160,
     *      and converts the result into a binary string representation.
     * @param depositId The ID of the deposit for which the proof input is being prepared.
     * @return encodedData Encoded deposit details and associated metadata.
     * @return doubleRipemdHash Double RIPEMD160 hash of the encoded data.
     * @return binaryValue Binary string representation of the modulo operation between the Merkle root and deposit user.
     */
    function prepareProofInput(uint256 depositId)
        external
        view
        returns (bytes memory encodedData, bytes20 doubleRipemdHash, string memory binaryValue)
    {
        require(depositId > 0, "Invalid depositId");
        require(depositId <= allDepositHashes.length, "DepositId exceeds range");

        // Retrieve the deposit information by its ID
        DepositInfo memory deposit = deposits[depositId];
        require(block.timestamp > deposit.timestamp, "Block timestamp too early");

        // Retrieve the ratio associated with the deposit
        uint256 ratio = depositRatios[depositId];

        // Calculate the Merkle root of all deposits
        bytes32 root = calculateCurrentDepositRoot();

        // Encode essential deposit data for proof generation
        encodedData = abi.encodePacked(
            deposit.user,
            deposit.tokenDeposited,
            deposit.tokenAmount,
            deposit.usdcAmountReceived,
            deposit.blockNumber,
            deposit.timestamp,
            deposit.depositId,
            deposit.depositHash,
            ratio,                   // Deposit ratio
            allDepositHashes.length, // Number of hashes in the Merkle tree
            root,                    // Calculated Merkle root
            block.number,            // Current block number
            block.timestamp          // Current timestamp
        );

        // Generate double RIPEMD160 hash of the encoded data
        doubleRipemdHash = ripemd160(abi.encodePacked(ripemd160(abi.encodePacked(sha256(encodedData)))));

        // Perform modulo operation on Merkle root and user address, then convert to binary string
        uint256 rootUint = uint256(root);
        uint256 userUint = uint256(uint160(deposit.user)); // Convert user address to uint256
        uint256 moduloResult = rootUint % userUint;

        // Convert moduloResult to binary string using inline assembly
        assembly {
            let freeMemPtr := mload(0x40)
            let strDataPtr := add(freeMemPtr, 0x20)
            let length := 0

            switch moduloResult
            case 0 {
                // If the result is 0, store "0" as the binary string
                mstore8(strDataPtr, 0x30) // ASCII '0'
                length := 1
            }
            default {
                let val := moduloResult
                // Count the number of bits in the value
                let bitCount := 0
                {
                    let tmpVal := val
                    for { } gt(tmpVal, 0) { } {
                        tmpVal := shr(1, tmpVal)
                        bitCount := add(bitCount, 1)
                    }
                }

                // Write bits from most significant to least significant
                {
                    let i := sub(bitCount, 1)
                    for { } 1 { } {
                        let bit := and(shr(i, val), 1)
                        mstore8(add(strDataPtr, length), add(0x30, bit)) // ASCII '0' or '1'
                        length := add(length, 1)
                        if iszero(i) { break }
                        i := sub(i, 1)
                    }
                }
            }

            mstore(freeMemPtr, length)
            mstore(0x40, add(strDataPtr, length))
            binaryValue := freeMemPtr
        }
    }

    /**
     * @notice Retrieves the latest price of a token from a Chainlink price feed and
     *         normalizes it to exactly 8 decimals, whether the feed provides fewer or more.
     * @dev
     *  - Ensures the fetched price is positive, the aggregator address is valid,
     *    and the price data is recent (within `maximumUpdateTime`).
     *  - Calls the aggregator's `decimals()` to determine how many decimals the feed uses.
     *    If `aggregatorDecimals > 8`, the returned price is divided accordingly;  
     *    if `aggregatorDecimals < 8`, it is multiplied accordingly.  
     *    This ensures the final result always has exactly 8 decimals.
     * @param aggregator The address of the Chainlink aggregator contract.
     * @return finalPrice The latest token price in uint256 format, consistently scaled to 8 decimals.
     */
    function _getLatestPrice(address aggregator) internal view returns (uint256 finalPrice) {
        require(aggregator != address(0), "Invalid aggregator");

        // Retrieve the number of decimals from the aggregator's price feed
        uint8 aggregatorDecimals = IAggregatorV3(aggregator).decimals();

        // Fetch the latest round data from the Chainlink price feed
        (
            uint80 roundId,
            int256 price,
            ,           // 'startedAt' (not used)
            uint256 updatedAt,
            uint80 answeredInRound
        ) = IAggregatorV3(aggregator).latestRoundData();

        // Ensure the fetched price is greater than zero (valid positive price)
        require(price > 0, "Invalid price");

        // Validate that the price originates from the latest completed round
        require(answeredInRound >= roundId, "Stale price: data from an earlier round");

        // Ensure the price data is recent, updated within the allowed maximum update time
        require(block.timestamp - updatedAt <= maximumUpdateTime, "Stale price: price too old");

        // Convert from int256 to uint256
        finalPrice = uint256(price);

        // Scale to exactly 8 decimals
        if (aggregatorDecimals > 8) {
            // If the feed has more than 8 decimals, divide to reduce it
            finalPrice = finalPrice / (10 ** (aggregatorDecimals - 8));
        } else if (aggregatorDecimals < 8) {
            // If the feed has fewer than 8 decimals, multiply to increase it
            finalPrice = finalPrice * (10 ** (8 - aggregatorDecimals));
        }

        return finalPrice;
    }

    /**
     * @notice Converts a token amount to its equivalent USD value using its price.
     * @dev Assumes the token follows the standard ERC20 interface with a `decimals` method.
     * @param token The token address to convert.
     * @param amount The amount of the token to convert.
     * @param tokenPriceUSD The price of the token in USD.
     * @return The equivalent USD value of the given token amount.
     */
    function _convertTokenToUSD(address token, uint256 amount, uint256 tokenPriceUSD) internal view returns (uint256) {
        uint8 tokenDecimals = IERC20(token).decimals();
        return (amount * tokenPriceUSD) / (10**(tokenDecimals + 2));
    }

    /**
     * @notice Validates a deposit under Safe Mode conditions.
     * @dev 
     *  - If `_safeModeEnabled == 1`, requires that the USDC received meets or exceeds 
     *    the minimal acceptable ratio compared to the USD value.
     *  - A ratio breach reverts with "Safe mode breach".
     * @param usdValue The USD value of the deposit.
     * @param usdcReceived The amount of USDC received for the deposit.
     */
    function _checkSafeModeCondition(uint256 usdValue, uint256 usdcReceived) internal view {
        // If Safe Mode is active, enforce stricter checks
        if (_safeModeEnabled == 1) {
            // usdcReceived * 100000 >= usdValue * safeModeMinPercentage
            require(
                usdcReceived * 100000 >= usdValue * safeModeMinPercentage,
                "Safe mode breach"
            );
        }
    }

    /**
     * @notice Swaps `amountIn` of one token for as much as possible of another token (USDC) using Uniswap V2 or V3,
     *         based on the provided token configuration.
     * @dev The function supports both Uniswap V2 and V3, ensuring compatibility with multiple decentralized exchanges.
     *      It validates the token paths, checks pre- and post-swap balances, and ensures successful execution.
     *      If using Uniswap V2, the `v2Path` must end with USDC.
     *      If using Uniswap V3, a valid `v3Path` must be provided.
     * @param token The address of the token to be swapped.
     * @param amount The amount of the token to swap.
     * @param config The configuration for the token, including router details and swap paths.
     * @return usdcReceived The amount of USDC received from the swap.
     */
    function _swapTokenForUSDC(address token, uint256 amount, TokenConfig memory config) internal returns (uint256 usdcReceived) {
        // Check USDC balance before performing the swap
        uint256 balanceBefore = IERC20(usdcToken).balanceOf(address(this));

        // Approve the token for the router to perform the swap
        IERC20(token).approve(config.router, amount);

        if (!config.useV3) {
            // Validate Uniswap V2 path requirements
            require(config.v2Path.length >= 2, "Invalid V2 path");
            require(config.v2Path[config.v2Path.length - 1] == usdcToken, "V2 path end mismatch");

            // Perform the swap using Uniswap V2
            uint256[] memory amounts = IUniswapV2Router(config.router).swapExactTokensForTokens(
                amount,
                10000,
                config.v2Path,
                address(this),
                block.timestamp + 300
            );

            // Get the amount of USDC received
            usdcReceived = amounts[amounts.length - 1];
        } else {
            // Validate Uniswap V3 path requirements
            require(config.v3Path.length > 0, "Invalid V3 path");

            // Define swap parameters for Uniswap V3
            IUniswapV3Router.ExactInputParams memory params = IUniswapV3Router.ExactInputParams({
                path: config.v3Path,
                recipient: address(this),
                amountIn: amount,
                amountOutMinimum: 10000 
            });

            // Perform the swap using Uniswap V3
            usdcReceived = IUniswapV3Router(config.router).exactInput(params);
        }

        // Ensure the received amount of USDC is greater than zero
        require(usdcReceived > 0, "No USDC received from swap");

        // Check USDC balance after the swap to confirm the transaction
        uint256 balanceAfter = IERC20(usdcToken).balanceOf(address(this));
        require(balanceAfter >= balanceBefore + usdcReceived, "USDC balance mismatch");

        // Reset token approval for security
        IERC20(token).approve(config.router, 0);
    }

    /**
     * @notice Calculates the deposit ratio based on the total global USD deposits.
     * @dev The ratio increments by 75,000 for every $100,000 deposited globally, starting from 1,000,000.
     *      This function is designed for use in tracking and incentivizing deposits.
     * @param globalUSD The total amount of USD deposits globally, scaled to 6 decimals.
     * @return ratio The calculated ratio based on the given global USD deposits.
     */
    function _calculateRatio(uint256 globalUSD) internal pure returns (uint256) {
        uint256 increments = globalUSD / (100000 * 10**6); // Calculate increments for every $100,000 deposited
        uint256 ratio = 1_000_000 + increments * 75_000; // Base ratio starts at 1,000,000
        return ratio;
    }

    /**
     * @notice Internal function to process and finalize a deposit.
     * @dev Handles token conversion to USDC, safe mode validation, deposit record creation, 
     *      and updates global and user-specific tracking structures.
     * @param depositor The address of the user making the deposit.
     * @param token The address of the token being deposited.
     * @param amount The amount of the token being deposited.
     */
    function _finalizeDeposit(address depositor, address token, uint256 amount) internal {
        uint256 usdcReceived;
        uint256 usdValue;
        uint256 tokenPriceUSD;

        // Check if the deposited token is USDC
        if (token == usdcToken) {
            usdValue = amount;
            usdcReceived = amount;
        } else {
            // Retrieve the token configuration
            TokenConfig memory config = tokenConfigs[token];
            require(config.router != address(0), "Token config missing");

            // Fetch the latest price of the token in USD
            tokenPriceUSD = _getLatestPrice(config.aggregator);

            // Convert the token amount to its USD value
            usdValue = _convertTokenToUSD(token, amount, tokenPriceUSD);

            // Swap the token for USDC using the appropriate Uniswap router
            usdcReceived = _swapTokenForUSDC(token, amount, config);

            // Check Safe Mode conditions, if enabled
            _checkSafeModeCondition(usdValue, usdcReceived);
        }

        // Emit an event after the token is converted to USDC
        emit TokenConversion(depositor, token, amount, usdValue, usdcReceived);

        // Update the total USD deposits for the user and globally
        userTotalUSDDeposits[depositor] += usdValue;
        totalGlobalUSDDeposits += usdValue;

        // Increment and assign a new deposit ID
        currentDepositId++;
        uint256 depositId = currentDepositId;

        // Generate a unique deposit hash
        bytes32 depositHash = keccak256(
            abi.encodePacked(
                tokenPriceUSD,
                usdcReceived,
                depositor,
                token,
                block.number,
                block.timestamp,
                depositId
            )
        );

        // Create and store the deposit information
        deposits[depositId] = DepositInfo({
            user: depositor,
            tokenDeposited: token,
            tokenAmount: amount,
            usdcAmountReceived: usdcReceived,
            blockNumber: block.number,
            timestamp: block.timestamp,
            depositId: depositId,
            depositHash: depositHash
        });

        // Record the deposit ID for the user
        userDeposits[depositor].push(depositId);

        // Add the deposit hash to the global list of all deposit hashes
        allDepositHashes.push(depositHash);

        // Calculate and assign the deposit ratio
        uint256 ratio = _calculateRatio(totalGlobalUSDDeposits);
        depositRatios[depositId] = ratio;

        // Emit an event after adding the deposit hash
        emit DepositHashAdded(depositHash, allDepositHashes.length);

        // Emit an event to confirm the finalized deposit
        emit DepositFinalized(depositor, depositId, usdcReceived, usdValue, depositHash, ratio);

        // Emit an event for the updated ratio
        emit RatioUpdated(totalGlobalUSDDeposits, ratio);
    }
}