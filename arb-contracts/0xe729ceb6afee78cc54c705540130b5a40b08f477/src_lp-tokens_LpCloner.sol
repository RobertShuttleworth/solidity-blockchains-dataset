// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;
import {Clones} from "./openzeppelin_contracts_proxy_Clones.sol";
import {Ownable} from "./openzeppelin_contracts_access_Ownable.sol";
import {LiquiDevilLp} from "./src_lp-tokens_LiquiDevilLp.sol";
import {ILpCloner} from "./src_lp-tokens_interfaces_ILpCloner.sol";

contract LpCloner is ILpCloner, Ownable {
    //implementation and factory address
    address public implementation;
    address public poolFactory;

    //events
    event PoolFactoryUpdated(address newPoolFactory);
    event ImplementationUpdated(address newImplementation);

    //modifiers
    modifier onlyPoolFactory() {
        require(msg.sender == poolFactory, "only pool factory allowed");
        _;
    }

    //create contract with ERC20 implementation address and a factory contract that is allowed to clone lp
    constructor(address _poolFactory) {
        implementation = address(new LiquiDevilLp());
        poolFactory = _poolFactory;
    }

    function setPoolFactory(address newPoolFactory) external onlyOwner {
        require(
            newPoolFactory != address(0) || newPoolFactory != poolFactory,
            "invalid new factory"
        );

        poolFactory = newPoolFactory;
        emit PoolFactoryUpdated(newPoolFactory);
    }

    function setImplementation(address newImplementation) external onlyOwner {
        require(
            newImplementation != address(0) || newImplementation != poolFactory,
            "invalid new implementation"
        );

        implementation = newImplementation;
        emit ImplementationUpdated(newImplementation);
    }

    function cloneLpTokens(
        string memory nftSymbol,
        address poolManager
    ) external onlyPoolFactory returns (address lpfToken, address lpnToken) {
        //Contract Creation for two new LP tokens LPN and LPF
        //LPN = NON fungible LP token minted and burned for NFT side of liquidity add amd remove respectively
        lpnToken = Clones.clone(implementation);
        LiquiDevilLp lpnTokenContract = LiquiDevilLp(lpnToken);

        lpnTokenContract.initialize(
            string.concat("LD-LPN-", nftSymbol),
            string.concat("LD-LPN-", nftSymbol)
        );
        lpnTokenContract.transferOwnership(poolManager);
        //LPF = fungible LP token minted and burned for ETH/ERC20 side of liquidity add amd remove respectively

        lpfToken = Clones.clone(implementation);
        LiquiDevilLp lpfTokenContract = LiquiDevilLp(lpfToken);
        lpfTokenContract.initialize(
            string.concat("LD-LPF-", nftSymbol),
            string.concat("LD-LPF-", nftSymbol)
        );
        lpfTokenContract.transferOwnership(poolManager);
    }
}