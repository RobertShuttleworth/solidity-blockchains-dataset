// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./openzeppelin_contracts_token_ERC20_ERC20.sol";
import "./openzeppelin_contracts_access_Ownable.sol";

contract DRTToken is ERC20,Ownable {
    address public membersContract;

    constructor(address _membersAddress) Ownable(msg.sender) ERC20("DeFily Royalty Token", "DRT") {
        membersContract = _membersAddress;
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    /**
     * @notice Función para que el contrato de membresía emita nuevos DRT.
     * @param account La dirección a la que se enviarán los tokens.
     * @param amount La cantidad de tokens a emitir.
     */
    function mint(address account, uint256 amount) external {
        require(msg.sender == membersContract, "Debe ser contrato members");
        _mint(account, amount);
    }

    /**
     * @notice Función para quemar tokens DRT.
     * @param account La dirección que posee los tokens a quemar.
     * @param amount La cantidad de tokens a quemar.
     */
    function burn(address account, uint256 amount) external {
        require(msg.sender == membersContract, "Debe ser contrato members");
        _burn(account, amount);
    }

    function adminMint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function setMembersContract(address _membersAddress) public onlyOwner {
        membersContract = _membersAddress;
    }

}