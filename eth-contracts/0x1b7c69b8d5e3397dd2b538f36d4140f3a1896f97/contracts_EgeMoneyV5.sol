// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
import "./openzeppelin_contracts-upgradeable_token_ERC20_ERC20Upgradeable.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC20_extensions_ERC20PermitUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_access_AccessControlUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_security_PausableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_security_ReentrancyGuardUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";

contract EgeMoneyV5 is
    Initializable,
    ERC20Upgradeable,
    ERC20PermitUpgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    
    mapping(address => bool) private _frozenAccounts;
    address public admin;

    event Mint(address indexed to, uint256 value);
    event Burn(address indexed from, uint256 value);
    event BurnToken(address indexed from, uint256 value);
    event Freeze(address indexed target);
    event Unfreeze(address indexed target);
    event AdminChanged(address indexed oldAdmin, address indexed newAdmin);

    uint256[19] private __gap;
    mapping(address => bool) public approvedMinters;
    
       function initialize() public initializer {
        __ERC20_init("EGEM", "EGEM");
        __ERC20Permit_init("EGEM");
        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        admin = msg.sender;
    }


    function decimals() public pure override returns (uint8) {
        return 8;
    }

     function totalSupply() public view override returns (uint256) {
        return super.totalSupply();
    }

    function balanceOf(address _owner) public view override returns (uint256) {
        return super.balanceOf(_owner);
    }

    function allowance(address _owner, address _spender)
        public
        view
        override
        returns (uint256)
    {
        return super.allowance(_owner, _spender);
    }



    function transfer(address _to, uint256 _value)
        public
        override
        whenNotPaused
        returns (bool)
    {
        require(!_frozenAccounts[msg.sender], "AF");
        require(!_frozenAccounts[_to], "RF");
        return super.transfer(_to, _value);
    }


     function approve(address _spender, uint256 _value)
        public
        override
        whenNotPaused
        returns (bool)
    {
        return super.approve(_spender, _value);
    }
 

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) public override whenNotPaused returns (bool) {
        require(!_frozenAccounts[_from], "AF");
        require(!_frozenAccounts[_to], "RF");
        return super.transferFrom(_from, _to, _value);
    }

    function mint(address _to, uint256 _value)
        public
        whenNotPaused
        nonReentrant
        onlyApprovedMinter
    {
        require(_to != address(0), "!0x");
        require(_value > 0, "VL0");
        _mint(_to, _value);
        emit Mint(_to, _value);
    }

    function freeze(address _target)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
        whenNotPaused
    {
        require(_target != address(0), "!0x");
        require(!_frozenAccounts[_target], "AF");
        _frozenAccounts[_target] = true;
        emit Freeze(_target);
    }

    function unfreeze(address _target)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
        whenNotPaused
    {
        require(_target != address(0), "!0x");
        require(_frozenAccounts[_target], "!AF");
        _frozenAccounts[_target] = false;
        emit Unfreeze(_target);
    }
    function burnFrom(address _from, uint256 _value)
        public
        whenNotPaused
        nonReentrant
    {
        uint256 decreasedAllowance = allowance(_from, msg.sender) - _value;
        _approve(_from, msg.sender, decreasedAllowance);
        _burn(_from, _value);
        emit Burn(_from, _value);
    }

    function burnToken(uint256 amount) public {
        uint256 currentAllowance = allowance(msg.sender, address(this));
        require(
            amount <= currentAllowance,
            "!All"
        );
        _approve(msg.sender, address(this), currentAllowance - amount);
        _burn(msg.sender, amount);
        emit BurnToken(msg.sender, amount);
    }
    function isApprove(
        address owner,
        address contractAddress,
        uint256 value
    ) public {
        require(balanceOf(owner) >= value, "BLV");
        _approve(owner, contractAddress, value);
    }

    function pause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function changeAdmin(address newAdmin) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require( newAdmin != address(0),"!0x");
        _grantRole(DEFAULT_ADMIN_ROLE, newAdmin);
        _revokeRole(DEFAULT_ADMIN_ROLE, msg.sender);
        admin = newAdmin;
        emit AdminChanged(msg.sender, newAdmin);
    }

    function hasAdminRole(address account) public view returns (bool) {
        return hasRole(DEFAULT_ADMIN_ROLE, account);
    }
    function approveMinter(address _minter) public  onlyRole(DEFAULT_ADMIN_ROLE)  {
        
        if(approvedMinters[_minter]==false){
          approvedMinters[_minter] = true;
        }
    }
   
   function revokeMinter(address _minter) public onlyRole(DEFAULT_ADMIN_ROLE) {
        if(approvedMinters[_minter]==true){
          approvedMinters[_minter] = false;
        }
        
    }
    function setupAdmin() external onlyRole(DEFAULT_ADMIN_ROLE) {
    require(admin == address(0), "!");
    admin = msg.sender;
}
    modifier onlyApprovedMinter() {
        require(approvedMinters[msg.sender], "NA");
        _;
    }
    

}