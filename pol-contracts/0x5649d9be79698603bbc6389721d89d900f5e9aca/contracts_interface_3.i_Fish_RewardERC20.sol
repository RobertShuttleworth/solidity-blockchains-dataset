// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;


import "./openzeppelin_contracts_access_IAccessControl.sol";
import "./openzeppelin_contracts_token_ERC20_IERC20.sol";

import "./contracts_interface_0.FishStructs.sol";

interface I_Fish_RewardERC20 is IAccessControl, IERC20 {

    event SetTransferLimitGlobalEvent( uint256 _newLimit );
    event SetTransferLimitUserEvent( address _targetAddress, uint256 _newLimit );


  
    // Contract Meta Administration
    function pause() external;
    function unpause() external;


    // Contract State Administration
    //   Transfer controls
    function set_injectedPriceInUSDT(uint256 _newValue) external;
    function set_fishUSDTPair(address _pairAddress) external;

    function set_transferLimit_global(uint256 _amount) external;
    function set_transferLimit_byUser(address _targetAddress, uint256 _amount) external;

    function addRemoveExemptOutgoing(address[] memory _walletAddresses, bool[] calldata _exemptionValue) external;
    function addRemoveExemptIncoming(address[] memory _walletAddresses, bool[] memory _exemptionValue) external;

    function set_defaultTaxationPercentageOutFromWallet_1000(uint256 _taxationPercentage10000) external;
    function set_customTaxationIncoming_byAddress(address _addressToSet, uint256 _taxationPercentage10000) external;
    function set_customTaxationOutgoing_byAddress(address _addressToSet, uint256 _taxationPercentage10000) external;

    // Role managed actions
    function mint(address _to, uint256 _amt) external;
    function burn(address _from, uint256 _amt) external;


    // Role managed actions
    function getPriceFromAMM() external view returns (uint256);

    
    // Public view functions
    function get_injectedPriceInUSDT() external view returns (uint256);
    function get_remainingLimit_byUser(address _targetAddress) external view returns (uint256);
    
}