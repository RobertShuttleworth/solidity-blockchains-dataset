// SPDX-License-Identifier: MIT
// solhint-disable-next-line compiler-version
pragma solidity ^0.8.0;

import "./openzeppelin_contracts-0.8_security_ReentrancyGuard.sol";
import "./openzeppelin_contracts-0.8_utils_math_SafeMath.sol";
import "./openzeppelin_contracts-0.8_utils_Strings.sol";
import "./openzeppelin_contracts-0.8_access_Ownable.sol";
import "./openzeppelin_contracts-0.8_utils_Context.sol";
import "./openzeppelin_contracts-0.8_token_ERC20_IERC20.sol";

contract MarketPlaceERC20 is Ownable, ReentrancyGuard {
    IERC20 internal immutable _ierc20;
    uint256 internal _unitPrice;

    constructor(
        IERC20 ierc20,
        uint256 unitPrice
    ) {
        _transferOwnership(_msgSender());
        _ierc20 = ierc20;
        _unitPrice = unitPrice;
    }

    event MarketPlaceERC20UnitPrice(uint256 _unitPrice);
    event MarketPlaceERC20Retrieved(address _receiver, uint256 _amountRetrieved);
    event MarketPlaceERC20Sale(address _receiver, uint256 _amount, uint256 _unitPrice, uint256 _price);

    /**
     * @notice Buy tokens with funds
     */
    function buy() external payable nonReentrant {
        uint256 amount = msg.value * (1 ether) / _unitPrice;
        require(amount > 0, "You must send enough funds.");
        require(balance() >= amount, string(abi.encodePacked("Only ",Strings.toString(balance())," tokens left to sale.")));
        
        // Send funds to owner
        (bool sent,) = payable(owner()).call{value: msg.value}("0x");
        require(sent, "Failed to send funds.");

        // Transfer ERC20 tokens to buyer
        _ierc20.transfer(_msgSender(), amount);

        emit MarketPlaceERC20Sale(_msgSender(), amount, _unitPrice, msg.value);
    }

    /// @notice Collect all IERC20 tokens from the contract to an address.
    function retrieveAllTokens() public nonReentrant onlyOwner {
        uint256 accountBalance = balance();
        _ierc20.transfer(_msgSender(), accountBalance);

        emit MarketPlaceERC20Retrieved(_msgSender(), accountBalance);
    }

    /// @notice Return the amount of IERC20 for an amount.
    function buyPreview(uint256 amount) public view returns (uint256) {
        return amount / _unitPrice;
    }

    /// @notice Return the IERC20 amount price.
    function getPrice(uint256 amount) public view returns (uint256) {
        return amount * _unitPrice;
    }

    /// @notice Return the IERC20 token address.
    function getTokenAddress() public view returns (address) {
        return address(_ierc20);
    }

    /// @notice Set the IERC20 unit price.
    function setUnitPrice(uint256 unitPrice) public nonReentrant onlyOwner {
        _unitPrice = unitPrice;
        emit MarketPlaceERC20UnitPrice(unitPrice);
    }

    /// @notice Return the IERC20 unit price.
    function getUnitPrice() public view returns (uint256) {
        return _unitPrice;
    }

    /// @notice Return the current IERC20 token balance for the contract.
    function balance() public view returns (uint256) {
        return _ierc20.balanceOf(address(this));
    }
}