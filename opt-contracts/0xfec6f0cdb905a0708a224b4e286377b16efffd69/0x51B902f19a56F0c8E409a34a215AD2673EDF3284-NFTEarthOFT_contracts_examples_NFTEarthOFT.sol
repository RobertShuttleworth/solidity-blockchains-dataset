/*
    
   ██████  ██████   ██████  ██   ██ ██████   ██████   ██████  ██   ██    ██████  ███████ ██    ██
  ██      ██    ██ ██    ██ ██  ██  ██   ██ ██    ██ ██    ██ ██  ██     ██   ██ ██      ██    ██
  ██      ██    ██ ██    ██ █████   ██████  ██    ██ ██    ██ █████      ██   ██ █████   ██    ██
  ██      ██    ██ ██    ██ ██  ██  ██   ██ ██    ██ ██    ██ ██  ██     ██   ██ ██       ██  ██
   ██████  ██████   ██████  ██   ██ ██████   ██████   ██████  ██   ██ ██ ██████  ███████   ████
  
  Find any smart contract, and build your project faster: https://www.cookbook.dev
  Twitter: https://twitter.com/cookbook_dev
  Discord: https://discord.gg/cookbookdev
  
  Find this contract on Cookbook: https://www.cookbook.dev/contracts/0x51B902f19a56F0c8E409a34a215AD2673EDF3284-NFTEarthOFT?utm=code
  */
  
  // SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

//     _   ____________________           __  __    ____  ____________
//    / | / / ____/_  __/ ____/___ ______/ /_/ /_  / __ \/ ____/_  __/
//   /  |/ / /_    / / / __/ / __ `/ ___/ __/ __ \/ / / / /_    / /
//  / /|  / __/   / / / /___/ /_/ / /  / /_/ / / / /_/ / __/   / /
// /_/ |_/_/     /_/ /_____/\__,_/_/   \__/_/ /_/\____/_/     /_/

import "./0x51B902f19a56F0c8E409a34a215AD2673EDF3284-NFTEarthOFT_contracts_token_oft_v2_OFTV2.sol";

/// @title An OmnichainFungibleToken using the LayerZero OFT standard

contract NFTEarthOFT is OFTV2 {
    constructor(string memory _name, string memory _symbol, uint8 _sharedDecimals, address _layerZeroEndpoint) OFTV2(_name, _symbol, _sharedDecimals, _layerZeroEndpoint) {
                 // mint 20M to deployer
        _mint(_msgSender(), 100 * 10**18);
    }
}