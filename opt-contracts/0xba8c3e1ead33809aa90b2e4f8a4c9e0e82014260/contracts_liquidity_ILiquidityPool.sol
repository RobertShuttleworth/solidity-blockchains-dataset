// @author Daosourced
// @date January 13, 2023
pragma solidity ^0.8.0;
import './contracts_liquidity_IExchange.sol';

/**
* @notice contains the 'send' and 'read' function definitions for the general vault contract in the HDNS ecosystem
*/
interface ILiquidityPool {

    /**
    * @notice allows entities to deposit funds into the vault  
    */
    function deposit() external payable;

    /**
    * @notice allows entities to deposit erc20 funds into the vault  
    */
    function deposit(uint256 amount) external;

    /**
    * @notice returns the symbol of the token In the vault  
    */
    function tokenSymbol() external view returns (string memory);
    
    /**
    * @notice returns the vault name  
    */
    function name() external view returns (string memory);

    /**
    * @notice returns tokenAddress of the vault
    */
    function token() external view returns (address);

    /**
    * @notice returns the current eth locked in the vault  
    */    
    function balance() external view returns (uint256);

    /**
    * @notice returns the current eth locked in the vault  
    */
    function tokenBalance() external view returns (uint256);

    /**
    * @notice locks the contract
    */
    function pause() external;

    /**
    * @notice unlocks the contract
    */
    function unpause() external;
} 
