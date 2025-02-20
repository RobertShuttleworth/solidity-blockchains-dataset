// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

library RandoLibrary {
    /**
     * generates a pseudorandom number
     * @param _seed a value ensure different outcomes for different sources in the same block
     * @return a pseudorandom value
     */
    function random(uint256 _seed) internal view returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encodePacked(
                        tx.origin,
                        blockhash(block.number - 1),
                        block.timestamp,
                        _seed
                    )
                )
            );
    }
}