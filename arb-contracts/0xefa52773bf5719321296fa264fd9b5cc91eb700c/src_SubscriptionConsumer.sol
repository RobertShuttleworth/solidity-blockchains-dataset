// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {VRFConsumerBaseV2Plus} from "./lib_chainlink-brownie-contracts_contracts_src_v0.8_vrf_dev_VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "./lib_chainlink-brownie-contracts_contracts_src_v0.8_vrf_dev_libraries_VRFV2PlusClient.sol";

contract SubscriptionConsumer is VRFConsumerBaseV2Plus {
    struct RequestStatus {
        bool fulfilled; // whether the request has been successfully fulfilled
        bool exists; // whether a requestId exists
        uint256[] randomWords; // array of random words received
    }

    mapping(uint256 requestId => RequestStatus) requests; // mapping to store request statuses

    uint256 public subscriptionId; // Chainlink VRF subscription ID

    uint256 private _lastRequestId; // stores the last request ID
    uint256[] public requestIds; // array of all request IDs for tracking

    uint16 public requestConfirmations = 3; // number of confirmations before fulfilling the request
    uint32 public callbackGasLimit = 2500000; // gas limit for the VRF callback
    bytes32 public keyHash; // specifies the gas lane for VRF

    // true - pay fee for VRF Request in native token(ex/ ETH)
    // false - pay fee in LINK token (cheaper)
    bool public enableNativePayment = true;

    event RequestSent(uint256 requestId, uint32 numWords); // emitted when a request is sent
    event RequestFulfilled(uint256 requestId, uint256[] randomWords); // emitted when a request is fulfilled

    error RequestNotFound(); // error thrown if request does not exist

    /**
     * @dev Throws if called request doesn't exist.
     */
    modifier requestExists(uint256 _requestId) {
        require(requests[_requestId].exists, RequestNotFound());
        _;
    }

    /**
     * @dev Constructor for the contract.
     * @param vrfCoordinator Address of the Chainlink VRF Coordinator.
     * @param _keyHash Key hash for selecting the VRF configuration.
     * @param _subscriptionId Subscription ID for Chainlink VRF.
     */
    constructor(address vrfCoordinator, bytes32 _keyHash, uint256 _subscriptionId)
        VRFConsumerBaseV2Plus(vrfCoordinator)
    {
        keyHash = _keyHash;
        subscriptionId = _subscriptionId;
    }

    /**
     * @dev Updates the gas limit for the VRF callback.
     * This function is only callable by the owner of the contract.
     * @param _callbackGasLimit New gas limit to set.
     */
    function setCallbackGasLimit(uint32 _callbackGasLimit) external onlyOwner {
        callbackGasLimit = _callbackGasLimit;
    }

    /**
     * @dev Updates the number of confirmations required for VRF.
     * This function is only callable by the owner of the contract.
     * @param _requestConfirmations New number of confirmations to set.
     */
    function setRequestConfirmations(uint16 _requestConfirmations) external onlyOwner {
        requestConfirmations = _requestConfirmations;
    }

    /**
     * @dev Toggles the payment method for VRF (native token or LINK).
     * This function is only callable by the owner of the contract.
     * @param _useNativePayment Boolean indicating if native payment should be used.
     */
    function setEnableNativePayment(bool _useNativePayment) external onlyOwner {
        enableNativePayment = _useNativePayment;
    }

    /**
     * @dev Retrieves the status of a VRF request.
     * @param _requestId ID of the request to check.
     * @return fulfilled Indicates if the request was fulfilled.
     * @return randomWords Array of random words generated for the request.
     */
    function getRequestStatus(uint256 _requestId)
        external
        view
        requestExists(_requestId)
        returns (bool fulfilled, uint256[] memory randomWords)
    {
        RequestStatus memory request = requests[_requestId];
        return (request.fulfilled, request.randomWords);
    }

    /**
     * @dev Returns the ID of the last request made.
     * @return ID of the last request.
     */
    function lastRequestId() public view returns (uint256) {
        return _lastRequestId;
    }

    /**
     * @dev Internal function to request random words from the VRF.
     * Assumes the subscription is sufficiently funded.
     * @param numWords Number of random words in one request.Cannot exceed VRFCoordinatorV2_5.MAX_NUM_WORDS.
     * @return requestId ID of the VRF request.
     */
    function _requestRandomWords(uint32 numWords) internal returns (uint256 requestId) {
        // Will revert if subscription is not set and funded.
        requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: keyHash,
                subId: subscriptionId,
                requestConfirmations: requestConfirmations,
                callbackGasLimit: callbackGasLimit,
                numWords: numWords,
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: enableNativePayment}))
            })
        );

        // Initialize the request status
        requests[requestId] = RequestStatus({randomWords: new uint256[](0), exists: true, fulfilled: false});
        requestIds.push(requestId);
        _lastRequestId = requestId;

        emit RequestSent(requestId, numWords);
        return requestId;
    }

    /**
     * @dev Callback function for the VRF to fulfill random words.
     * @param _requestId ID of the request being fulfilled.
     * @param _randomWords Array of random words generated by the VRF.
     */
    function fulfillRandomWords(uint256 _requestId, uint256[] calldata _randomWords)
        internal
        override
        requestExists(_requestId)
    {
        requests[_requestId].fulfilled = true;
        requests[_requestId].randomWords = _randomWords;
        emit RequestFulfilled(_requestId, _randomWords);
    }
}