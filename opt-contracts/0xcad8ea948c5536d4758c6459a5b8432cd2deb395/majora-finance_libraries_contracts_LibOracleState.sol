// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {DataTypes} from "./majora-finance_libraries_contracts_DataTypes.sol";
import {IERC20} from "./openzeppelin_contracts_token_ERC20_IERC20.sol";


/**
 * @title LibOracleState
 * @author Majora Development Association
 * @notice A library for managing and manipulating the state of oracle data, specifically token amounts.
 */
library LibOracleState {

    /**
     * @notice Finds the amount for a specific token in the oracle state.
     * @param self The oracle state.
     * @param _token The address of the token to find the amount for.
     * @return The amount of the specified token.
     */
    function findTokenAmount(DataTypes.OracleState memory self, address _token) internal pure returns (uint256) {
        for (uint256 i = 0; i < self.tokens.length; i++) {
            if (self.tokens[i] == _token) {
                return self.tokensAmount[i];
            }
        }
        return 0;
    }

    /**
     * @notice Finds the amount for a specific token in the oracle state and discover it if unknown.
     * @param self The oracle state.
     * @param _token The address of the token to find the amount for.
     * @return The amount of the specified token.
     */
    function discoverTokenAmount(DataTypes.OracleState memory self, address _token) internal view returns (uint256) {
        bool exists;
        uint256 balance;
        for (uint256 i = 0; i < self.tokens.length; i++) {
            if (self.tokens[i] == _token) {
                exists = true;
                balance = self.tokensAmount[i];
            }
        }

        if(balance == 0 && !exists) {
            balance = IERC20(_token).balanceOf(self.vault);
            
            address[] memory newTokens = new address[](self.tokens.length + 1);
            uint256[] memory newTokensAmount = new uint256[](
                self.tokens.length + 1
            );

            for (uint256 i = 0; i < self.tokens.length; i++) {
                newTokens[i] = self.tokens[i];
                newTokensAmount[i] = self.tokensAmount[i];
            }

            newTokens[self.tokens.length] = _token;
            newTokensAmount[self.tokens.length] = balance;

            self.tokens = newTokens;
            self.tokensAmount = newTokensAmount;
        }

        return balance;
    }

    /**
     * @notice Check if a token amount exists in the oracle state.
     * @param self The oracle state.
     * @param _token The address of the token to check.
     * @return exists boolean that indicate if the token exists.
     */
    function tokenExists(DataTypes.OracleState memory self, address _token) internal pure returns (bool) {
        for (uint256 i = 0; i < self.tokens.length; i++) {
            if (self.tokens[i] == _token) {
                return true;
            }
        }
        return false;
    }

    /**
     * @notice Adds an amount to a specific token in the oracle state. If the token does not exist, it is added to the state.
     * @param self The oracle state to modify.
     * @param _token The token address to add the amount to.
     * @param _amount The amount to add to the token's total.
     */
    function addTokenAmount(DataTypes.OracleState memory self, address _token, uint256 _amount) internal view {

        //If token exists, add it directly and return
        for (uint256 i = 0; i < self.tokens.length; i++) {
            if (self.tokens[i] == _token) {
                self.tokensAmount[i] += _amount;
                return;
            }
        }

        //else add token in oracle, get its balance and add the amount in parameters 
        address[] memory newTokens = new address[](self.tokens.length + 1);
        uint256[] memory newTokensAmount = new uint256[](
            self.tokens.length + 1
        );

        for (uint256 i = 0; i < self.tokens.length; i++) {
            newTokens[i] = self.tokens[i];
            newTokensAmount[i] = self.tokensAmount[i];
        }

        uint256 balance = IERC20(_token).balanceOf(self.vault);
        newTokens[self.tokens.length] = _token;
        newTokensAmount[self.tokens.length] = balance + _amount;

        self.tokens = newTokens;
        self.tokensAmount = newTokensAmount;
    }

    /**
     * @notice Sets the amount for a specific token in the oracle state.. If the token does not exist, it is added with the given amount.
     * @param self The oracle state to modify.
     * @param _token The token address whose amount to set.
     * @param _amount The amount to set for the token.
     */
    function setTokenAmount(DataTypes.OracleState memory self, address _token, uint256 _amount) internal pure {
        for (uint256 i = 0; i < self.tokens.length; i++) {
            if (self.tokens[i] == _token) {
                self.tokensAmount[i] = _amount;
                return;
            }
        }

        address[] memory newTokens = new address[](self.tokens.length + 1);
        uint256[] memory newTokensAmount = new uint256[](
            self.tokens.length + 1
        );

        for (uint256 i = 0; i < self.tokens.length; i++) {
            newTokens[i] = self.tokens[i];
            newTokensAmount[i] = self.tokensAmount[i];
        }

        newTokens[self.tokens.length] = _token;
        newTokensAmount[self.tokens.length] = _amount;

        self.tokens = newTokens;
        self.tokensAmount = newTokensAmount;
    }

    /**
     * @notice Removes an amount from a specific token in the oracle state.
     * @param self The oracle state to modify.
     * @param _token The token address to remove the amount from.
     * @param _amount The amount to remove from the token's total.
     */
    function removeTokenAmount(DataTypes.OracleState memory self, address _token, uint256 _amount) internal pure {
        for (uint256 i = 0; i < self.tokens.length; i++) {
            if (self.tokens[i] == _token) {
                self.tokensAmount[i] -= _amount;
            }
        }
    }

    /**
     * @notice Applies a percentage reduction to a specific token's amount in the oracle state.
     * @param self The oracle state to modify.
     * @param _token The token address to apply the reduction to.
     * @param _percent The percentage (in basis points) to reduce the token's amount by.
     */
    function removeTokenPercent(DataTypes.OracleState memory self, address _token, uint256 _percent) internal pure {
        for (uint256 i = 0; i < self.tokens.length; i++) {
            if (self.tokens[i] == _token) {
                self.tokensAmount[i] -= (self.tokensAmount[i] * _percent) / 10000;
            }
        }
    }

    /**
     * @notice Applies a percentage reduction to all token amounts in the oracle state.
     * @param self The oracle state to modify.
     * @param _percent The percentage (in basis points) to reduce each token's amount by.
     */
    function removeAllTokenPercent(DataTypes.OracleState memory self, uint256 _percent) internal pure {
        for (uint256 i = 0; i < self.tokens.length; i++) {
            self.tokensAmount[i] -= (self.tokensAmount[i] * _percent) / 10000;
        }
    }

    /**
     * @notice Applies a percentage reduction to all token amounts in the oracle state.
     * @param self The oracle state to modify.
     */
    function clone(DataTypes.OracleState memory self) internal pure returns (DataTypes.OracleState memory) {
        DataTypes.OracleState memory _clone;
        _clone.vault = self.vault;

        uint256 length = self.tokens.length;
        address[] memory clonedTokens = new address[](length);
        uint256[] memory clonedTokensAmount = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            clonedTokens[i] = self.tokens[i];
            clonedTokensAmount[i] = self.tokensAmount[i];
        }

        _clone.tokens = clonedTokens;
        _clone.tokensAmount = clonedTokensAmount;

        return _clone;
    }
}