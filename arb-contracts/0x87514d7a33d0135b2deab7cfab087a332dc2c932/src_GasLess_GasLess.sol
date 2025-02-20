// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IERC20} from "./lib_openzeppelin-contracts_contracts_token_ERC20_IERC20.sol";
import {ECDSA} from "./lib_openzeppelin-contracts_contracts_utils_cryptography_ECDSA.sol";
import {MessageHashUtils} from "./lib_openzeppelin-contracts_contracts_utils_cryptography_MessageHashUtils.sol";
import {Initializable} from "./lib_openzeppelin-contracts-upgradeable_contracts_proxy_utils_Initializable.sol";
import {UUPSUpgradeable} from "./lib_openzeppelin-contracts-upgradeable_contracts_proxy_utils_UUPSUpgradeable.sol";
import {IERC20Permit} from "./src_GasLess_IERC20Permit.sol";

error GasLess__NotAuthorized();
error GasLess__NotEnoughFunds();
error GasLess_ExecutionFailed();
error GasLess_AllowanceApprovalFailed();

contract GasLess is Initializable, UUPSUpgradeable {
    enum STATE {
        OPEN,
        PAUSED,
        CLOSED
    }

    event GasLessClaimState(STATE state);

    address private i_owner;
    address public ethosToken;
    STATE private state;
    mapping(address => bool) private trustedAddresses;

    struct TokenPermit {
        address token;
        uint256 amount;
        uint256 deadline;
        uint8 _v;
        bytes32 _r;
        bytes32 _s;
    }

    address[] private s_ownedTokens;

    modifier onlyOwner() {
        if (msg.sender != i_owner) revert GasLess__NotAuthorized();
        _;
    }

    modifier onlyOpen() {
        if (state != STATE.OPEN) revert GasLess__NotAuthorized();
        _;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function initialize(address _ethosToken, address _signerAddress) public initializer {
        __UUPSUpgradeable_init();
        ethosToken = _ethosToken;
        i_owner = msg.sender;
        state = STATE.OPEN;
        trustedAddresses[_signerAddress] = true;
        emit GasLessClaimState(state);
    }

    function executeData(
        address _to,
        address _user,
        TokenPermit memory _tokenPermit,
        uint256 _nonce,
        bytes memory _signature,
        bytes calldata _data
    ) public onlyOpen {
        bool validSignature = verifySignatureV1(
            _user, _to, _tokenPermit.token, _tokenPermit.amount, _nonce, _tokenPermit.deadline, _data, _signature
        );
        if (!validSignature) revert GasLess__NotAuthorized();
        _permitAndTransfer(_user, _tokenPermit);
        _maybeApprove(_to, _tokenPermit);
        _executeCall(_to, _data);
        _maybeUpdateOwnedTokens(_tokenPermit.token);
    }

    function executeData(
        address _to,
        address _user,
        TokenPermit memory _tokenPermitA,
        TokenPermit memory _tokenPermitB,
        uint256 _nonce,
        bytes memory _signature,
        bytes calldata _data
    ) public onlyOpen {
        bool validSignature = verifySignatureV2(
            _user,
            _to,
            _tokenPermitA.token,
            _tokenPermitB.token,
            _tokenPermitA.amount,
            _tokenPermitB.amount,
            _nonce,
            _tokenPermitA.deadline,
            _data,
            _signature
        );
        if (!validSignature) revert GasLess__NotAuthorized();
        _permitAndTransfer(_user, _tokenPermitA);
        _permitAndTransfer(_user, _tokenPermitB);
        _maybeApprove(_to, _tokenPermitA);
        _executeCall(_to, _data);
        _maybeUpdateOwnedTokens(_tokenPermitA.token);
    }

    function _permitAndTransfer(address _user, TokenPermit memory _tokenPermit) private {
        IERC20Permit(_tokenPermit.token).permit(
            _user,
            address(this),
            _tokenPermit.amount,
            _tokenPermit.deadline,
            _tokenPermit._v,
            _tokenPermit._r,
            _tokenPermit._s
        );
        bool transferred = IERC20Permit(_tokenPermit.token).transferFrom(_user, address(this), _tokenPermit.amount);
        if (!transferred) revert GasLess__NotEnoughFunds();
    }

    function _executeCall(address _to, bytes calldata _data) private {
        (bool success,) = _to.call(_data);
        if (!success) revert GasLess_ExecutionFailed();
    }

    function _maybeApprove(address _to, TokenPermit memory _tokenPermit) private {
        // check if the _to is an EFC20 token
        if (!isERC20(_to) && IERC20Permit(_tokenPermit.token).allowance(address(this), _to) < _tokenPermit.amount) {
            uint256 MAX_UINT256 = type(uint256).max;
            bool approved = IERC20Permit(_tokenPermit.token).approve(_to, MAX_UINT256);
            if (!approved) revert GasLess_AllowanceApprovalFailed();
        }
    }

    function _maybeUpdateOwnedTokens(address _token) private {
        if (!addressExists(_token)) {
            s_ownedTokens.push(_token);
        }
    }

    function isERC20(address _address) public view returns (bool) {
        try IERC20Permit(_address).totalSupply() {
            return true;
        } catch {
            return false;
        }
    }

    function transferAllTokens(address _to) public onlyOwner {
        for (uint256 i = 0; i < s_ownedTokens.length; i++) {
            uint256 balance = IERC20Permit(s_ownedTokens[i]).balanceOf(address(this));
            if (balance > 0) {
                bool transfer = IERC20Permit(s_ownedTokens[i]).transfer(_to, balance);
                if (!transfer) revert GasLess__NotEnoughFunds();
            }
        }
    }

    function transferToken(address _token, address _to, uint256 _amount) public onlyOwner {
        uint256 balance = IERC20Permit(_token).balanceOf(address(this));
        if (balance < _amount) revert GasLess__NotEnoughFunds();
        bool transfer = IERC20Permit(_token).transfer(_to, _amount);
        if (!transfer) revert GasLess__NotEnoughFunds();
    }

    function addressExists(address _address) public view returns (bool) {
        for (uint256 i = 0; i < s_ownedTokens.length; i++) {
            if (s_ownedTokens[i] == _address) {
                return true;
            }
        }
        return false;
    }

    function setSignerAddress(address _signerAddress) public onlyOwner {
        trustedAddresses[_signerAddress] = true;
    }

    function removeSignerAddress(address _signerAddress) public onlyOwner {
        trustedAddresses[_signerAddress] = false;
    }

    function getOwner() public view returns (address) {
        return i_owner;
    }

    function setOwner(address _owner) public onlyOwner {
        i_owner = _owner;
    }

    function pause() public onlyOwner {
        state = STATE.PAUSED;
        emit GasLessClaimState(state);
    }

    function resume() public onlyOwner {
        state = STATE.OPEN;
        emit GasLessClaimState(state);
    }

    function verifySignatureV1(
        address _user,
        address _to,
        address _token,
        uint256 _amount,
        uint256 _nonce,
        uint256 _deadline,
        bytes calldata _data,
        bytes memory _signature
    ) private view returns (bool) {
        bytes32 encodedMessage = keccak256(abi.encodePacked(_user, _to, _token, _amount, _nonce, _deadline, _data));
        //  we want to make sure the payload matches the encoding
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(encodedMessage);
        address signerAddress = ECDSA.recover(ethSignedMessageHash, _signature);
        return trustedAddresses[signerAddress];
    }

    function verifySignatureV2(
        address _user,
        address _to,
        address _tokenA,
        address _tokenB,
        uint256 _amountA,
        uint256 _amountB,
        uint256 _nonce,
        uint256 _deadline,
        bytes calldata _data,
        bytes memory _signature
    ) private view returns (bool) {
        bytes32 encodedMessage =
            keccak256(abi.encodePacked(_user, _to, _tokenA, _tokenB, _amountA, _amountB, _nonce, _deadline, _data));
        //  we want to make sure the payload matches the encoding
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(encodedMessage);
        address signerAddress = ECDSA.recover(ethSignedMessageHash, _signature);
        return trustedAddresses[signerAddress];
    }
}