// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "./FreeMintToken.sol";

contract FDMEFactory is Ownable {

    address public daramAddress = 0xaD86b91A1D1Db15A4CD34D0634bbD4eCAcB5b61a;

    address public foundationAddress = 0x68614Fbb36911005Ba9CA3Ce35111f49b223be9c;
    
    address public blackHoleAddress = 0x000000000000000000000000000000000000dEaD;
    
    address public taxAddress = 0xFa78995407CA49a12080c3DD52ACc2ded3C4eab0;

    uint public foundationPercent = 25;
    
    uint public blackHolePercent = 25;
    
    uint public tax = 1000000 * 1 ether;
	
    address[] public fdmdContracts;

    mapping(string => address) public fdmeMap;

    event CreateFDMEContract(address indexed owner, address indexed fdmeContract);

    constructor() Ownable(msg.sender){

    }

    function setFoundationAddress(address foundationAddress_) public onlyOwner {
        foundationAddress = foundationAddress_;
    }

    function setTaxAddress(address taxAddress_) public onlyOwner {
        taxAddress = taxAddress_;
    }

    function setFoundationPercent(uint8 foundationPercent_) public onlyOwner {
        foundationPercent = foundationPercent_;
    }

    function setBlackHolePercent(uint8 blackHolePercent_) public onlyOwner {
        blackHolePercent = blackHolePercent_;
    }

    function setTax(uint tax_) public onlyOwner {
        tax = tax_;
    }
	
    function createFDMEContract(string memory name_, string memory symbol_, uint maxSupply_, uint mintAmount_, bool isToVitalik_, uint toVitalikPercent_) public {
        require(fdmeMap[name_] == address(0), "FDME contract is existed.");

        ERC20 daram = ERC20(daramAddress);
        uint256 balance = daram.balanceOf(msg.sender);
        require(balance >= tax, "Insufficient daram balance");

        uint256 allowance = daram.allowance(msg.sender, address(this));
        require(allowance >= tax, "Insufficient allowance amount");

        daram.transferFrom(msg.sender, foundationAddress, tax * foundationPercent / 100 );
        daram.transferFrom(msg.sender, blackHoleAddress, tax * blackHolePercent / 100);
        daram.transferFrom(msg.sender, taxAddress, tax * (100 - foundationPercent - blackHolePercent) / 100);

        FreeMintToken newContract = new FreeMintToken(name_, symbol_, maxSupply_, mintAmount_, isToVitalik_, toVitalikPercent_);
        fdmdContracts.push(address(newContract));
        fdmeMap[name_] = address(newContract);
        emit CreateFDMEContract(msg.sender, address(newContract));
    }

    function getDeployedContractsCount() public view returns (uint256) {
        return fdmdContracts.length;
    }

    function getDeployedContractByIndexes(uint256[] memory indexs) public view returns (address[] memory) {
        require(indexs.length > 0, "Indexs is empty");
        address[] memory contracts = new address[](indexs.length);
        for (uint i = 0; i < indexs.length; i++) {
            uint256 index = indexs[i];
            require(index < fdmdContracts.length, "Index out of bounds");
            contracts[i] = fdmdContracts[index];
        }    
        return contracts;
    }

    function getDeployedContractByName(string memory name) public view returns (address) {
        require(fdmeMap[name] != address(0), "Invalid name");
        return fdmeMap[name];
    }
}