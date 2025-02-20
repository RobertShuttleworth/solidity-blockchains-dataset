// @author Daosourced
// @date January 24, 2023
import "./openzeppelin_contracts-upgradeable_token_ERC20_IERC20Upgradeable.sol";

pragma solidity ^0.8.0;

/**
* @notice contains general 'read' and 'write' function definitions for a erc20 token contract in the HDNS Ecosystem
*/
interface BaseHDNSToken is IERC20Upgradeable {    
    /**
    * @notice mints an erc20 token to an account
    * @param to list of addressess to mint to
    * @param amount token amount to mint
    */
    function mint(address to, uint256 amount) external;
    
    /**
    * @notice mints to multple accounts in different amounts
    * @param tos list of addressess to mint to
    * @param amounts list token amounts to mint
    */
    function mintMany(address[] calldata tos, uint256[] calldata amounts) external;
}