// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
import "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";
import "./openzeppelin_contracts-upgradeable_proxy_utils_UUPSUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_access_OwnableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_security_ReentrancyGuardUpgradeable.sol";
import {IOptionModuleV2} from "./contracts_interfaces_internal_IOptionModuleV2.sol";
import {IVault} from "./contracts_interfaces_internal_IVault.sol";
import {IERC20} from "./contracts_interfaces_external_IERC20.sol";

contract TradingCreditPool is Initializable, OwnableUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable {

    address public optionModuleContractAddress;

    uint256 public tradingCreditDecimal;
    mapping(address => uint256) public tradingCredits;

    mapping(address => bool) public operators;
    event SubmitFreeAmount(address indexed user, address indexed tokenAddress, uint256 indexed amount);

    uint256 public deductionDecimal;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    modifier onlyOperator(){
        require(operators[msg.sender] == true, "You are not operator");
        _;
    }

    function initialize(address _optionModule, uint256 _decimal) public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        optionModuleContractAddress = _optionModule;
        tradingCreditDecimal = _decimal;
    }

    function setOperator(address _op, bool allow) public onlyOwner{
        operators[_op] = allow;
    }

    function setOptionModuleContractAddress(address _address) public onlyOperator {
        optionModuleContractAddress = _address;
    }

    function setTradingCreditDecimal(uint256 _decimal) public onlyOperator {
        tradingCreditDecimal = _decimal;
    }

    function setDecuctionDecimal(uint256 _decimal) public onlyOperator {
        deductionDecimal = _decimal;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    function setTradingCreditsToUser(address[] memory _user, uint256[] memory credits) public onlyOperator{

        require(_user.length == credits.length, "Error length");
        
        for(uint256 i = 0; i < _user.length; i++){
            address user = _user[i];
            tradingCredits[user] = credits[i];
        }
    }

    function addTradingCreditsToUser(address[] memory _user, uint256[] memory credits) public onlyOperator{

        require(_user.length == credits.length, "Error length");
        
        for(uint256 i = 0; i < _user.length; i++){
            address user = _user[i];
            tradingCredits[user] += credits[i];
        }
    }

    function getUserTradingCredits(
        address user,
        uint256 premiumFee
    ) public view returns (uint256 credit){

        uint256 creditBalance = tradingCredits[user];
        uint256 allowCredit = 0;
        if(creditBalance < premiumFee){
            allowCredit = creditBalance; 
        }else{
            allowCredit = premiumFee; 
        }

        return allowCredit;
    }

    function getFreeAmount(IOptionModuleV2.ManagedOrder memory _optionOrder) public view returns (uint256 amount){

        address _vault = _optionOrder.recipient;
        address eoaAddress = IVault(_vault).owner();

        uint256 discountAmount = _optionOrder.premiumSign.premiumFee * _optionOrder.quantity / 10**18;
        uint256 creditAmount = getUserTradingCredits(eoaAddress, discountAmount);
        return creditAmount;
    }

    function submitFreeAmount(IOptionModuleV2.ManagedOrder memory _optionOrder, uint256 amount) public returns (bool ok){

        require(msg.sender == optionModuleContractAddress, "NFTDiscountPool: only option module contract can call this function");
        
        address _vault = _optionOrder.recipient;
        address eoaAddress = IVault(_vault).owner();

        if(amount > 0){
            tradingCredits[eoaAddress] = tradingCredits[eoaAddress] - amount;
        }

        emit SubmitFreeAmount(eoaAddress, _optionOrder.premiumSign.premiumAsset, amount);
        return true;
    }

    function execute(
        address dest,
        uint256 value,
        bytes calldata func
    ) external returns (bytes memory result) {

        require(msg.sender == optionModuleContractAddress, "NFTDiscountPool: only option module contract can call this function");

        address[] memory _dest = new address[](1);
        _dest[0] = dest;
        result = _call(dest, value, func);
    }

    function _call(
        address target,
        uint256 value,
        bytes memory data
    ) internal returns (bytes memory) {
        (bool success, bytes memory result) = target.call{value: value}(data);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
        return result;
    }

    // function withdraw(address tokenAddress, address to, uint256 amount) public onlyOwner {
    //     IERC20(tokenAddress).transfer(to, amount);
    // }
}