//SPDX-License-Identifier: MIT
pragma solidity =0.8.14;

import "./openzeppelin_contracts-upgradeable_proxy_ClonesUpgradeable.sol";

import "./contracts_DAOFarm.sol";

contract Factory {
    address public implementation;

    event Deployment(address indexed deployer, address deployedAt, DAOFarm.InitParams params);

    constructor() {
        implementation = address(new DAOFarm());
    }

    function deployMultiple(DAOFarm.InitParams[] calldata params) external returns (address[] memory) {
        address[] memory deployedAt = new address[](params.length);
        for (uint i; i < params.length; i++) {
            deployedAt[i] = deploy(params[i]);
        }
        return deployedAt;
    }

    function deploy(DAOFarm.InitParams calldata params) public returns (address) {
        address deployedAt = ClonesUpgradeable.clone(implementation);
        DAOFarm(deployedAt).init(params);
        DAOFarm(deployedAt).transferOwnership(msg.sender);
        emit Deployment(msg.sender, deployedAt, params);
        return deployedAt;
    }
}