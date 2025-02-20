// SPDX-License-Identifier: ISC
pragma solidity 0.8.27;

/**
 * @title Bonus Errors
 * @notice Library to manage errors in the Bonus contract
 * @author https://x.com/0xjsieth
 *
 */
library BonusErrors{
    // Error thrown if user does not own any boosters
    error USER_DOESNT_OWN_ANY_BOOSTER();

    // Error thrown when a user tries to burn a booster that isnt theirs
    error NOT_AN_OWNER();

    // Error thrown if user has already minted a booster
    error ALREADY_MINTED();

    // Error thrown if the token address is not a contract
    error NOT_A_CONTRACT();

    // Error thrown if the admin tries to revoke his minter role
    error CANNOT_REVOKE_FROM_ADMIN();
}