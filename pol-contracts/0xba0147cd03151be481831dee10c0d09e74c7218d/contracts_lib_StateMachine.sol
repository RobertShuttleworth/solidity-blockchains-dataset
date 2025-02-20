// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title State Machine Library
 * @notice (c) 2023 ViciNFT https://vicinft.com/
 * @author Josh Davis <josh.davis@vicinft.com>
 *
 * @dev An implementation of a Finite State Machine.
 * @dev A State has a name, some arbitrary data, and a set of
 *   valid transitions.
 * @dev A State Machine has an initial state and a set of states.
 */
library StateMachine {
    struct State {
        bytes32 name;
        bytes data;
        mapping(bytes32 => bool) transitions;
    }

    struct States {
        bytes32 initialState;
        mapping(bytes32 => State) states;
    }

    /**
     * @dev You MUST call this before using the state machine.
     * @dev creates the initial state.
     * @param startStateName The name of the initial state.
     * @param _data The data for the initial state.
     *
     * Requirements:
     * - The state machine MUST NOT already have an initial state.
     * - `startStateName` MUST NOT be empty.
     * - `startStateName` MUST NOT be the same as an existing state.
     */
    function initialize(
        States storage stateMachine,
        bytes32 startStateName,
        bytes memory _data
    ) internal {
        require(startStateName != bytes32(0), "invalid state name");
        require(
            stateMachine.initialState == bytes32(0),
            "already initialized"
        );
        State storage startState = stateMachine.states[startStateName];
        require(!_isValid(startState), "duplicate state");
        stateMachine.initialState = startStateName;
        startState.name = startStateName;
        startState.data = _data;
    }

    /**
     * @dev Returns the name of the iniital state.
     */
    function initialStateName(States storage stateMachine)
        internal
        view
        returns (bytes32)
    {
        return stateMachine.initialState;
    }

    /**
     * @dev Creates a new state transition, creating
     *   the "to" state if necessary.
     * @param fromStateName the "from" side of the transition
     * @param toStateName the "to" side of the transition
     * @param _data the data for the "to" state
     *
     * Requirements:
     * - `fromStateName` MUST be the name of a valid state.
     * - There MUST NOT aleady be a transition from `fromStateName`
     *   and `toStateName`.
     * - `toStateName` MUST NOT be empty
     * - `toStateName` MAY be the name of an existing state. In
     *   this case, `_data` is ignored.
     * - `toStateName` MAY be the name of a non-existing state. In
     *   this case, a new state is created with `_data`.
     */
    function addStateTransition(
        States storage stateMachine,
        bytes32 fromStateName,
        bytes32 toStateName,
        bytes memory _data
    ) internal {
        require(toStateName != bytes32(0), "Missing to state");
        State storage fromState = stateMachine.states[fromStateName];
        require(_isValid(fromState), "invalid from state");
        require(!fromState.transitions[toStateName], "duplicate transition");

        State storage toState = stateMachine.states[toStateName];
        if (!_isValid(toState)) {
            toState.name = toStateName;
            toState.data = _data;
        }
        fromState.transitions[toStateName] = true;
    }

    /**
     * @dev Removes a transtion. Does not remove any states.
     * @param fromStateName the "from" side of the transition
     * @param toStateName the "to" side of the transition
     *
     * Requirements:
     * - `fromStateName` and `toState` MUST describe an existing transition.
     */
    function deleteStateTransition(
        States storage stateMachine,
        bytes32 fromStateName,
        bytes32 toStateName
    ) internal {
        require(
            stateMachine.states[fromStateName].transitions[toStateName],
            "invalid transition"
        );
        stateMachine.states[fromStateName].transitions[toStateName] = false;
    }

    /**
     * @dev Update the data for a state.
     * @param stateName The state to be updated.
     * @param _data The new data
     *
     * Requirements:
     * - `stateName` MUST be the name of a valid state.
     */
    function setStateData(
        States storage stateMachine,
        bytes32 stateName,
        bytes memory _data
    ) internal {
        State storage state = stateMachine.states[stateName];
        require(_isValid(state), "invalid state");
        state.data = _data;
    }

    /**
     * @dev Returns the data for a state.
     * @param stateName The state to be queried.
     *
     * Requirements:
     * - `stateName` MUST be the name of a valid state.
     */
    function getStateData(
        States storage stateMachine,
        bytes32 stateName
    ) internal view returns (bytes memory) {
        State storage state = stateMachine.states[stateName];
        require(_isValid(state), "invalid state");
        return state.data;
    }

    /**
     * @dev Returns true if the parameters describe a valid
     *   state transition.
     * @param fromStateName the "from" side of the transition
     * @param toStateName the "to" side of the transition
     */
    function isValidTransition(
        States storage stateMachine,
        bytes32 fromStateName,
        bytes32 toStateName
    ) internal view returns (bool) {
        return stateMachine.states[fromStateName].transitions[toStateName];
    }

    /**
     * @dev Returns true if the state exists.
     * @param stateName The state to be queried.
     */
    function isValidState(
        States storage stateMachine,
        bytes32 stateName
    ) internal view returns (bool) {
        return _isValid(stateMachine.states[stateName]);
    }

    function _isValid(State storage state) private view returns (bool) {
        return state.name != bytes32(0);
    }
}