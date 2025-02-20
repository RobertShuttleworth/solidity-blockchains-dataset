// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./contracts_utils_Strings.sol";

import "./contracts_access_ViciOwnable.sol";
import "./contracts_lib_Monotonic.sol";
import "./contracts_lib_StateMachine.sol";
import "./contracts_metadata_DynamicURI.sol";
import "./contracts_ERC721_extensions_IDropManagement.sol";

/**
 * @title Drop Management
 * @notice (c) 2023 ViciNFT https://vicinft.com/
 * @author Josh Davis <josh.davis@vicinft.com>
 * 
 * @dev A "drop" is a subset of a token collection with its own maximum size 
 * and its own scheme for resolving token metadata.
 * @dev Manages tokens within a drop using a state machine. Tracks the current 
 * state of each token. If there are multiple drops, each drop has its own 
 * state machine. A token's URI can change when its state changes.
 * @dev The state's data field contains the base URI for the state.
 * @dev The main token contract MUST be the owner of this contract.
 * @dev Main contracts SHOULD refer to this contract via the IDropManagement
 * interface
 */
contract DropManagement is ViciOwnable, IDropManagement {
    using Strings for string;
    using StateMachine for StateMachine.States;
    using Monotonic for Monotonic.Counter;

    Monotonic.Counter tokensReserved;
    Monotonic.Counter tokensMinted;
    uint256 maxSupply;
    bool requireCategory;
    string defaultBaseURI;
    mapping(uint256 => string) customURIs;
    bytes32[] allDropNames;
    mapping(bytes32 => ManagedDrop) dropByName;
    mapping(uint256 => bytes32) dropNameByTokenId;

    /* ################################################################
     * Initialization
     * ##############################################################*/

    function initialize(uint256 _maxSupply) public virtual initializer {
        __DropManagement_init(_maxSupply);
    }

    function __DropManagement_init(uint256 _maxSupply)
        internal
        onlyInitializing
    {
        __Ownable_init();
        __DropManagement_init_unchained(_maxSupply);
    }

    function __DropManagement_init_unchained(uint256 _maxSupply)
        internal
        onlyInitializing
    {
        maxSupply = _maxSupply;
    }

    /**
     * @dev reverts unless `dropName` is empty or refers to an existing drop.
     * @dev if `tokenData.requireCategory` is true, also reverts if `dropName`
     *     is empty.
     */
    modifier validDropName(bytes32 dropName) {
        if (dropName != bytes32(0) || requireCategory) {
            require(_isRealDrop(dropByName[dropName].drop), "invalid category");
        }
        _;
    }

    /**
     * @dev reverts if `dropName` does not rever to an existing drop.
     * @dev This does not check whether the drop is active.
     */
    modifier realDrop(bytes32 dropName) {
        require(_isRealDrop(dropByName[dropName].drop), "invalid category");
        _;
    }

    /**
     * @dev reverts if the baseURI is an empty string.
     */
    modifier validBaseURI(string memory baseURI) {
        require(bytes(baseURI).length > 0, "empty base uri");
        _;
    }

    /* ################################################################
     * Queries
     * ##############################################################*/

    /**
     * @dev Returns the total maximum possible size for the collection.
     */
    function getMaxSupply() public view virtual override returns (uint256) {
        return maxSupply;
    }

    /**
     * @dev returns the amount available to be minted outside of any drops, or
     *     the amount available to be reserved in new drops.
     * @dev {total available} = {max supply} - {amount minted so far} -
     *      {amount remaining in pools reserved for drops}
     */
    function totalAvailable() public view virtual override returns (uint256) {
        return maxSupply - tokensMinted.current() - tokensReserved.current();
    }

    /**
     * @dev see IERC721Enumerable
     */
    function totalSupply() public view virtual override returns (uint256) {
        return tokensMinted.current();
    }

    /* ################################################################
     * URI Management
     * ##############################################################*/

    /**
     * @dev Base URI for computing {tokenURI}. The resulting URI for each
     * token will be he concatenation of the `baseURI` and the `tokenId`.
     */
    function getBaseURI() public view virtual override returns (string memory) {
        return defaultBaseURI;
    }

    /**
     * @dev Change the base URI for the named drop.
     */
    function setBaseURI(string memory baseURI)
        public
        virtual
        override
        onlyOwner
        validBaseURI(baseURI)
    {
        require(
            keccak256(bytes(baseURI)) != keccak256(bytes(defaultBaseURI)),
            "base uri unchanged"
        );
        defaultBaseURI = baseURI;
    }

    /**
     * @dev get the base URI for the named drop.
     * @dev if `dropName` is the empty string, returns the baseURI for any
     *     tokens minted outside of a drop.
     */
    function getBaseURIForDrop(bytes32 dropName)
        public
        view
        virtual
        override
        realDrop(dropName)
        returns (string memory)
    {
        ManagedDrop storage currentDrop = dropByName[dropName];
        return
            _getBaseURIForState(
                currentDrop,
                currentDrop.stateMachine.initialStateName()
            );
    }

    /**
     * @dev Change the base URI for the named drop.
     */
    function setBaseURIForDrop(bytes32 dropName, string memory baseURI)
        public
        virtual
        override
        onlyOwner
        realDrop(dropName)
        validBaseURI(baseURI)
    {
        ManagedDrop storage currentDrop = dropByName[dropName];
        require(
            keccak256(bytes(baseURI)) !=
                keccak256(bytes(currentDrop.drop.baseURI)),
            "base uri unchanged"
        );
        currentDrop.drop.baseURI = baseURI;

        currentDrop.stateMachine.setStateData(
            currentDrop.stateMachine.initialStateName(),
            bytes(abi.encode(baseURI))
        );
    }

    /**
     * @dev return the base URI for the named state in the named drop.
     * @param dropName The name of the drop
     * @param stateName The state to be updated.
     *
     * Requirements:
     *
     * - `dropName` MUST refer to a valid drop.
     * - `stateName` MUST refer to a valid state for `dropName`
     * - `dropName` MAY refer to an active or inactive drop
     */
    function getBaseURIForState(bytes32 dropName, bytes32 stateName)
        public
        view
        virtual
        override
        realDrop(dropName)
        returns (string memory)
    {
        ManagedDrop storage currentDrop = dropByName[dropName];
        return _getBaseURIForState(currentDrop, stateName);
    }

    /**
     * @dev Change the base URI for the named state in the named drop.
     */
    function setBaseURIForState(
        bytes32 dropName,
        bytes32 stateName,
        string memory baseURI
    )
        public
        virtual
        override
        onlyOwner
        realDrop(dropName)
        validBaseURI(baseURI)
    {
        ManagedDrop storage currentDrop = dropByName[dropName];
        require(_isRealDrop(currentDrop.drop));
        require(
            keccak256(bytes(baseURI)) !=
                keccak256(bytes(currentDrop.drop.baseURI)),
            "base uri unchanged"
        );

        currentDrop.stateMachine.setStateData(stateName, abi.encode(baseURI));
    }

    /**
     * @dev Override the baseURI + tokenId scheme for determining the token
     * URI with the specified custom URI.
     *
     * @param tokenId The token to use the custom URI
     * @param newURI The custom URI
     *
     * Requirements:
     *
     * - `tokenId` MAY refer to an invalid token id. Setting the custom URI
     *      before minting is allowed.
     * - `newURI` MAY be an empty string, to clear a previously set customURI
     *      and use the default scheme.
     */
    function setCustomURI(uint256 tokenId, string calldata newURI)
        public
        virtual
        override
        onlyOwner
    {
        customURIs[tokenId] = newURI;
        emit URI(newURI, tokenId);
    }

    /**
     * @dev Use this contract to override the default mechanism for
     *     generating token ids.
     *
     * Requirements:
     * - `dynamicURI` MAY be the null address, in which case the override is
     *     removed and the default mechanism is used again.
     * - If `dynamicURI` is not the null address, it MUST be a contract with a
     *     tokenURI(uint256) function (0xc87b56dd).
     */
    function setDynamicURI(bytes32 dropName, DynamicURI dynamicURI)
        public
        virtual
        override
        onlyOwner
        validDropName(dropName)
    {
        dropByName[dropName].dynamicURI = dynamicURI;
    }

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     *
     * @param tokenId the tokenId
     */
    function getTokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        // We have to convert string to bytes to check for existence
        bytes memory customUriBytes = bytes(customURIs[tokenId]);
        if (customUriBytes.length > 0) {
            return customURIs[tokenId];
        }

        ManagedDrop storage currentDrop = dropByName[
            dropNameByTokenId[tokenId]
        ];

        if (address(currentDrop.dynamicURI) != address(0)) {
            string memory dynamic = currentDrop.dynamicURI.tokenURI(tokenId);
            if (bytes(dynamic).length > 0) {
                return dynamic;
            }
        }

        string memory base = defaultBaseURI;
        if (_isRealDrop(currentDrop.drop)) {
            bytes32 stateName = currentDrop.stateForToken[tokenId];
            if (stateName == bytes32(0)) {
                return currentDrop.drop.baseURI;
            } else {
                base = _getBaseURIForState(currentDrop, stateName);
            }
        }
        if (bytes(base).length > 0) {
            return string(abi.encodePacked(base, Strings.toString(tokenId)));
        }

        return base;
    }

    /* ################################################################
     * Drop Management - Queries
     * ##############################################################*/

    /**
     * @dev Returns the number of tokens that may still be minted in the named drop.
     * @dev Returns 0 if `dropName` does not refer to an active drop.
     *
     * @param dropName The name of the drop
     */
    function amountRemainingInDrop(bytes32 dropName)
        public
        view
        virtual
        override
        returns (uint256)
    {
        if (dropName == bytes32(0)) {
            return totalAvailable();
        }

        ManagedDrop storage currentDrop = dropByName[dropName];
        if (!currentDrop.active) {
            return 0;
        }

        return _remaining(currentDrop);
    }

    /**
     * @dev Returns the number of tokens minted so far in a drop.
     * @dev Returns 0 if `dropName` does not refer to an active drop.
     *
     * @param dropName The name of the drop
     */
    function dropMintCount(bytes32 dropName)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return dropByName[dropName].mintCount.current();
    }

    /**
     * @dev returns the drop with the given name.
     * @dev if there is no drop with the name, the function should return an
     * empty drop.
     */
    function dropForName(bytes32 dropName)
        public
        view
        virtual
        override
        returns (Drop memory)
    {
        return dropByName[dropName].drop;
    }

    /**
     * @dev Return the name of a drop at `_index`. Use along with {dropCount()} to
     * iterate through all the drop names.
     */
    function dropNameForIndex(uint256 _index)
        public
        view
        virtual
        override
        returns (bytes32)
    {
        return allDropNames[_index];
    }

    /**
     * @notice A drop is active if it has been started and has neither run out of supply
     * nor been stopped manually.
     * @dev Returns true if the `dropName` refers to an active drop.
     */
    function isDropActive(bytes32 dropName)
        public
        view
        virtual
        override
        returns (bool)
    {
        return dropByName[dropName].active;
    }

    /**
     * @dev Returns the number of drops that have been created.
     */
    function dropCount() public view virtual override returns (uint256) {
        return allDropNames.length;
    }

    function _remaining(ManagedDrop storage drop)
        private
        view
        returns (uint32)
    {
        return drop.drop.dropSize - uint32(drop.mintCount.current());
    }

    function _isRealDrop(Drop storage testDrop)
        internal
        view
        virtual
        returns (bool)
    {
        return testDrop.dropSize != 0;
    }

    /* ################################################################
     * Drop Management
     * ##############################################################*/

    /**
     * @notice If categories are required, attempts to mint with an empty drop
     * name will revert.
     */
    function setRequireCategory(bool required)
        public
        virtual
        override
        onlyOwner
    {
        requireCategory = required;
    }

    /**
     * @notice Starts a new drop.
     * @param dropName The name of the new drop
     * @param dropStartTime The unix timestamp of when the drop is active
     * @param dropSize The number of NFTs in this drop
     * @param _startStateName The initial state for the drop's state machine.
     * @param baseURI The base URI for the tokens in this drop
     */
    function startNewDrop(
        bytes32 dropName,
        uint32 dropStartTime,
        uint32 dropSize,
        bytes32 _startStateName,
        string memory baseURI
    ) public virtual override onlyOwner {
        require(dropSize > 0, "invalid drop");
        require(dropSize <= totalAvailable(), "drop too large");
        require(dropName != bytes32(0), "invalid category");
        ManagedDrop storage newDrop = dropByName[dropName];
        require(!_isRealDrop(newDrop.drop), "drop exists");

        newDrop.drop = Drop(dropName, dropStartTime, dropSize, baseURI);
        _activateDrop(newDrop, _startStateName);

        tokensReserved.add(dropSize);
        emit DropAnnounced(newDrop.drop);
    }

    function _activateDrop(ManagedDrop storage drop, bytes32 _startStateName)
        internal
        virtual
    {
        allDropNames.push(drop.drop.dropName);
        drop.active = true;
        drop.stateMachine.initialize(
            _startStateName,
            abi.encode(drop.drop.baseURI)
        );
    }

    /**
     * @notice Ends the named drop immediately. It's not necessary to call this.
     * The current drop ends automatically once the last token is sold.
     *
     * @param dropName The name of the drop to deactivate
     */
    function deactivateDrop(bytes32 dropName)
        public
        virtual
        override
        onlyOwner
    {
        ManagedDrop storage currentDrop = dropByName[dropName];
        require(currentDrop.active, "invalid drop");

        currentDrop.active = false;
        tokensReserved.subtract(_remaining(currentDrop));
        emit DropEnded(currentDrop.drop);
    }

    /* ################################################################
     * Minting / Burning
     * ##############################################################*/

    /**
     * @dev Call this function when minting a token within a drop.
     * @dev Validates drop and available quantities
     * @dev Updates available quantities
     * @dev Deactivates drop when last one is minted
     */
    function onMint(
        bytes32 dropName,
        uint256 tokenId,
        string memory customURI
    ) public virtual override onlyOwner validDropName(dropName) {
        ManagedDrop storage currentDrop = dropByName[dropName];

        if (_isRealDrop(currentDrop.drop)) {
            _preMintCheck(currentDrop, 1);

            dropNameByTokenId[tokenId] = dropName;
            currentDrop.stateForToken[tokenId] = currentDrop
                .stateMachine
                .initialStateName();
            tokensReserved.decrement();
        } else {
            require(totalAvailable() >= 1, "sold out");
        }

        if (bytes(customURI).length > 0) {
            customURIs[tokenId] = customURI;
        }

        tokensMinted.increment();
    }

    /**
     * @dev Call this function when minting a batch of tokens within a drop.
     * @dev Validates drop and available quantities
     * @dev Updates available quantities
     * @dev Deactivates drop when last one is minted
     */
    function onBatchMint(bytes32 dropName, uint256[] memory tokenIds)
        public
        virtual
        override
        onlyOwner
        validDropName(dropName)
    {
        ManagedDrop storage currentDrop = dropByName[dropName];

        bool inDrop = _isRealDrop(currentDrop.drop);
        if (inDrop) {
            _preMintCheck(currentDrop, tokenIds.length);

            tokensReserved.subtract(tokenIds.length);
        } else {
            require(totalAvailable() >= tokenIds.length, "sold out");
        }

        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (inDrop) {
                dropNameByTokenId[tokenIds[i]] = dropName;
                currentDrop.stateForToken[tokenIds[i]] = currentDrop
                    .stateMachine
                    .initialStateName();
            }
        }

        tokensMinted.add(tokenIds.length);
    }

    function _preMintCheck(ManagedDrop storage currentDrop, uint256 _quantity)
        internal
        virtual
    {
        require(currentDrop.active, "no drop");
        require(block.timestamp >= currentDrop.drop.dropStartTime, "early");
        uint32 remaining = _remaining(currentDrop);
        require(remaining >= _quantity, "sold out");

        currentDrop.mintCount.add(_quantity);
        if (remaining == _quantity) {
            currentDrop.active = false;
            emit DropEnded(currentDrop.drop);
        }
    }

    /**
     * @dev Call this function when burning a token within a drop.
     * @dev Updates available quantities
     * @dev Will not reactivate the drop.
     */
    function postBurnUpdate(uint256 tokenId) public virtual override onlyOwner {
        ManagedDrop storage currentDrop = dropByName[
            dropNameByTokenId[tokenId]
        ];
        if (_isRealDrop(currentDrop.drop)) {
            currentDrop.mintCount.decrement();
            tokensReserved.increment();
            delete dropNameByTokenId[tokenId];
            delete currentDrop.stateForToken[tokenId];
        }

        delete customURIs[tokenId];
        tokensMinted.decrement();
    }

    /* ################################################################
     * State Machine
     * ##############################################################*/

    /**
     * @notice Sets up a state transition
     *
     * Requirements:
     * - `dropName` MUST refer to a valid drop
     * - `fromState` MUST refer to a valid state for `dropName`
     * - `toState` MUST NOT be empty
     * - `baseURI` MUST NOT be empty
     * - A transition named `toState` MUST NOT already be defined for `fromState`
     *    in the drop named `dropName`
     */
    function addStateTransition(
        bytes32 dropName,
        bytes32 fromState,
        bytes32 toState,
        string memory baseURI
    )
        public
        virtual
        override
        onlyOwner
        realDrop(dropName)
        validBaseURI(baseURI)
    {
        ManagedDrop storage drop = dropByName[dropName];

        drop.stateMachine.addStateTransition(
            fromState,
            toState,
            abi.encode(baseURI)
        );
    }

    /**
     * @notice Removes a state transition. Does not remove any states.
     *
     * Requirements:
     * - `dropName` MUST refer to a valid drop.
     * - `fromState` and `toState` MUST describe an existing transition.
     */
    function deleteStateTransition(
        bytes32 dropName,
        bytes32 fromState,
        bytes32 toState
    ) public virtual override onlyOwner realDrop(dropName) {
        ManagedDrop storage drop = dropByName[dropName];

        drop.stateMachine.deleteStateTransition(fromState, toState);
    }

    /**
     * @dev Returns the token's current state
     * @dev Returns empty string if the token is not managed by a state machine.
     */
    function getState(uint256 tokenId) public view override returns (bytes32) {
        ManagedDrop storage currentDrop = dropByName[
            dropNameByTokenId[tokenId]
        ];

        if (!_isRealDrop(currentDrop.drop)) {
            return "";
        }

        return currentDrop.stateForToken[tokenId];
    }

    /**
     * @dev Moves the token to the new state.
     * @param tokenId the token
     * @param stateName the next state
     * @param requireValidTransition force the token along predefined paths, or
     * allow arbitrary state changes.
     *
     * Requirements
     * - `tokenId` MUST be managed by a state machine
     * - `stateName` MUST be a defined state
     * - if `requireValidTransition` is true, `stateName` MUST be a valid 
     *   transition from the token's current state.
     * - if `requireValidTransition` is false, `stateName` MAY be any state
     *   defined for the state machine.
     */
    function setState(
        uint256 tokenId,
        bytes32 stateName,
        bool requireValidTransition
    ) public virtual override onlyOwner {
        ManagedDrop storage currentDrop = dropByName[
            dropNameByTokenId[tokenId]
        ];
        require(_isRealDrop(currentDrop.drop), "no state");
        require(
            currentDrop.stateMachine.isValidState(stateName),
            "invalid state"
        );
        bytes32 currentStateName = currentDrop.stateForToken[tokenId];

        if (requireValidTransition) {
            require(
                currentDrop.stateMachine.isValidTransition(
                    currentStateName,
                    stateName
                ),
                "No such transition"
            );
        }

        currentDrop.stateForToken[tokenId] = stateName;
        emit StateChange(tokenId, currentStateName, stateName);
    }

    function _getBaseURIForState(
        ManagedDrop storage currentDrop,
        bytes32 stateName
    ) internal view virtual returns (string memory) {
        return
            abi.decode(
                currentDrop.stateMachine.getStateData(stateName),
                (string)
            );
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[41] private __gap;
}