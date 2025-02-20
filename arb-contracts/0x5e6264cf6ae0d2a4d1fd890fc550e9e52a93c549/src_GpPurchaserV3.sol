// SPDX-License-Identifier: MIT
pragma solidity >=0.8.20;

/** 
 *    $$\                           $$\                         
 *    $$ |                          $$ |                        
 *    $$ |      $$$$$$\   $$$$$$\ $$$$$$\    $$$$$$\  $$\   $$\ 
 *    $$ |     $$  __$$\ $$  __$$\\_$$  _|  $$  __$$\ \$$\ $$  |
 *    $$ |     $$ /  $$ |$$ /  $$ | $$ |    $$$$$$$$ | \$$$$  / 
 *    $$ |     $$ |  $$ |$$ |  $$ | $$ |$$\ $$   ____| $$  $$<  
 *    $$$$$$$$\\$$$$$$  |\$$$$$$  | \$$$$  |\$$$$$$$\ $$  /\$$\ 
 *    \________|\______/  \______/   \____/  \_______|\__/  \__|
*/       

import "./lib_openzeppelin-contracts_contracts_utils_ReentrancyGuard.sol";
import "./lib_openzeppelin-contracts-upgradeable_contracts_proxy_utils_Initializable.sol";
import "./lib_openzeppelin-contracts-upgradeable_contracts_proxy_utils_UUPSUpgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {IERC20Permit} from './lib_openzeppelin-contracts_contracts_token_ERC20_extensions_IERC20Permit.sol';
import {IERC20} from "./lib_openzeppelin-contracts_contracts_token_ERC20_IERC20.sol";
import "./src_IWrapNative.sol";
import "./src_IAggregator.sol";

contract GpPurchaserV3 is 
    ReentrancyGuard, 
    Initializable, 
    UUPSUpgradeable{

    uint256 public constant VERSION = 3;
    address admin;
    uint256 constant INIT_INDEX = 1 << 255;
    mapping(address => uint256) public nonce;
    mapping (address => bool) public isOwner;

    IWrapNative public wrapNative;
    IAggregator private aggregator;
    uint256[] private _indexOfErc20;
    uint256 private _indexOfNative;
    uint256 delegateConfirmThreshold;
    uint256 updateOwnerConfirmThreshold;
    uint256 withdrawOwnerConfirmThreshold;
    uint256 updateAdminConfirmThreshold;
    mapping(address => bool) private updateOwnerChecker;
    mapping (address => bool) private withdrawOwnerChecker;
    mapping (address => bool) private updateAdminChecker;
    address[] public ownerList;
    mapping(address=> bool) private _isDuplicate;

    struct UpdateOwnerRequest{
        address oldOwner;
        address newOwner;
        uint256 confirmCount;
    }

    struct UpdateAdminRequest{
        address newAdmin;
        uint256 confirmCount;
    }

    struct WithdrawRequest{
        address token;
        address to;
        uint256 amount;
        uint256 confirmCount;
    }

    struct DelegateRequest {
        uint256 marketId;
        uint256 _consumedGp;
        uint256 _delegatedValue;
        bool _continueIfFailed;
        uint256 _selfValue;
        bytes _inputData;
    }

    UpdateOwnerRequest[] public updateOwnerRequests;
    WithdrawRequest[] public withdrawRequests;
    UpdateAdminRequest[] public updateAdminRequests;
    
    event DelegateBuyExecuted(address[] _token, address requester, uint256[] consumedGp, uint256[] delegatedValue, uint256[] selfValue, uint256[] endTime, bytes[][] adminSignature);
    event Deposit(address _tokenAddress, address sponsor, uint256 amount);
    event ConsumeTokens (address _sender, address[] _tokenAddress, uint256[] amount);

    error AdminNotAllowed();
    error ArrayLengthNotMatched();
    error ValueNotMatch();
    error AllowanceNotEnough();
    error BalanceNotEnough();
    error DuplicateToken();
    error WithdrawError();
    error RefundFailed();
    error SignatureExpired();
    error ContractBalanceNotEnough(address _token);
    error OwnerArrayNotMatchConfirmThreshold();
    error AlreadyOwner();
    error NotAnOwner();
    error SomeSignError();
    error DuplcatedSigner();
    error AlreadyAnOwner();
    error AlreadyConfirmed();
    error CandidateCannotConfirm();
    error InvalidRequestIndex();
    error InvalidReceiver();
    error AlreadyAnAdmin();
    error NotAnAdmin();

    modifier onlyOwner{
        if (!isOwner[msg.sender]){
            revert NotAnOwner();
        }
        _;
    }
    
    modifier onlyAdmin{
        if (!(admin == msg.sender)){
            revert NotAnAdmin();
        }
        _;
    }

    /**
     * @dev the same ability of constructor, but it is for proxy mechanism.
     */ 
    function initialize(address[] calldata _owners, address _aggregator_addr, address _wrapNative, address _admin) public initializer{
        __UUPSUpgradeable_init();
        aggregator = IAggregator(_aggregator_addr);
        wrapNative = IWrapNative(_wrapNative);

        admin = _admin;

        _indexOfNative = INIT_INDEX;
        
        delegateConfirmThreshold = 3;
        updateOwnerConfirmThreshold = 2;
        withdrawOwnerConfirmThreshold = 2;
        updateAdminConfirmThreshold = 2;

        if (_owners.length != delegateConfirmThreshold){
            revert OwnerArrayNotMatchConfirmThreshold();
        }else{
            for(uint256 i = 0 ; i < delegateConfirmThreshold; i++){
                if (isOwner[_owners[i]]){
                    revert AlreadyOwner();
                }
                isOwner[_owners[i]] = true;
                ownerList.push(_owners[i]);
            }
        }
    }

    //  ---------------------------------------
    // |     Public/External Write-Function    |
    //  ---------------------------------------

    function delegateBuy(
        address[] memory _tokens,
        uint256[] memory _consumedGps,
        uint256[] memory _delegatedValue,
        uint256[] memory _selfValue,
        uint256[] memory _endTime,
        bytes memory _inputData,
        bytes[][] calldata _adminSignature
    ) external nonReentrant() payable {
        if ((_tokens.length != _consumedGps.length) ||
            (_consumedGps.length != _delegatedValue.length) ||
            (_tokens.length != _delegatedValue.length)||
            (_adminSignature.length != _tokens.length) ||
            (_selfValue.length != _tokens.length) ||
            (_endTime.length != _consumedGps.length)
        ){
            revert ArrayLengthNotMatched();
        }

        for(uint256 i = 0 ; i < _tokens.length; i++){
            if (_endTime[i] < block.timestamp){
                revert SignatureExpired();
            }
            if (_tokens[i] == address(wrapNative)){
                _checkAndSwapWrapToken(_delegatedValue[i]);
            }
            if (_tokens[i] != address(0) && IERC20(_tokens[i]).balanceOf(address(this)) < _delegatedValue[i]){
                revert ContractBalanceNotEnough(_tokens[i]);
            }
            if (_tokens[i] == address(0) && address(this).balance < _delegatedValue[i]){
                revert ContractBalanceNotEnough(_tokens[i]);
            }
            _checkBalanceAndSig(_tokens[i], _consumedGps[i], _delegatedValue[i], _selfValue[i], _endTime[i], _adminSignature[i]);
        }

        _transferERC20(_tokens, _selfValue);
        
        _delegateBuy(_tokens, _delegatedValue, _selfValue, _inputData);

        nonce[msg.sender]++;

        emit DelegateBuyExecuted(_tokens, msg.sender, _consumedGps, _delegatedValue, _selfValue, _endTime, _adminSignature);
        
    }

    //  ---------------------------------------
    // |             Admin Function           |
    //  ---------------------------------------

    function updateAggregator(address _new_address) external onlyOwner{
        aggregator = IAggregator(_new_address);
    }

    function approveErc20(address _token, address _target, uint256 _amount) external onlyOwner{
        IERC20(_token).approve(_target, _amount);
    }

    function requestUpdateAdmin(address _newAdmin) external onlyOwner{
        if (admin == _newAdmin){
            revert AlreadyAnAdmin();
        }
        
        updateAdminRequests.push(
            UpdateAdminRequest({
                newAdmin: _newAdmin,
                confirmCount: 1
            })
        );
        updateAdminChecker[msg.sender] = true;  
    }

    function requestUpdateOwner(address _oldOwner, address _newOwner) external onlyOwner{
        if (!isOwner[_oldOwner]){
            revert NotAnOwner();
        }
        if (isOwner[_newOwner]){
            revert AlreadyAnOwner();
        }
        updateOwnerRequests.push(
            UpdateOwnerRequest({
                oldOwner: _oldOwner,
                newOwner: _newOwner,
                confirmCount: 1
            })
        );
        updateOwnerChecker[msg.sender] = true;  
    }

    function requestWithdraw(address _token, address _to, uint256 _amount) external onlyOwner(){
        if ( address(this).balance < _amount){
            revert BalanceNotEnough();
        }
        withdrawRequests.push(
            WithdrawRequest({
                token: _token,
                to: _to,
                amount: _amount,
                confirmCount: 1
            })
        );
        withdrawOwnerChecker[msg.sender] = true;
    }

    function confirmUpdateOwner(uint256 _index) external onlyOwner{
        if(_index >= updateOwnerRequests.length){
            revert InvalidRequestIndex();
        } 
        UpdateOwnerRequest storage request = updateOwnerRequests[_index];

        if (updateOwnerChecker[msg.sender]){
            revert AlreadyConfirmed();
        }
        // if (msg.sender == request.oldOwner){
        //     revert CandidateCannotConfirm();
        // }
        request.confirmCount += 1;

        if (request.confirmCount == updateOwnerConfirmThreshold){
            isOwner[request.oldOwner] = false;
            isOwner[request.newOwner] = true;

            for(uint256 i = 0 ; i < ownerList.length; i++){
                if (ownerList[i] == request.oldOwner){
                    ownerList[i] = request.newOwner;
                    break;
                }
            }

            for(uint256 j = 0 ;j < ownerList.length; j++){
                if(updateOwnerChecker[ownerList[j]]){
                    updateOwnerChecker[ownerList[j]] = false;
                }
            }

            if (updateOwnerRequests.length == 1 ||
                (updateOwnerRequests.length - 1) == _index){
                updateOwnerRequests.pop();
            }else{
                UpdateOwnerRequest memory tmp = updateOwnerRequests[_index];
                updateOwnerRequests[_index] = updateOwnerRequests[updateOwnerRequests.length - 1];
                updateOwnerRequests[updateOwnerRequests.length - 1] = tmp;
                updateOwnerRequests.pop();
            }
        }
    }

    function confirmUpdateAdmin(uint256 _index) external onlyOwner{
        if(_index >= updateAdminRequests.length){
            revert InvalidRequestIndex();
        } 
        UpdateAdminRequest storage request = updateAdminRequests[_index];

        if (updateAdminChecker[msg.sender]){
            revert AlreadyConfirmed();
        }
        request.confirmCount += 1;

        if (request.confirmCount == updateAdminConfirmThreshold){
            admin = request.newAdmin;

            for(uint256 j = 0 ;j < ownerList.length; j++){
                if(updateAdminChecker[ownerList[j]]){
                    updateAdminChecker[ownerList[j]] = false;
                }
            }
            if (updateAdminRequests.length == 1 ||
                (updateAdminRequests.length - 1) == _index){
                updateAdminRequests.pop();
            }else{
                UpdateAdminRequest memory tmp = updateAdminRequests[_index];
                updateAdminRequests[_index] = updateAdminRequests[updateAdminRequests.length - 1];
                updateAdminRequests[updateAdminRequests.length - 1] = tmp;
                updateAdminRequests.pop();
            }
        }
    }

    function confirmWithdraw(uint256 _index) external nonReentrant() onlyOwner{
        if(_index >= withdrawRequests.length){
            revert InvalidRequestIndex();
        } 
        WithdrawRequest storage request = withdrawRequests[_index];

        if (withdrawOwnerChecker[msg.sender]){
            revert AlreadyConfirmed();
        }

        request.confirmCount += 1;

        if (request.confirmCount == withdrawOwnerConfirmThreshold){

            _withdraw(request.token, request.to, request.amount);

            for(uint256 j = 0 ;j < ownerList.length; j++){
                if(withdrawOwnerChecker[ownerList[j]]){
                    withdrawOwnerChecker[ownerList[j]] = false;
                }
            }

            if (withdrawRequests.length == 1 ||
                (withdrawRequests.length - 1) == _index){
                withdrawRequests.pop();
            }else{
                WithdrawRequest memory tmp = withdrawRequests[_index];
                withdrawRequests[_index] = withdrawRequests[withdrawRequests.length - 1];
                withdrawRequests[withdrawRequests.length - 1] = tmp;
                withdrawRequests.pop();
            }
        }
    }

    //  ---------------------------------------
    // |           Internal Function          |
    //  ---------------------------------------

    /**
     * @dev The function overrides one from UUPSUpgradeable to ensure that only an admin can update it.
     */ 
    function _authorizeUpgrade(address newImplementation) internal view onlyAdmin override {
        require(newImplementation != address(0), "Cannot be zero address.");
    }

    //  ---------------------------------------
    // |           Private Function           |
    //  ---------------------------------------
    
    /**
     * @dev Verified admin signature for GP pay.
     */ 
    function _verifyAdminSignature(
        address _token,
        uint256 consumedGp,
        uint256 delegatedValue,
        uint256 _endTime,
        bytes memory signature
    ) private view returns (bool, address) {
        bytes32 messageHash = _getMessageHash(_token, msg.sender, consumedGp, delegatedValue, _endTime);
        bytes32 ethSignedMessageHash = _getEthSignedMessageHash(messageHash);
        address recoverOwner = _recoverSigner(ethSignedMessageHash, signature);

        return (isOwner[recoverOwner], recoverOwner) ;
    }

    /**
     * @dev recover signature to signer address.
     */ 
    function _recoverSigner(bytes32 ethSignedMessageHash, bytes memory signature) private pure returns (address) {
        (bytes32 r, bytes32 s, uint8 v) = _splitSignature(signature);
        require(v == 27 || v == 28, "Invalid signature 'v' value");
        return ecrecover(ethSignedMessageHash, v, r, s);
    }

    /**
     * @dev Split signature to r, s, v
     */ 
    function _splitSignature(bytes memory sig) private pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(sig.length == 65, "Invalid signature length");

        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
    }
    /**
     * @dev get message.
     */ 
    function _getMessageHash(
        address _token, 
        address sender, 
        uint256 consumedGp,
        uint256 delegatedValue,
        uint256 _endTime
    ) private view returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                nonce[msg.sender],
                _token,
                sender,
                consumedGp,
                delegatedValue,
                _endTime
            )
        );
    }

    /**
     * @dev get ethereum Message, which follow EIP-191
     */ 
    function _getEthSignedMessageHash(bytes32 messageHash) private pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                messageHash
            )
        );
    }

    function _delegateBuy(
        address[] memory _tokens,
        uint256[] memory _delegatedValue,
        uint256[] memory _selfValue,
        bytes memory _inputData
    ) private{
        uint256[] memory preTokenAmount = _getContractBalance( _tokens);
        
        _checkDuplicateTokensAndFillTokenIndex(_tokens);
        if (_indexOfErc20.length == 0){
            uint256 value = _delegatedValue[0] + _selfValue[0];
            aggregator.batchBuyWithETH{value: value }(_inputData);
        }else{
            IAggregator.ERC20Pair[] memory erc20Pairs = new IAggregator.ERC20Pair[](_indexOfErc20.length);
            address[] memory erc20Arr = new address[](_indexOfErc20.length);
            for(uint256 i = 0 ; i < _indexOfErc20.length; i++){
                uint256 _index = _indexOfErc20[i];
                erc20Arr[i] = _tokens[_index];
                erc20Pairs[i] = IAggregator.ERC20Pair(
                    {
                        token: _tokens[_index],
                        amount: (_delegatedValue[_index] + _selfValue[_index])
                    }
                );
            }
            if (_indexOfNative == INIT_INDEX){
                aggregator.batchBuyWithERC20s(
                    erc20Pairs,
                    _inputData,
                    erc20Arr
                );
            }else{
                aggregator.batchBuyWithERC20s{value: (_delegatedValue[_indexOfNative] + _selfValue[_indexOfNative])}(
                    erc20Pairs,
                    _inputData,
                    erc20Arr
                );
            }
        }
        uint256[] memory consumeTokenAmount = _getConsumeTokenAmount(_tokens, preTokenAmount);
        
        emit ConsumeTokens(msg.sender, _tokens, consumeTokenAmount);

        uint256[] memory refundAmount = _getRefundAmount(_tokens, _delegatedValue, _selfValue, consumeTokenAmount);
        _refund(_tokens, refundAmount);
        _clean_storage(_tokens); 
    }

    function _checkBalanceAndSig(
        address _token,
        uint256 _consumedGp,
        uint256 _delegatedValue,
        uint256 _selfValue,
        uint256 _endTime,
        bytes[] memory _adminSignature
        ) private {
            uint256 confirmCount = 0;
            address sender = msg.sender;
            uint256 value = msg.value;
            if (_token != address(0)){
                if(IERC20(_token).allowance(sender, address(this)) < _selfValue){
                    revert AllowanceNotEnough();
                }
                if (IERC20(_token).balanceOf(sender) < _selfValue){
                    revert BalanceNotEnough();
                }
            }else{
                if (value != _selfValue){
                    revert ValueNotMatch();
                }
            }
            for(uint256 i = 0 ; i < _adminSignature.length; i++){
                address[] memory confirmAddr = new address[](delegateConfirmThreshold);
                (bool _isVerified, address _recoverOwner) = _verifyAdminSignature(_token, _consumedGp, _delegatedValue, _endTime, _adminSignature[i]);
                if(!_isVerified){
                    revert AdminNotAllowed();
                }else{
                    _checkVerifiedOwnerDuplicated(confirmAddr, _recoverOwner);
                    confirmAddr[confirmCount] = _recoverOwner;
                }
                confirmCount += 1;  
            }
            if (confirmCount != delegateConfirmThreshold){
                revert SomeSignError();
            }
            
    }

    function _transferERC20(
        address[] memory _tokens,
        uint256[] memory _selfValue
    ) private {
        for(uint256 i = 0 ; i < _tokens.length; i++){
            if((_tokens[i] != address(0)) && (_selfValue[i] != 0)){
                IERC20(_tokens[i]).transferFrom(msg.sender, address(this), _selfValue[i]); 
            }
        }
    }

    //  ---------------------------------------
    // |           Depsoit Function           |
    //  ---------------------------------------
    
    function depsoitNativeToken() external payable{
        emit Deposit(address(0), msg.sender, msg.value);
    }

    function depsoitERC20(
        address _tokenAddress,
        uint256 _value
    ) external payable{ 
        IERC20(_tokenAddress).transferFrom(msg.sender, address(this), _value); 
        emit Deposit(_tokenAddress, msg.sender, _value);
    }

    function _checkDuplicateTokensAndFillTokenIndex (
        address[] memory _tokens
    ) private {
        for(uint256 i = 0 ; i < _tokens.length; i++){
            if (_isDuplicate[_tokens[i]]){
                revert DuplicateToken();
            }
            _isDuplicate[_tokens[i]] = true;
            if (_tokens[i] != address(0)){
                _indexOfErc20.push(i);
            }else{
                _indexOfNative = i;
            }
        }
    }

    function _clean_storage(
        address[] memory _tokens
    ) private {
        for(uint256 i = 0 ; i < _tokens.length; i++){
            _isDuplicate[_tokens[i]] = false;
        }
        delete _indexOfErc20;
        _indexOfNative = INIT_INDEX;
        
    }

    function _getContractBalance (
        address[] memory _tokens
    )private view returns(uint256[] memory) {
        uint256[] memory _tokenAmount = new uint256[](_tokens.length);
        for(uint256 i = 0 ; i < _tokens.length; i ++){
            if (_tokens[i] == address(0)){
                _tokenAmount[i] = address(this).balance;
                continue;
            }
            _tokenAmount[i] = IERC20(_tokens[i]).balanceOf(address(this));
        }

        return _tokenAmount;
    }

    function _getConsumeTokenAmount(address[] memory _tokens, uint256[] memory _preBalance) private view returns (uint256[] memory) {
        uint256[] memory consumeAmount = new uint256[](_tokens.length);
        for(uint256 i = 0 ; i < _tokens.length; i ++){
            if (_tokens[i] == address(0)){
                consumeAmount[i] = _preBalance[i] - address(this).balance;
                continue;
            }
            consumeAmount[i] = _preBalance[i] - IERC20(_tokens[i]).balanceOf(address(this));
        }
        return consumeAmount;
    }

    function _getRefundAmount(
        address[] memory _tokens,
        uint256[] memory _delegatedValue,
        uint256[] memory _selfValue,
        uint256[] memory _consumeValue
    ) private pure returns(uint256[] memory){
        uint256[] memory refunds = new uint256[](_tokens.length);
        for(uint256 i = 0 ; i < _tokens.length; i++){
            if (_delegatedValue[i] < _consumeValue[i] ){
                refunds[i] = _selfValue[i] - (_consumeValue[i] - _delegatedValue[i]);
            }else{
                refunds[i] = _selfValue[i];
            }
        }
        return refunds;
    }

    function _checkVerifiedOwnerDuplicated(
        address[] memory alreadyConfirmed,
        address _toBeCheck
    )private pure {
        for(uint256 i = 0 ; i < alreadyConfirmed.length; i++){
            if (alreadyConfirmed[i] == _toBeCheck){
                revert DuplcatedSigner();
            }
        }
    }

    function _refund(address[] memory _tokens, uint256[] memory _amount) private{
        for(uint256 i = 0 ; i < _tokens.length; i++){
            if (_amount[i] == 0) {
                continue;
            }else{
                if (_tokens[i] != address(0)){
                    IERC20(_tokens[i]).transfer(msg.sender, _amount[i]);
                }else{
                    (bool success, ) = payable(msg.sender).call{value: _amount[i]}("");
                    if (!success){
                        revert RefundFailed();
                    }
                }
            }   
        }
    }

    function _checkAndSwapWrapToken( uint256 _amount) private{
        uint256 selfBalance = wrapNative.balanceOf(address(this));
        if (selfBalance < _amount){
            uint256 toSwapAmount = _amount - selfBalance;
            if (toSwapAmount <= address(this).balance){
                _swap2WETH(toSwapAmount);
            }else{
                revert BalanceNotEnough();
            }
        }
    }

    function _swap2WETH( uint256 _amount ) private {
        wrapNative.deposit{value: _amount}();
    }

    function _withdraw(address _token, address _recipient, uint256 _amount) private {
        if (_recipient == address(0)){
            revert InvalidReceiver();
        }
        if (_token == address(0)){
            (bool success, ) = payable(_recipient).call{value: _amount}("");
            if (!success){
                revert WithdrawError();
            }
        }else{
            IERC20(_token).transfer(_recipient, _amount);
        }
    }


    receive() external payable{}
}