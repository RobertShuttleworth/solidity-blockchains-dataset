// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./hardhat_console.sol";

import "./openzeppelin_contracts_utils_Strings.sol";



import "./openzeppelin_contracts_token_ERC20_ERC20.sol";
import "./openzeppelin_contracts_token_ERC20_extensions_ERC20Pausable.sol";
import "./openzeppelin_contracts_access_AccessControl.sol";
import "./uniswap_v2-core_contracts_interfaces_IUniswapV2Pair.sol";

contract Fish_RewardERC20 is ERC20, AccessControl, ERC20Pausable {
    bytes32 public constant PAUSE_ROLE = keccak256("PAUSE_ROLE");

    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    
    // externally injected price
    bool useInjectedUSDTPrice;
    uint256 private injectedPriceInUSDT;
    // PancakeSwap Pair Contract for FISH/USDT
    IUniswapV2Pair public fishUSDTPair_contractAddress;
    address public feeWalletAddress;
    
    
    uint256 private lastResetTimestamp_global;
    

    uint256 public transferLimitUSDT_global = 0 * 1e6;
    mapping(address => uint256) private transferLimitUSDT_byAddress;
    mapping(address => uint256) private transferAmountUSDT_byAddress;
    mapping(address => uint256) private lastTransferTimestamp_byAddress;


    mapping(address => bool) private isExemptFromTaxIncoming_byAddress;
    mapping(address => bool) private isExemptFromTaxOutgoing_byAddress;


    uint256 public defaultTaxationPercentageOutFromWallet_10000 = 600;
    mapping(address => uint256) private customTaxationIncomingFromWallet10000_byAddress;
    mapping(address => uint256) private customTaxationOutgoingFromWallet10000_byAddress;
    
    

    constructor(
        string memory _name, 
        string memory _symbol,
        address _feeWalletAddress
    ) ERC20(_name, _symbol) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        
        _setRoleAdmin(PAUSE_ROLE, DEFAULT_ADMIN_ROLE);
        
        _setRoleAdmin(ORACLE_ROLE, DEFAULT_ADMIN_ROLE);
        
        _setRoleAdmin(MINTER_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(BURNER_ROLE, DEFAULT_ADMIN_ROLE);
        
        feeWalletAddress = _feeWalletAddress;

        // Initialize reset timestamp to today at 00:00 UTC
        lastResetTimestamp_global = block.timestamp - (block.timestamp % 1 days);

        useInjectedUSDTPrice = true;
    }


    // Contract Meta Administration
    function pause() external onlyRole(PAUSE_ROLE) {
        _pause();
    }
    function unpause() external onlyRole(PAUSE_ROLE) {
        _unpause();
    }


    // Contract State Administration
    // setFeeWalletAddress
    function set_feeWalletaddress(address _feeWalletAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_feeWalletAddress != address(0x00), "Fee wallet cannot be 0x address");
        feeWalletAddress = _feeWalletAddress;
    } 
    
    //   Function to set the PancakeSwap pair address after deployment
    function set_fishUSDTPair(address _pairAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        fishUSDTPair_contractAddress = IUniswapV2Pair(_pairAddress);
        customTaxationOutgoingFromWallet10000_byAddress[_pairAddress] = 300;
    }
    //   Transfer limits
    function set_transferLimitUSDT_global(uint256 _amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        transferLimitUSDT_global = _amount;
    }
    function set_transferLimitUSDT_byUser(address _targetAddress, uint256 _amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        transferLimitUSDT_byAddress[_targetAddress] = _amount;
    }
    // Taxation Tooling
    function addRemoveExemptIncoming(address[] memory _walletAddresses, bool[] memory _exemptionValue) external onlyRole(DEFAULT_ADMIN_ROLE)  {
        // Check if both arrays have the same length
        require(_walletAddresses.length > 0, "Arrays must not be zero length");
        require(_walletAddresses.length == _exemptionValue.length, "Arrays must be of the equal length");

        // Iterate over the arrays and set the mapping values
        for (uint256 i = 0; i < _walletAddresses.length; i++) {
            isExemptFromTaxIncoming_byAddress[_walletAddresses[i]] = _exemptionValue[i];
        }
    }
    function addRemoveExemptOutgoing(address[] memory _walletAddresses, bool[] calldata _exemptionValue) external onlyRole(DEFAULT_ADMIN_ROLE)  {
        // Check if both arrays have the same length
        require(_walletAddresses.length > 0, "Arrays must not be zero length");
        require(_walletAddresses.length == _exemptionValue.length, "Arrays must be of the same length");

        // Iterate over the arrays and set the mapping values
        for (uint256 i = 0; i < _walletAddresses.length; i++) {
            isExemptFromTaxOutgoing_byAddress[_walletAddresses[i]] = _exemptionValue[i];
        }
    }
    function set_defaultTaxationPercentageOutFromWallet_1000(uint256 _taxationPercentage10000) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_taxationPercentage10000 < 10001, "_taxationPercentage10000 cannot be over 100%");

        defaultTaxationPercentageOutFromWallet_10000 = _taxationPercentage10000;
    }
    function set_customTaxationIncoming_byAddress(address _addressToSet, uint256 _taxationPercentage10000) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_addressToSet != address(0), "_addressToSet cannot be the zero wallet");
        require(_taxationPercentage10000 < 10001, "_taxationPercentage10000 cannot be over 100%");

        customTaxationIncomingFromWallet10000_byAddress[_addressToSet] = _taxationPercentage10000;
    }
    function set_customTaxationOutgoing_byAddress(address _addressToSet, uint256 _taxationPercentage10000) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_addressToSet != address(0), "_addressToSet cannot be the zero wallet");
        require(_taxationPercentage10000 < 10001, "_taxationPercentage10000 cannot be over 100%");

        customTaxationOutgoingFromWallet10000_byAddress[_addressToSet] = _taxationPercentage10000;
    }


    // Role managed actions - admin
    function mint(address _to, uint256 _amt) external onlyRole(MINTER_ROLE) {
        _mint(_to, _amt);
    }
    function burn(address _from, uint256 _amt) external onlyRole(BURNER_ROLE) {
        _transfer(_from, address(this), _amt);
        _burn(address(this), _amt);
    }

    function set_injectedPriceInUSDT(uint256 _newValue) external onlyRole(DEFAULT_ADMIN_ROLE) {
      injectedPriceInUSDT = _newValue;
    }


    // Role managed actions - inter-contract
    function getPriceFromAMM() external view onlyRole(ORACLE_ROLE) returns (uint256) {
        return iGetPriceFromAMM();
    }


    // Public view functions
    function get_injectedPriceInUSDT() external view returns (uint256) {
      return injectedPriceInUSDT;
    }
   

    // Public function to calculate the recipient and fee amounts
    function calculateAmountsWithFee(address _senderAddress, address _recipientAddress, uint256 _amount) public view returns (uint256, uint256) {
        console.log("Fish_RewardERC20: calculateAmountsWithFee: _senderAddress: ", _senderAddress);
        console.log("Fish_RewardERC20: calculateAmountsWithFee: _recipientAddress: ", _recipientAddress);
        console.log("Fish_RewardERC20: calculateAmountsWithFee: exemptOutgoing: ", isExemptFromTaxOutgoing_byAddress[_senderAddress]);
        
        // Check if sender or recipient is exempt from the tax
        if (isExemptFromTaxOutgoing_byAddress[_senderAddress] || isExemptFromTaxIncoming_byAddress[_recipientAddress]) {
            return (_amount, 0); // No tax applied
        }
        
        uint256 taxationPercentage10000 = 
                    customTaxationIncomingFromWallet10000_byAddress[_recipientAddress]
                +   customTaxationOutgoingFromWallet10000_byAddress[_senderAddress];
        
        if (taxationPercentage10000 == 0) taxationPercentage10000 = defaultTaxationPercentageOutFromWallet_10000;

        if (taxationPercentage10000 > 10000) taxationPercentage10000 = 10000;
        

        // Calculate % fee
        uint256 feeAmount = (_amount * taxationPercentage10000) / 10000;
        uint256 recipientAmount = _amount-feeAmount;
        
        return (recipientAmount, feeAmount);
    }


    // Protocol Override Functions
    // Override transfer to apply tax logic
    function transfer(address _recipientAddress, uint256 _amount) public override returns (bool) {
        (uint256 recipientAmount, uint256 feeAmount) = calculateAmountsWithFee(msg.sender, _recipientAddress, _amount);

        uint256 limitUSDTThisUser = iGet_remainingLimitUSDT_byUser(msg.sender);
        uint256 amountUSDT = (iGetPriceFromAMM() * recipientAmount) / 1e18;

        require(
            amountUSDT <= limitUSDTThisUser,
            string(
                abi.encodePacked(
                    "This amount would exceed daily limits: amountUSDT=",
                    Strings.toString(amountUSDT),
                    ", limitUSDTThisUser=",
                    Strings.toString(limitUSDTThisUser),
                    ", msg.sender=",
                    Strings.toHexString(uint160(msg.sender), 20)
                )
            )
        );
        
        
        // Transfer the recipient amount
        super._transfer(msg.sender, _recipientAddress, recipientAmount);

        // Transfer the fee amount to the treasury, if applicable
        console.log("Fish_RewardERC20: transfer: feeAmount:", feeAmount);
        if (feeAmount > 0) {
            super._transfer(msg.sender, feeWalletAddress, feeAmount);
        }
        
        return true;
    }

    // Override transferFrom to apply tax logic
    function transferFrom(address _senderAddress, address _recipientAddress, uint256 _amount) public override returns (bool) {
        (uint256 recipientAmount, uint256 feeAmount) = calculateAmountsWithFee(_senderAddress, _recipientAddress, _amount);

        uint256 limitUSDTThisUser = iGet_remainingLimitUSDT_byUser(_senderAddress);
        uint256 amountUSDT = (iGetPriceFromAMM() * recipientAmount) / 1e18;

        require(
            amountUSDT <= limitUSDTThisUser,
            string(
                abi.encodePacked(
                    "This amount would exceed daily limits: amountUSDT=",
                    Strings.toString(amountUSDT),
                    ", limitUSDTThisUser=",
                    Strings.toString(limitUSDTThisUser),
                    ", msg.sender=",
                    Strings.toHexString(uint160(msg.sender), 20)
                )
            )
        );
        
        // Transfer the recipient amount
        super._transfer(_senderAddress, _recipientAddress, recipientAmount);

        // Transfer the fee amount to the treasury, if applicable
        console.log("Fish_RewardERC20: transferFrom: feeAmount:", feeAmount);
        if (feeAmount > 0) {
            super._transfer(_senderAddress, feeWalletAddress, feeAmount);
        }
        

        return true;
    }    
    
    // Internal Functions
    //   Fetch FISH/USDT price from PancakeSwap pair
    function iGetPriceFromAMM() internal view returns (uint256) {
        if (useInjectedUSDTPrice == true) {
          require(injectedPriceInUSDT > 0, "injectedPriceHasNotBeenSet");
          return injectedPriceInUSDT;
        } else {
          require(address(fishUSDTPair_contractAddress) != address(0), "LP Pair Address not set");
          (uint112 reserveFISH, uint112 reserveUSDT, ) = fishUSDTPair_contractAddress.getReserves();
          require(reserveFISH > 0 && reserveUSDT > 0, "Insufficient liquidity in LP");
          
          return (uint256(reserveUSDT) * 1e18) / uint256(reserveFISH); // Price of 1 FISH in USDT
        }
    }
    // Internal function to check and reset daily limits per address
    function iGet_remainingLimitUSDT_byUser(address _targetAddress) internal returns (uint256) {
        uint256 currentTimestamp = block.timestamp;
        // Determine cycle time: 1 day for other chains, 6 minutes for chain ID 80002
        uint256 cycleTime = (block.chainid == 97) ? 6 minutes : 1 days;

        if (currentTimestamp >= lastResetTimestamp_global + cycleTime) {
            // Reset the timestamp to the start of the current cycle
            lastResetTimestamp_global = currentTimestamp - (currentTimestamp % cycleTime);
        }
        if (lastTransferTimestamp_byAddress[_targetAddress] < lastResetTimestamp_global) {
            if (transferAmountUSDT_byAddress[_targetAddress] > 0) transferAmountUSDT_byAddress[_targetAddress] = 0;
            lastTransferTimestamp_byAddress[_targetAddress] = currentTimestamp;
        }

         uint256 limit = transferLimitUSDT_byAddress[msg.sender] > 0 
            ? transferLimitUSDT_byAddress[msg.sender] 
            : transferLimitUSDT_global;

        return limit - transferAmountUSDT_byAddress[msg.sender];
    }


    // Protocol Hook Functions
    function _update(address _senderAddress, address _recipientAddress, uint256 _amount)
        internal
        override(ERC20, ERC20Pausable)
    {
        super._update(_senderAddress, _recipientAddress, _amount);
    }


    // Override supportsInterface to support AccessControl
    function supportsInterface(bytes4 interfaceId) public view virtual override(AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}