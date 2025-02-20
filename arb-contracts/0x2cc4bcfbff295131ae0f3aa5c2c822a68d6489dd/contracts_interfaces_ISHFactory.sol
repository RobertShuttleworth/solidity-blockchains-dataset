// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "./openzeppelin_contracts-upgradeable_token_ERC20_IERC20Upgradeable.sol";
import "./contracts_libraries_DataTypes.sol";

interface ISHFactory {
    function createProduct(
        string memory _name,
        string memory _underlying,
        IERC20Upgradeable _currency,
        address _manager,
        address _qredoWallet,
        uint256 _maxCapacity,
        DataTypes.IssuanceCycle memory _issuanceCycle,
        address _router,
        address _market        
    ) external;
    
    function numOfProducts() external view returns (uint256);

    function isProduct(address _product) external view returns (bool);

    function getProduct(string memory _name) external view returns (address);
}