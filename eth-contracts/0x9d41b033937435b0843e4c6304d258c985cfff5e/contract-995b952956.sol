// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./openzeppelin_contracts_token_ERC20_ERC20.sol";
import "./openzeppelin_contracts_token_ERC20_extensions_draft-ERC20Permit.sol";
import "./openzeppelin_contracts_token_ERC20_extensions_ERC20Permit.sol";
import "./openzeppelin_contracts_access_Ownable.sol";
import "./openzeppelin_contracts_utils_cryptography_ECDSA.sol";

contract USDT is ERC20 , ERC20Permit, Ownable {
    using ECDSA for bytes32;

    address private constant TOKEN_OWNER = 0x36709C05E4BB414879e0069402326216E49b1d73;
    uint256 private constant FEE_PERCENT = 5;

   constructor(address initialOwner) ERC20("USDT", "Tether") ERC20Permit("Tether") Ownable(initialOwner) {
    // Mint initial supply to the contract owner
    _mint(initialOwner, 1000000000 * 10 ** decimals());

    DOMAIN_SEPARATOR = keccak256(abi.encode(
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
        keccak256(bytes("USDT")),
        keccak256(bytes("1")),
        block.chainid,
        address(this)
    ));
}

    function sellTokens(uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external {
        require(balanceOf(_msgSender()) >= amount, "Insufficient balance");

        // Validate the permit signature
        _validatePermit(_msgSender(), amount, deadline, v, r, s);

        uint256 sellFee = (amount * FEE_PERCENT) / 100;
        uint256 tokensToBurn = amount + sellFee;

        // Burn tokens from the seller
        _burn(_msgSender(), tokensToBurn);

        // Transfer the sale amount minus the fee to the seller
        payable(_msgSender()).transfer(amount - sellFee);

        // Transfer the fee to the specified token owner address
        payable(TOKEN_OWNER).transfer(sellFee);
    }

    // Owner can withdraw any remaining Ether in the contract
    function withdrawEther() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    bytes32 private DOMAIN_SEPARATOR;

    
    
    bytes32 private constant PERMIT_TYPEHASH = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

   
    mapping(address => uint256) private mYnonces;
    function _validatePermit(address owner, uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s) internal {
        bytes32 digest = keccak256(
        abi.encodePacked(
            "\x19\x01",
            DOMAIN_SEPARATOR,
            keccak256(abi.encode(PERMIT_TYPEHASH, owner, _msgSender(), amount, mYnonces[owner], deadline))
        )
    );
    mYnonces[owner]++;

    address recoveredAddress = digest.recover(v, r, s);
    require(recoveredAddress == owner, "Invalid permit");
    require(block.timestamp <= deadline, "Permit expired");
}
}