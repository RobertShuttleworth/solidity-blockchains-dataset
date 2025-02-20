// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.23 <0.9.0;

import { MultiTokenManager } from "./src_MultiTokenManager.sol";
import { ERC20 } from "./node_modules_openzeppelin_contracts_token_ERC20_ERC20.sol";
import { BaseScript } from "./script_Base.s.sol";
import { console } from "./node_modules_forge-std_src_console.sol";

// create a test ERC20 token
contract MEMEToken is ERC20 {
    constructor() ERC20("MEME Token", "MEME") {
        _mint(msg.sender, 1000000 * 10**18);
    }
}

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract Deploy is BaseScript {
    uint8 private constant DECIMALS = 18;
    uint256 private constant DECIMAL_FACTOR = 10**DECIMALS;

    function run() public broadcast returns (MultiTokenManager multiTokenManager) {
        address deployer = msg.sender;
        
        // 1. deploy MultiTokenManager
        multiTokenManager = new MultiTokenManager();
        console.log("MultiTokenManager deployed at:", address(multiTokenManager));
        console.log("Deployer address:", deployer);

        // 2. deploy test token
        MEMEToken memeToken = new MEMEToken();
        console.log("MEME Token deployed at:", address(memeToken));
        console.log("Deployer address:", deployer);

        // 3. register ERC20 token
        MultiTokenManager.TokenInfo memory tokenInfo = MultiTokenManager.TokenInfo({
            erc20Address: address(memeToken),
            name: "MEME Token",
            symbol: "MEME",
            decimals: DECIMALS
        });

        uint256 tokenId = multiTokenManager.registerToken(tokenInfo);
        console.log("Token registered with ID:", tokenId);
        console.log("Initial MEME balance of deployer:", memeToken.balanceOf(deployer) / DECIMAL_FACTOR, "MEME");
        console.log("Deployer address:", deployer);

        // 4. mint ERC1155 token
        console.log("----------------MINT----------------");
        multiTokenManager.mint(deployer, tokenId, 4000 * DECIMAL_FACTOR, "");
        console.log("ERC1155 minted for 4000 MEME, token ID:", tokenId, " to:", deployer);
        console.log("ERC1155 balance after mint:", multiTokenManager.balanceOf(deployer, tokenId) / DECIMAL_FACTOR, "MEME");
        console.log("MEME balance after mint:", memeToken.balanceOf(deployer) / DECIMAL_FACTOR, "MEME");
        console.log("Deployer address:", deployer);
        
        // 5. burn ERC1155 token
        console.log("----------------BURN----------------");
        multiTokenManager.burn(tokenId, 1000 * DECIMAL_FACTOR);
        console.log("ERC1155 burned for 1000 MEME, token ID:", tokenId, " from:", deployer);
        console.log("ERC1155 balance after burn:", multiTokenManager.balanceOf(deployer, tokenId) / DECIMAL_FACTOR, "MEME");
        console.log("MEME balance after burn:", memeToken.balanceOf(deployer) / DECIMAL_FACTOR, "MEME");
        console.log("Deployer address:", deployer);

        // 6. transfer ERC1155 token
        console.log("----------------TRANSFER----------------");
        multiTokenManager.safeTransferFrom(deployer, address(0x2), tokenId, 1000 * DECIMAL_FACTOR, "");
        console.log("ERC1155 transferred for 1000 MEME, token ID:", tokenId, " to:", address(0x2));
        console.log("Sender ERC1155 balance after transfer:", multiTokenManager.balanceOf(deployer, tokenId) / DECIMAL_FACTOR, "MEME");
        console.log("Receiver ERC1155 balance after transfer:", multiTokenManager.balanceOf(address(0x2), tokenId) / DECIMAL_FACTOR, "MEME");
        console.log("Deployer address:", deployer);

        // // 7. swap ERC1155 token to ERC20 token
        // console.log("----------------SWAP----------------");
        // uint256 amountOut = multiTokenManager.swapExactInputSingle(tokenId, address(memeToken), 500, 1000 * DECIMAL_FACTOR);
        // console.log("ERC1155 swapped for", amountOut / DECIMAL_FACTOR, "MEME, token ID:", tokenId);

        // 8. burn ERC20 token
        // console.log("----------------BURN----------------");
        // memeToken.burn(amountOut);
        // console.log("ERC20 burned for", amountOut / DECIMAL_FACTOR, "MEME");
        // console.log("ERC20 balance after burn:", memeToken.balanceOf(deployer) / DECIMAL_FACTOR, "MEME");
        // console.log("Deployer address:", deployer);

        // 9. check final balances 
        console.log("----------------FINAL BALANCES----------------");
        console.log("Final ERC1155 balance:", multiTokenManager.balanceOf(deployer, tokenId) / DECIMAL_FACTOR, "MEME");
        console.log("Final MEME balance:", memeToken.balanceOf(deployer) / DECIMAL_FACTOR, "MEME");
        console.log("Deployer address:", deployer);
    }
}