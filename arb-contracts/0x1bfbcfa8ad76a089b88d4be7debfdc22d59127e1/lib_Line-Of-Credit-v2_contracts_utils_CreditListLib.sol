// SPDX-License-Identifier: GPL-3.0
// Copyright: https://github.com/credit-cooperative/Line-Of-Credit-v2/blob/master/COPYRIGHT.md

pragma solidity 0.8.25;

/**
 * @title   - CreditListLib
 * @author  - Credit Cooperative
 * @notice  - Core logic that manages the repayment queue of credit positions in LineOfCredit contract.
 */
library CreditListLib {
    event QueueCleared();
    event SortedIntoQ(uint256 indexed id, uint256 indexed newIdx, uint256 indexed oldIdx, uint256 oldId);

    error CantStepQ();

    /**
     * @notice  - Removes a position id from the active list of open positions.
     * @dev     - assumes `id` is stored only once in the `positions` array. if `id` occurs twice, debt would be double counted.
     * @param ids           - all current credit lines on the Line of Credit facility
     * @param id            - the hash id of the credit line to be removed from active ids after removePosition() has run
     */
    function removePosition(uint256[] storage ids, uint256 id) external {
        uint256 len = ids.length;

        for (uint256 i; i < len; ++i) {
            if (ids[i] == id) {
                delete ids[i];
            }
        }
    }

    /**
     * @notice  - swap the first element in the queue, provided it is null, with the next available valid(non-null) id
     * @dev     - Must perform check for ids[0] being valid (non-zero) before calling
     * @param ids       - all current credit lines on the Line of Credit facility
     * @return swapped  - returns true if the swap has occurred
     */
    function stepQ(uint256[] storage ids) external returns (bool) {
        if (ids[0] != 0) {
            revert CantStepQ();
        }

        uint256 len = ids.length;
        if (len <= 1) return false;

        // skip the loop if we don't need
        if (len == 2 && ids[1] != 0) {
            (ids[0], ids[1]) = (ids[1], ids[0]);
            emit SortedIntoQ(ids[0], 0, 1, ids[1]);
            return true;
        }

        // we never check the first id, because we already know it's null
        for (uint256 i = 1; i < len;) {
            if (ids[i] != 0) {
                (ids[0], ids[i]) = (ids[i], ids[0]); // swap the ids in storage
                emit SortedIntoQ(ids[0], 0, i, ids[i]);
                return true; // if we make the swap, return early
            }
            unchecked {
                ++i;
            }
        }
        emit QueueCleared();
        return false;
    }
}