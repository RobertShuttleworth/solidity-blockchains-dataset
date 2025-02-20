// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "./openzeppelin_contracts_access_Ownable.sol";
import {ISgInfoV2} from "./contracts_interfaces_cross_chain_ISgInfoV2.sol";

/// @title SgInfoV2 for CrossChainRouterV5.
/// @notice Router for stateless execution of cross chain swap against Stargate V2.
/// @custom:stargate-contracts https://stargateprotocol.gitbook.io/stargate/v2-developer-docs/technical-reference/v2-supported-networks-and-assets
contract SgInfoV2 is ISgInfoV2, Ownable {

    // eid => SGETH token address
    mapping(uint32 => address) public sgETHs;

    // eid => Endpoint address
    mapping(uint32 => address) public endpoints;

    // eid => stargate address
    mapping(uint32 => mapping(address => address)) public stargates;

    // Stargate Eid on local chain
    uint32 public sgEidLocal;

    constructor(address _owner, uint32 _sgEidLocal) Ownable(_owner) {
        sgEidLocal = _sgEidLocal;
        _initStargates();
        _initEndpoints();
    }

    function _initEndpoints() internal {
        // Ethereum
        endpoints[30101] = 0x1a44076050125825900e736c501f859c50fE728c;
        // BNB Chain
        endpoints[30102] = 0x1a44076050125825900e736c501f859c50fE728c;
        // Avalanche
        endpoints[30106] = 0x1a44076050125825900e736c501f859c50fE728c;
        // Polygon
        endpoints[30109] = 0x1a44076050125825900e736c501f859c50fE728c;
        // Arbitrum
        endpoints[30110] = 0x1a44076050125825900e736c501f859c50fE728c;
        // Optimism
        endpoints[30111] = 0x1a44076050125825900e736c501f859c50fE728c;
        // Linea
        endpoints[30183] = 0x1a44076050125825900e736c501f859c50fE728c;
        // Base
        endpoints[30184] = 0x1a44076050125825900e736c501f859c50fE728c;
    }

    function _initStargates() internal {
        // Ethereum
        stargates[30101][0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2] = 0x77b2043768d28E9C9aB44E1aBfC95944bcE57931; // Native ETH
        stargates[30101][0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48] = 0xc026395860Db2d07ee33e05fE50ed7bD583189C7; // USDC
        stargates[30101][0xdAC17F958D2ee523a2206206994597C13D831ec7] = 0x933597a323Eb81cAe705C5bC29985172fd5A3973; // USDT
        // BNB Chain
        stargates[30102][0x55d398326f99059fF775485246999027B3197955] = 0x138EB30f73BC423c6455C53df6D89CB01d9eBc63; // USDT
        stargates[30102][0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d] = 0x962Bd449E630b0d928f308Ce63f1A21F02576057; // USDC
        // Avalanche
        stargates[30106][0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E] = 0x5634c4a5FEd09819E3c46D86A965Dd9447d86e47; // USDC
        stargates[30106][0x9702230A8Ea53601f5cD2dc00fDBc13d4dF4A8c7] = 0x12dC9256Acc9895B076f6638D628382881e62CeE; // USDT
        // Polygon
        stargates[30109][0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174] = 0x9Aa02D4Fae7F58b8E8f34c66E756cC734DAc7fe4; // USDC
        stargates[30109][0xc2132D05D31c914a87C6611C10748AEb04B58e8F] = 0xd47b03ee6d86Cf251ee7860FB2ACf9f91B9fD4d7; // USDT
        // Arbitrum
        stargates[30110][0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8] = 0xe8CDF27AcD73a434D661C84887215F7598e7d0d3; // USDC
        stargates[30110][0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9] = 0xcE8CcA271Ebc0533920C83d39F417ED6A0abB7D0; // USDT
        stargates[30110][0x82aF49447D8a07e3bd95BD0d56f35241523fBab1] = 0xA45B5130f36CDcA45667738e2a258AB09f4A5f7F; // Native ETH
        // Optimism
        stargates[30111][0x7F5c764cBc14f9669B88837ca1490cCa17c31607] = 0xcE8CcA271Ebc0533920C83d39F417ED6A0abB7D0; // USDC
        stargates[30111][0x94b008aA00579c1307B0EF2c499aD98a8ce58e58] = 0x19cFCE47eD54a88614648DC3f19A5980097007dD; // USDT
        stargates[30111][0x4200000000000000000000000000000000000006] = 0xe8CDF27AcD73a434D661C84887215F7598e7d0d3; // Native ETH
        // Linea
        stargates[30183][0xe5D7C2a44FfDDf6b295A15c148167daaAf5Cf34f] = 0x81F6138153d473E8c5EcebD3DC8Cd4903506B075; // Native ETH
        // Base
        stargates[30184][0xd9aAEc86B65D86f6A7B5B1b0c42FFA531710b6CA] = 0x27a16dc786820B16E5c9028b75B99F6f604b5d26; // USDC
        stargates[30184][0x4200000000000000000000000000000000000006] = 0xdc181Bd607330aeeBEF6ea62e03e5e1Fb4B6F7C7; // Native ETH
    }

    function setSgETH(uint32 eid, address token) external onlyOwner {
        sgETHs[eid] = token;
    }

    function setStargate(
        uint32 eid,
        address token,
        address _stargate
    ) external onlyOwner {
        stargates[eid][token] = _stargate;
    }

    function setSgEidLocal(uint32 _eid) external onlyOwner {
        sgEidLocal = _eid;
    }
}