// SPDX-License-Identifier: BSL1.1
pragma solidity >=0.8.0 <0.9.0;

import "./openzeppelin_contracts-upgradeable_access_AccessControlUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";
import "./openzeppelin_contracts-upgradeable_proxy_utils_UUPSUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_access_OwnableUpgradeable.sol";
import "./openzeppelin_contracts_utils_cryptography_MerkleProof.sol";
import "./openzeppelin_contracts_proxy_ERC1967_ERC1967Proxy.sol";

import "./contracts_v1.1_lib_UnsafeCalldataBytesLib.sol";
import "./contracts_v1.1_evm_VerificationLib.sol";

// import "hardhat/console.sol";

contract UDFOracle is
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    AccessControlUpgradeable
{
    error UDFOracle__PullOracleFeeNotReceived();
    error UDFOracle__OutdatedData();

    bytes32 public constant ADMIN = keccak256("ADMIN");
    bytes32 public constant PUBLISHER = keccak256("PUBLISHER");

    uint256 public pullCommision;

    struct LatestUpdate {
        /// @notice The price for asset from latest update
        uint256 latestPrice;
        /// @notice The timestamp of latest update
        uint256 latestTimestamp;
    }

    VerificationLib public verificationLib;

    /// @notice mapping of dataKey to the latest update
    mapping(bytes32 dataKey => LatestUpdate) public latestUpdate;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _verificationLib,
        uint256 _pullComission
    ) public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        verificationLib = VerificationLib(_verificationLib);
        pullCommision = _pullComission;
        _setRoleAdmin(ADMIN, ADMIN);
        _setRoleAdmin(PUBLISHER, ADMIN);
        _grantRole(ADMIN, msg.sender);
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    /// @notice Accept updates encoded to array of bytes, verifies the updates and returns(pull model)
    /// @param encodedData The encoded data - `<MAGIC><n_updates>(<feedKey><n_votes>(<feedKey><value><timestamp><sig_r><sig_s><sig_v>)...)...`
    /**
     *@dev Data format for EVM chain updates.
     *
     * Format: <MAGIC><n_updates>(<feedKey><n_votes>(<feedKey><value><timestamp><sig_r><sig_s><sig_v>)...)...
     *
     * Structure:
     * - `Magic feed data key` (4 bytes): MAGIC (must be 0x55444646 for UDF)
     * - `update_length` (1 byte): Number of updates.
     * - `updates_array`:
     *
     *      - `feedKey` (8 bytes)
     *      - `n_votes` (1 byte)
     *
     *      - `votes_array`:
     *
     *         - `value` (8 bytes)
     *         - `timestamp` (8 bytes)
     *         - `r` (8 bytes): R component of the signature.
     *         - `s` (8 bytes): S component of the signature.
     *         - `v` (1 byte): V component of the signature.
     *
     *      - `end_of_votes_array`
     *
     * - `end_of_updates_array`
     */
    function updatePriceFeeds(
        bytes calldata encodedUpdates
    )
        external
        payable
        returns (
            uint256[] memory values,
            uint256[] memory timestamps,
            bytes32[] memory feedKeys
        )
    {
        uint8 nUpdates = UnsafeCalldataBytesLib.toUint8(encodedUpdates, 4);
        if (msg.value < pullCommision * nUpdates) {
            revert UDFOracle__PullOracleFeeNotReceived();
        }
        (values, timestamps, feedKeys) = verificationLib.processData(
            encodedUpdates
        );
        for (uint8 i = 0; i < values.length; ) {
            if (latestUpdate[feedKeys[i]].latestTimestamp >= timestamps[i]) {
                revert UDFOracle__OutdatedData();
            }
            unchecked {
                i++;
            }
        }
    }

    /// @notice Accept updates encoded to array of bytes, verifies the updates and stores on chain
    /// @param encodedData The encoded data - `<MAGIC><n_updates>(<feedKey><n_votes>(<feedKey><value><timestamp><sig_r><sig_s><sig_v>)...)...`
    /**
     *@dev Data format for EVM chain updates.
     *
     * Format: <MAGIC><n_updates>(<feedKey><n_votes>(<feedKey><value><timestamp><sig_r><sig_s><sig_v>)...)...
     *
     * Structure:
     * - `Magic feed data key` (4 bytes): MAGIC (must be 0x55444646 for UDF)
     * - `update_length` (1 byte): Number of updates.
     * - `updates_array`:
     *
     *      - `feedKey` (8 bytes)
     *      - `n_votes` (1 byte)
     *
     *      - `votes_array`:
     *
     *         - `value` (8 bytes)
     *         - `timestamp` (8 bytes)
     *         - `r` (8 bytes): R component of the signature.
     *         - `s` (8 bytes): S component of the signature.
     *         - `v` (1 byte): V component of the signature.
     *
     *      - `end_of_votes_array`
     *
     * - `end_of_updates_array`
     */
    function pushPriceFeeds(
        bytes calldata encodedUpdates
    ) external onlyRole(PUBLISHER) {
        (
            uint256[] memory values,
            uint256[] memory timestamps,
            bytes32[] memory feedKeys
        ) = verificationLib.processData(encodedUpdates);

        for (uint8 i = 0; i < values.length; ) {
            // Load the latest update into memory
            LatestUpdate storage latest = latestUpdate[feedKeys[i]];
            if (latest.latestTimestamp < timestamps[i]) {
                // Store the median value with corresponding feedKey and timestamp
                latest.latestPrice = values[i];
                latest.latestTimestamp = timestamps[i];
            }
            unchecked {
                i++;
            }
        }
    }

    function calcPullOracleComission(
        bytes calldata encodedUpdates
    ) external view returns (uint256) {
        uint8 nUpdates = UnsafeCalldataBytesLib.toUint8(encodedUpdates, 4);
        return pullCommision * nUpdates;
    }

    function setVerificationLibAddress(
        address _verificationLib
    ) external onlyRole(ADMIN) {
        verificationLib = VerificationLib(_verificationLib);
    }

    function setPullOracleComission(
        uint256 _comission
    ) external onlyRole(ADMIN) {
        pullCommision = _comission;
    }
}