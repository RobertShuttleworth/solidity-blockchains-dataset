// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library Periods {

    function period(uint256 _timestamp, uint256 _period) internal pure returns (uint256) {
        return (_timestamp / _period) * _period;
    }

    function since(uint256 _timestamp, uint256 _period) internal view returns (uint256) {
        return between(_timestamp, block.timestamp, _period);
    }

    function between(uint256 _timestamp1, uint256 _timestamp2, uint256 _period) internal pure returns (uint256) {
        uint256 _period1 = period(_timestamp1, _period);
        uint256 _period2 = period(_timestamp2, _period);
        return (_period1 == _period2) ? 0 : (_period1 > _period2) ? (_period1 - _period2) / _period : (_period2 - _period1) / _period;
    }

}