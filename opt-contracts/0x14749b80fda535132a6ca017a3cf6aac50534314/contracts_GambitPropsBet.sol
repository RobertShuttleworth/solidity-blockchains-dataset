// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.0;

import { Ownable } from "./openzeppelin_contracts_access_Ownable.sol";
import { IERC20 } from "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import { ECDSA, EIP712 } from "./openzeppelin_contracts_utils_cryptography_EIP712.sol";
// import "hardhat/console.sol";

struct BetInfo {
    address token;
    uint256 amount;
    uint256 profit;
    uint8 status;   // 0-bet, 1-won, 2-lose, 3-claimed
    // bytes32[] slips;
}

struct Currency {
    address token;
    address feed;
}

contract GambitPropsBet is Ownable, EIP712 {
    uint256 public BET_FEE = 0;
    uint256 public CLAIM_FEE = 0;
    uint256 public LIQUIDITY_FEE = 1000;
    uint256 public constant FEE_DENOMINATOR = 10000;
    address public constant ZERO = address(0);
    
    uint8 public constant STATE_NONE = 0;
    uint8 public constant STATE_WON = 1;
    uint8 public constant STATE_LOST = 2;
    uint8 public constant STATE_CLAIM = 3;

    mapping(address => bytes32[]) public userBets;
    mapping(bytes32 => BetInfo) public betInfos;
    mapping(address => uint256) public tokenBets;
    mapping(address => bool) public verifiers;
    mapping(address => uint256) public tokens;
    Currency[] public currencies;
    mapping(address => address) public dataFeeds;
    mapping(address => uint256) public balances;
    // mapping(address => uint256) public winAmounts;
    // mapping(address => uint256) public failAmounts;
    mapping(address => mapping(address => uint256)) public userShares;
    mapping(address => mapping(address => uint256)) public userRewardDebt;
    mapping(address => mapping(address => uint256)) public userRewardPending;
    mapping(address => uint256) public fees;
    mapping(address => uint256) public tokenPerShare;
    mapping(address => uint256) public nonces;

    address private treasury;

    bytes32 private constant _PERMIT_TYPEHASH = keccak256("Permit(address owner,bytes32 id,address token,uint256 amount,uint256 profit,uint256 nonce,uint256 deadline)");
        
    constructor() EIP712("GambitBet", "1") {
        treasury = address(this);
    }

    modifier onlyVerifier() {
        require(verifiers[msg.sender], "Only verifier can call");
        _;
    }

    function bet(
        bytes32 _betId,
        address _collateral, 
        uint256 _amount,
        uint256 _profit,
        uint256 _deadline, 
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public payable {
        require(tokens[_collateral] > 0, "Unsupported collateral");
        require(block.timestamp <= _deadline, "Expired deadline");

        bytes32 _structHash = keccak256(abi.encode(_PERMIT_TYPEHASH, msg.sender, _betId, _collateral, _amount, _profit, nonces[msg.sender], _deadline));
        bytes32 _hash = _hashTypedDataV4(_structHash);
        address _signer = ECDSA.recover(_hash, v, r, s);
        require(verifiers[_signer], "Invalid signature");
        nonces[msg.sender] ++;

        userBets[msg.sender].push(_betId);
        betInfos[_betId].token = _collateral;
        betInfos[_betId].amount = _amount;
        betInfos[_betId].profit = _profit;        

        uint256 _fee = _amount * BET_FEE / FEE_DENOMINATOR;
        balances[_collateral] += _amount - _fee;
        
        if (_collateral == ZERO)
            require(msg.value >= _amount, "Insufficient value");
        else
            IERC20(_collateral).transferFrom(msg.sender, address(this), _amount);
    }

    function finish(bytes32[] calldata _wonBetIds, bytes32[] calldata _lostBetIds) public onlyVerifier {
        uint256[] memory _wonAmounts = new uint256[](currencies.length);
        uint256[] memory _lostAmounts = new uint256[](currencies.length);
        
        for (uint256 i = 0; i < _wonBetIds.length; i++) {
            BetInfo storage _betInfo = betInfos[_wonBetIds[i]];
            require(_betInfo.status == STATE_NONE, "Already determined");
            if (tokens[_betInfo.token] > 0) {
                _betInfo.status = STATE_WON;
                _wonAmounts[tokens[_betInfo.token] - 1] += _betInfo.profit - _betInfo.amount;
            }
        }
        for (uint256 i = 0; i < _lostBetIds.length; i++) {
            BetInfo storage _betInfo = betInfos[_lostBetIds[i]];
            require(_betInfo.status == STATE_NONE, "Already determined");
            if (tokens[_betInfo.token] > 0) {
                _betInfo.status = STATE_LOST;
                _lostAmounts[tokens[_betInfo.token] - 1] += _betInfo.amount;
            }
        }
        
        for (uint256 i = 0; i < currencies.length; i++) {
            address _currency = currencies[i].token;
            if (tokens[_currency] > 0 && _lostAmounts[i] > _wonAmounts[i]) {
                uint256 _fee = _lostAmounts[i] - _wonAmounts[i];
                balances[_currency] -= _fee;
                if (userShares[address(this)][_currency] > 0) {
                    uint256 _liquidityFee = _fee * LIQUIDITY_FEE / FEE_DENOMINATOR;
                    tokenPerShare[_currency] += _liquidityFee * 1 ether / userShares[address(this)][_currency];
                    _fee -= _liquidityFee;
                }
                if (_fee > 0) {
                    if (_currency == ZERO) {
                        (bool _success, ) = address(treasury).call{value: _fee}("");
                        require(_success, "ETH transfer fail");
                    } else {
                        IERC20(_currency).transfer(treasury, _fee);
                    }
                }
            }
        }
    }

    function addLiquidity(address _token, uint256 _amount) public payable {
        if(userShares[msg.sender][_token] > 0) {
            userRewardPending[msg.sender][_token] += tokenPerShare[_token] * userShares[msg.sender][_token] / 1 ether - userRewardDebt[msg.sender][_token];
        }

        balances[_token] += _amount;
        userShares[msg.sender][_token] += _amount;
        userShares[address(this)][_token] += _amount;

        userRewardDebt[msg.sender][_token] = (tokenPerShare[_token] * userShares[msg.sender][_token]) / 1 ether;
        
        if (_token == ZERO)
            require(msg.value >= _amount, "Insufficient value");
        else
            IERC20(_token).transferFrom(msg.sender, address(this), _amount);
    }

    function removeLiquidity(address _token, uint256 _amount) public {
        require(userShares[msg.sender][_token] > 0, "No liquidity");

        userRewardPending[msg.sender][_token] += tokenPerShare[_token] * userShares[msg.sender][_token] / 1 ether - userRewardDebt[msg.sender][_token];
        
        uint256 _userShare = _amount == 0 || _amount > userShares[msg.sender][_token] ? userShares[msg.sender][_token] : _amount;
        uint256 _amountRecieve = balances[_token] < userShares[address(this)][_token] ? balances[_token] * _userShare / userShares[address(this)][_token] : _userShare;
        userShares[msg.sender][_token] -= _userShare;
        userShares[address(this)][_token] -= _userShare;
        balances[_token] -= _amountRecieve;

        userRewardDebt[msg.sender][_token] = (tokenPerShare[_token] * userShares[msg.sender][_token]) / 1 ether;
        uint256 _earnAmount = userRewardPending[msg.sender][_token];
        userRewardPending[msg.sender][_token] = 0;

        if (_token == ZERO) {
            (bool _success, ) = address(msg.sender).call{value: _amountRecieve + _earnAmount}("");
            require(_success, "ETH transfer fail");
        } else {
            IERC20(_token).transfer(msg.sender, _amountRecieve + _earnAmount);
        }
    }

    function claimLiquidityFee() public {
        for (uint256 i = 0; i < currencies.length; i++) {
            address _currency = currencies[i].token;
            if (tokens[_currency] > 0 && userShares[msg.sender][_currency] > 0) {
                userRewardPending[msg.sender][_currency] += tokenPerShare[_currency] * userShares[msg.sender][_currency] / 1 ether - userRewardDebt[msg.sender][_currency];
                userRewardDebt[msg.sender][_currency] = (tokenPerShare[_currency] * userShares[msg.sender][_currency]) / 1 ether;
                uint256 _earnAmount = userRewardPending[msg.sender][_currency];
                userRewardPending[msg.sender][_currency] = 0;
                if (_currency == ZERO) {
                    (bool _success, ) = address(msg.sender).call{value: _earnAmount}("");
                    require(_success, "ETH transfer fail");
                } else {
                    IERC20(_currency).transfer(msg.sender, _earnAmount);
                }
            }
        }
    }

    function _claimTokenTo(address _to, uint256 _amount, address _token) private {
        require(balances[_token] >= _amount, "Insufficient balances to claim");
        uint256 _fee = _amount * CLAIM_FEE / FEE_DENOMINATOR;
        if (_fee > 0)
            fees[_token] += _fee;
        balances[_token] -= _amount;
        if (_token == ZERO) {
            (bool _success, ) = address(_to).call{value: _amount - _fee}("");
            require(_success, "ETH transfer fail");
        } else {
            IERC20(_token).transfer(_to, _amount - _fee);
        }
    }

    function claim(bytes32[] calldata _betIds) public {
        uint256[] memory _wonAmounts = new uint256[](currencies.length);
        if (_betIds.length == 0) {
            for (uint256 i = 0; i < userBets[msg.sender].length; i++) {
                bytes32 _betId = userBets[msg.sender][i];
                BetInfo storage _betInfo = betInfos[_betId];
                if (_betInfo.status == STATE_WON && tokens[_betInfo.token] > 0) {
                    _wonAmounts[tokens[_betInfo.token] - 1] += _betInfo.profit;
                    _betInfo.status = STATE_CLAIM;
                }
            }
        } else {
            for (uint256 i = 0; i < _betIds.length; i++) {
                bytes32 _betId = _betIds[i];
                BetInfo storage _betInfo = betInfos[_betId];
                if (_betInfo.status == STATE_WON && tokens[_betInfo.token] > 0) {
                    _wonAmounts[tokens[_betInfo.token] - 1] += _betInfo.profit;
                    _betInfo.status = STATE_CLAIM;
                }
            }
        }
        for (uint256 i = 0; i < currencies.length; i++) {
            address _currency = currencies[i].token;
            if (tokens[_currency] > 0 && _wonAmounts[i] > 0) {
                _claimTokenTo(msg.sender, _wonAmounts[i], _currency);
            }
        }
    }


    /********* admin actions *********/

    function withdraw(address _token, address _to) public onlyOwner {
        balances[_token] = 0;
        if (_token == ZERO) {
            (bool _success, ) = address(_to).call{value: balances[_token]}("");
            require(_success, "ETH transfer fail");
        } else {
            IERC20(_token).transfer(_to, balances[_token]);
        }
    }

    function setVerifier(address _verifier, bool _enabled) public onlyOwner {
        verifiers[_verifier] = _enabled;
    }

    function setToken(address _token, address _feed, bool _enabled) public onlyOwner {
        if (_enabled) {
            // require(_feed != ZERO, "Invalid dataFeed");
            if (tokens[_token] == 0) {
                currencies.push(Currency({
                    token: _token, feed: _feed
                }));
                tokens[_token] = currencies.length;
            } else {
                currencies[tokens[_token]].feed = _feed;
            }
        } else {
            tokens[_token] = 0;
        }
    }

    function setTreasury(address _treasury) public onlyOwner {
        treasury = _treasury;
    }

    function setFee(uint256 _feeBet, uint256 _feeClaim) public onlyOwner {
        BET_FEE = _feeBet;
        CLAIM_FEE = _feeClaim;
    }

    function setLiquidityFee(uint256 _fee) public onlyOwner {
        LIQUIDITY_FEE = _fee;
    }

    /*********************************/
}