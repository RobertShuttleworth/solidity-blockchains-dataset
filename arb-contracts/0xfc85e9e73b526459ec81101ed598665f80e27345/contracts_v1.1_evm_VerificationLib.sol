// SPDX-License-Identifier: BSL1.1
pragma solidity >=0.8.0 <0.9.0;

import "./openzeppelin_contracts-upgradeable_access_AccessControlUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";
import "./openzeppelin_contracts-upgradeable_proxy_utils_UUPSUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_access_OwnableUpgradeable.sol";
import "./entangle_protocol_oracle-sdk_contracts_interfaces_IEndPoint.sol";

import "./contracts_v1.1_lib_UnsafeCalldataBytesLib.sol";
// import "hardhat/console.sol";

contract VerificationLib is
    Initializable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    OwnableUpgradeable
{
    error VerificationLib__WrongUDFMagic();
    error VerificationLib__ZeroVotes();
    error VerificationLib__NotAllowedTransmitter(address);
    error VerificationLib__VotesTimestampExpired();
    error VerificationLib__DuplicateTransmitter(address);
    error VerificationLib__VotesThresholdNotReached(uint256);
    error VerificationLib__NotSortedVotes();
    error VerificationLib__ZeroSignerAddress();

    bytes32 public constant ADMIN = keccak256("ADMIN");

    bytes32 public protocolId;
    uint256 public timeThreshold; // threshold time in seconds
    uint256 public votesThreshold;

    IEndPoint public endPoint;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializer
    /// @param initAddr - 0: admin
    function initialize(
        address[1] calldata initAddr,
        bytes32 _protocolId,
        uint256 _timeThreshold,
        uint256 _votesThreshold,
        address _endPoint
    ) public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();

        protocolId = _protocolId;
        endPoint = IEndPoint(_endPoint);
        timeThreshold = _timeThreshold;
        votesThreshold = _votesThreshold;
        _setRoleAdmin(ADMIN, ADMIN);
        _grantRole(ADMIN, initAddr[0]);
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function processData(
        bytes calldata encodedUpdates
    )
        external
        view
        returns (uint256[] memory, uint256[] memory, bytes32[] memory)
    {
        // Decode the MAGIC number (first 4 bytes)
        bytes4 magic = UnsafeCalldataBytesLib.toBytes4(encodedUpdates, 0);
        if (magic != 0x55444646) {
            revert VerificationLib__WrongUDFMagic();
        }
        // console.logBytes4(magic);

        // Number of updates (next byte)
        uint8 nUpdates = UnsafeCalldataBytesLib.toUint8(encodedUpdates, 4);
        // console.log(nUpdates);

        uint256 offset = 5; // Start after MAGIC and nUpdates
        uint256[] memory medianUpdates = new uint256[](nUpdates);
        uint256[] memory timestampUpdates = new uint256[](nUpdates);
        bytes32[] memory feedKeyUpdates = new bytes32[](nUpdates);
        uint256 _timeThreshold = timeThreshold;
        uint256 _votesThreshold = votesThreshold;
        IEndPoint _endPoint = endPoint;
        bytes32 _protocolId = protocolId;
        for (uint8 i = 0; i < nUpdates; i++) {
            bytes32 feedKey = UnsafeCalldataBytesLib.toBytes32(
                encodedUpdates,
                offset
            );
            offset += 32; // Move past feedKey
            // console.logBytes32(feedKey);
            uint8 nVotes = UnsafeCalldataBytesLib.toUint8(
                encodedUpdates,
                offset
            );
            // console.log(nVotes);
            if (nVotes == 0) {
                revert VerificationLib__ZeroVotes();
            }

            offset += 1; // Move past nVotes

            uint256[] memory values = new uint256[](nVotes);
            uint256[] memory timestamps = new uint256[](nVotes);
            address[] memory uniqueSigners = new address[](nVotes);
            uint256 nUniqueSigners = 0;

            for (uint8 j = 0; j < nVotes; j++) {
                uint256 value = UnsafeCalldataBytesLib.toUint256(
                    encodedUpdates,
                    offset
                );
                offset += 32; // Move past value
                // console.log(value);
                uint256 timestamp = UnsafeCalldataBytesLib.toUint256(
                    encodedUpdates,
                    offset
                );
                offset += 32; // Move past timestamp
                // console.log(timestamp);
                bytes32 r = UnsafeCalldataBytesLib.toBytes32(
                    encodedUpdates,
                    offset
                );
                offset += 32; // Move past r
                // console.logBytes32(r);
                bytes32 s = UnsafeCalldataBytesLib.toBytes32(
                    encodedUpdates,
                    offset
                );
                offset += 32; // Move past s
                // console.logBytes32(s);
                uint8 v = UnsafeCalldataBytesLib.toUint8(
                    encodedUpdates,
                    offset
                );
                offset += 1; // Move past v

                // Verify signature
                bytes32 messageHash = keccak256(
                    abi.encodePacked(
                        "\x19Ethereum Signed Message:\n32",
                        keccak256(abi.encodePacked(feedKey, value, timestamp))
                    )
                );

                address signer = ecrecover(messageHash, v, r, s);
                if (signer == address(0)) {
                    revert VerificationLib__ZeroSignerAddress();
                }
                bool isAllowed = _endPoint.allowedTransmitters(
                    _protocolId,
                    signer
                );
                if (!isAllowed) {
                    revert VerificationLib__NotAllowedTransmitter(signer);
                }
                // Check for duplicate signer
                bool isDuplicate = false;
                for (uint256 k = 0; k < nUniqueSigners; k++) {
                    if (uniqueSigners[k] == signer) {
                        isDuplicate = true;
                        break;
                    }
                }

                if (isDuplicate) {
                    revert VerificationLib__DuplicateTransmitter(signer);
                }

                // Store this signer as unique
                uniqueSigners[nUniqueSigners] = signer;
                nUniqueSigners++;

                // Store values and timestamps
                values[j] = value;
                timestamps[j] = timestamp;
            }
            if (nUniqueSigners < _votesThreshold) {
                revert VerificationLib__VotesThresholdNotReached(
                    nUniqueSigners
                );
            }

            // console.log(timestamps[0]);
            // Check if more than half of votes are older than the threshold
            if (!isRecent(_timeThreshold, timestamps)) {
                revert VerificationLib__VotesTimestampExpired();
            }

            // Calculate the median value from values array
            medianUpdates[i] = calculateMedian(values);
            timestampUpdates[i] = _max(timestamps);
            feedKeyUpdates[i] = feedKey;
        }
        return (medianUpdates, timestampUpdates, feedKeyUpdates);
    }

    // TODO turn this functions to internal after testing
    function calculateMedian(
        uint256[] memory values
    ) internal pure returns (uint256) {
        uint256 length = values.length;

        // Check if the array is sorted
        for (uint256 i = 0; i < length - 1; i++) {
            if (values[i] > values[i + 1]) {
                revert VerificationLib__NotSortedVotes();
            }
        }

        // Calculate median
        if (length % 2 == 1) {
            return values[length / 2]; // Odd case
        } else {
            return (values[length / 2 - 1] + values[length / 2]) / 2; // Even case
        }
    }

    function isRecent(
        uint256 _timeThreshold,
        uint256[] memory timestamps
    ) internal view returns (bool) {
        uint256 countOlder = 0;
        uint256 currentTime = block.timestamp;
        // console.log(currentTime);
        for (uint256 i = 0; i < timestamps.length; i++) {
            if (currentTime - timestamps[i] > _timeThreshold) {
                countOlder++;
            }
        }

        return countOlder <= timestamps.length / 2; // More than half should not be older
    }

    function _max(uint256[] memory numbers) internal pure returns (uint256) {
        uint256 maxNumber;

        for (uint256 i = 0; i < numbers.length; i++) {
            if (numbers[i] > maxNumber) {
                maxNumber = numbers[i];
            }
        }

        return maxNumber;
    }

    function setEndpointAddress(address _endPoint) external onlyRole(ADMIN) {
        endPoint = IEndPoint(_endPoint);
    }

    function setVotesThreshold(uint256 _votesNum) external onlyRole(ADMIN) {
        votesThreshold = _votesNum;
    }

    function setTimeThreshold(uint256 _timeThreshold) external onlyRole(ADMIN) {
        timeThreshold = _timeThreshold;
    }
}