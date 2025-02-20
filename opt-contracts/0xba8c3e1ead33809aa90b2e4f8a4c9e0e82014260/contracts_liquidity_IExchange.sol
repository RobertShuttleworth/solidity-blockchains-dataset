// @author Daosourced, CPM Model Credits to Uniswap (v1)
// @date February 17

pragma solidity ^0.8.0;

interface IExchange { 

    event TokenPurchase(address indexed buyer, address recipient, uint256 indexed ethSold, uint256 indexed tokensBought);

    event EthPurchase(address indexed buyer, address  recipient, uint256 indexed tokensSold, uint256 indexed ethBought);
    
    event NativeDeposit(uint256 indexed amount);
    
    event TokenDeposit(uint256 indexed amount);

    /**
    * @notice Convert ETH to Tokens and transfers Tokens to recipient.
    * @dev User specifies exact input (msg.value) and minimum output
    * @param minTokens Minimum Tokens bought.
    * @param deadline Time after which this transaction can no longer be executed.
    * @param recipient The address that receives output Tokens.
    * @return Amount of Tokens bought.
    */
    function ethToTokenTransferInput(uint256 minTokens, uint256 deadline, address recipient) external payable returns (uint256);
    
    /** 
    * @notice Convert ETH to Tokens
    * @dev User specifies exact input (msg.value) and minimum output
    * @param minTokens Minimum Tokens bought
    * @param deadline Time after which this transaction can no longer be executed.
    * @return Amount of Tokens bought.
    */
    function ethToTokenSwapInput(uint256 minTokens, uint256 deadline) external payable returns (uint256);

    /** 
    * @notice Convert ETH to Tokens.
    * @dev User specifies maximum input (msg.value) and exact output.
    * @param tokensBought  Amount of tokens bought.
    * @param deadline Time after which this transaction can no longer be executed.
    * @return Amount of ETH sold.
    */
    function ethToTokenSwapOutput(uint256 tokensBought, uint256 deadline) external payable returns (uint256);
    
    /** 
    * @notice Convert ETH to Tokens.
    * @dev User specifies maximum input (msg.value) and exact output.
    * @param tokensBought  Amount of tokens bought.
    * @param deadline Time after which this transaction can no longer be executed.
    * @param recipient The address that receives output Tokens.
    * @return Amount of ETH sold.
    */
    function ethToTokenTransferOutput(uint256 tokensBought, uint256 deadline, address recipient) external payable returns (uint256);
    
    /**
    * @dev User specifies exact input and minimum output.
    * @param tokensSold Amount of Tokens sold.
    * @param minEth Minimum ETH purchased.
    * @param deadline Time after which this transaction can no longer be executed.
    * @return Amount of ETH bought. 
    */
    function tokenToEthSwapInput(uint256 tokensSold, uint256 minEth, uint256 deadline) external returns (uint256);

    /**
    * @notice Convert Tokens to ETH and transfers ETH to recipient.
    * @dev User specifies exact input and minimum output.
    * @param tokensSold Amount of Tokens sold.
    * @param minEth Minimum ETH purchased.
    * @param deadline Time after which this transaction can no longer be executed.
    * @param recipient The address that receives output ETH.
    * @return Amount of ETH bought.
    */
    function tokenToEthTransferInput(
        uint256 tokensSold, 
        uint256 minEth, 
        uint256 deadline, 
        address recipient
    ) external returns (uint256);

    /**
    * @notice Convert Tokens to ETH.
    * @dev User specifies maximum input and exact output.
    * @param ethBought Amount of ETH purchased.
    * @param maxTokens Maximum Tokens sold.
    * @param deadline Time after which this transaction can no longer be executed.
    * @return Amount of Tokens sold.
    */    
    function tokenToEthSwapOutput(uint256 ethBought, uint256 maxTokens, uint256 deadline) external returns (uint256);

    /**
    * @notice Convert Tokens to ETH and transfers ETH to recipient.
    * @dev User specifies maximum input and exact output.
    * @param ethBought Amount of ETH purchased.
    * @param maxTokens Maximum Tokens sold.
    * @param deadline Time after which this transaction can no longer be executed.
    * @param recipient The address that receives output ETH.
    * @return Amount of Tokens sold.
    */
    function tokenToEthTransferOutput(
        uint256 ethBought, 
        uint256 maxTokens, 
        uint256 deadline, 
        address recipient
    ) external returns (uint256);

    /**
    * @notice Public price function for ETH to Token trades with an exact input.
    * @param ethSold Amount of ETH sold.
    * @return Amount of Tokens that can be bought with input ETH.
    */
    function getEthToTokenInputPrice(uint256 ethSold) external view returns (uint256);

    /**
    * @notice Public price function for ETH to Token trades with an exact output.
    * @param tokensBought Amount of Tokens bought.
    * @return Amount of ETH needed to buy output Tokens.
    */
    function getEthToTokenOutputPrice(uint256 tokensBought) external view returns (uint256);

    /**
    * @notice Public price function for Token to ETH trades with an exact input.
    * @param tokensSold Amount of Tokens sold.
    * @return Amount of ETH that can be bought with input Tokens.
    */
    function getTokenToEthInputPrice(uint256 tokensSold) external view returns (uint256);

    /**
    * @notice Public price function for Token to ETH trades with an exact output.
    * @param ethBought Amount of output ETH.
    * @return Amount of Tokens needed to buy output ETH.
    */
    function getTokenToEthOutputPrice(uint256 ethBought) external view returns (uint256);
        

    /**
    * @notice Public price function for ETH to Token trades with an exact input.
    * @param ethSold Amount of ETH sold.
    * @param buyer The address that receives output Tokens.
    * @return Amount of Tokens that can be bought with input ETH.
    */
    function getEthToTokenInputPrice(uint256 ethSold, address buyer) external view returns (uint256);

    /**
    * @notice Public price function for ETH to Token trades with an exact output.
    * @param tokensBought Amount of Tokens bought.
    * @param buyer The address that receives output Tokens.
    * @return Amount of ETH needed to buy output Tokens.
    */
    function getEthToTokenOutputPrice(uint256 tokensBought, address buyer) external view returns (uint256);

    /**
    * @notice Public price function for Token to ETH trades with an exact input.
    * @param tokensSold Amount of Tokens sold.
    * @param buyer The address that receives output ETH.
    * @return Amount of ETH that can be bought with input Tokens.
    */
    function getTokenToEthInputPrice(uint256 tokensSold, address buyer) external view returns (uint256);

    /**
    * @notice Public price function for Token to ETH trades with an exact output.
    * @param ethBought Amount of output ETH.
    * @param buyer The address that receives output ETH.
    * @return Amount of Tokens needed to buy output ETH.
    */
    function getTokenToEthOutputPrice(uint256 ethBought, address buyer) external view returns (uint256);
        
    /**
    * @notice add liquidity to the vault.
    */
    function getTokenLiquidityAmount(uint256 depositValue) external view returns (uint256);

}