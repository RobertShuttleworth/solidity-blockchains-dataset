// SPDX-License-Identifier: BUSL-1.1
// OpenZeppelin Contracts (last updated v4.6.0) (governance/extensions/GovernorVotes.sol)

pragma solidity ^0.8.0;

import {VetoGovernor} from "./contracts_governance_VetoGovernor.sol";
import {IERC6372} from "./lib_openzeppelin-contracts_contracts_interfaces_IERC6372.sol";
import {IVotes} from "./contracts_governance_IVotes.sol";
import {SafeCast} from "./lib_openzeppelin-contracts_contracts_utils_math_SafeCast.sol";

/**
 * @dev OpenZeppelin's GovernorVotes using VetoGovernor
 */
abstract contract VetoGovernorVotes is VetoGovernor {
    IVotes public immutable token;

    constructor(IVotes tokenAddress) {
        token = IVotes(address(tokenAddress));
    }

    /**
     * @dev Clock (as specified in EIP-6372) is set to match the token's clock. Fallback to block numbers if the token
     * does not implement EIP-6372.
     */
    function clock() public view virtual override returns (uint48) {
        try IERC6372(address(token)).clock() returns (uint48 timepoint) {
            return timepoint;
        } catch {
            return SafeCast.toUint48(block.number);
        }
    }

    /**
     * @dev Machine-readable description of the clock as specified in EIP-6372.
     */
    // solhint-disable-next-line func-name-mixedcase
    function CLOCK_MODE() public view virtual override returns (string memory) {
        try IERC6372(address(token)).CLOCK_MODE() returns (string memory clockmode) {
            return clockmode;
        } catch {
            return "mode=blocknumber&from=default";
        }
    }

    /**
     * Read the voting weight from the token's built in snapshot mechanism (see {Governor-_getVotes}).
     */
    function _getVotes(
        address account,
        uint256 tokenId,
        uint256 timepoint,
        bytes memory /*params*/
    ) internal view virtual override returns (uint256) {
        return token.getPastVotes(account, tokenId, timepoint);
    }
}