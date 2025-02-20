// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

contract MinimalBetOneAccountWithAutoReward {
    uint8 private _outcome; // 0 = None, 1 = Team A Wins, 2 = Team B Wins, 3 = Draw
    bool private _finalized;
    uint256 private constant FEE_PERCENT = 1;
    uint256 private constant REWARD_PERCENT = 99;

    address private owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    string private _teamA;
    string private _teamB;
    string private _matchLocation;

    uint256 private _betStart;
    uint256 private _betEnd;
    uint256 private _matchTime;

    uint256 private _poolA;
    uint256 private _poolB;
    uint256 private _poolDraw;

    uint256 private _goalsA;
    uint256 private _goalsB;

    mapping(address => uint256) private _betsA;
    mapping(address => uint256) private _betsB;
    mapping(address => uint256) private _betsDraw;
    mapping(address => bool) private _isBettor;

    constructor() payable {
        owner = msg.sender;

        if (msg.value > 0) {
            uint256 fee = (msg.value * FEE_PERCENT) / 100;
            (bool feeOk, ) = owner.call{value: fee}("");
            require(feeOk, "Fee transfer failed");

            uint256 net = msg.value - fee;
            uint256 half = net / 2;

            _poolA = half;
            _poolB = net - half;
        }
    }

    function setMatchInfo(
        string calldata teamA_,
        string calldata teamB_,
        string calldata location_,
        uint256 betStart_,
        uint256 betEnd_,
        uint256 matchTime_
    ) external onlyOwner {
        require(betStart_ < betEnd_, "Invalid betting window");
        require(matchTime_ > betEnd_, "Match must be after betting ends");

        _teamA = teamA_;
        _teamB = teamB_;
        _matchLocation = location_;
        _betStart = betStart_;
        _betEnd = betEnd_;
        _matchTime = matchTime_;
    }

    function setFinalScore(uint256 goalsA, uint256 goalsB) external onlyOwner {
        require(!_finalized, "Already finalized");

        _goalsA = goalsA;
        _goalsB = goalsB;

        if (goalsA > goalsB) {
            _outcome = 1; // Team A Wins
        } else if (goalsB > goalsA) {
            _outcome = 2; // Team B Wins
        } else {
            _outcome = 3; // Draw
        }

        _finalized = true;
    }

    function withdrawUnclaimedFunds() external onlyOwner {
        require(block.timestamp > _matchTime + 30 days, "Claim period not over");
        uint256 unclaimedBalance = address(this).balance;
        (bool success, ) = owner.call{value: unclaimedBalance}("");
        require(success, "Withdraw failed");
    }

    function placeBet(uint8 outcomeCode) external payable {
        require(!_finalized, "Betting closed");
        require(block.timestamp >= _betStart && block.timestamp <= _betEnd, "Betting window closed");
        require(msg.value > 0, "Must send ETH to bet");
        require(outcomeCode == 1 || outcomeCode == 2 || outcomeCode == 3, "Invalid outcome");

        uint256 fee = (msg.value * FEE_PERCENT) / 100;
        (bool feeOk, ) = owner.call{value: fee}("");
        require(feeOk, "Fee transfer failed");

        uint256 netBet = msg.value - fee;

        if (outcomeCode == 1) {
            _betsA[msg.sender] += netBet;
            _poolA += netBet;
        } else if (outcomeCode == 2) {
            _betsB[msg.sender] += netBet;
            _poolB += netBet;
        } else {
            _betsDraw[msg.sender] += netBet;
            _poolDraw += netBet;
        }

        if (!_isBettor[msg.sender]) {
            _isBettor[msg.sender] = true;
        }
    }

    function withdrawReward() external {
        require(_finalized, "Match not finalized");

        uint256 reward;
        if (_outcome == 1) {
            require(_poolA > 0, "No bets for Team A");
            reward = (_betsA[msg.sender] * (_poolA+_poolB + _poolDraw) * 1e18 / _poolA) / 1e18;
        } else if (_outcome == 2) {
            require(_poolB > 0, "No bets for Team B");
            reward = (_betsB[msg.sender] * (_poolA+_poolB + _poolDraw) * 1e18 / _poolB) / 1e18;
        } else if (_outcome == 3) {
            require(_poolDraw > 0, "No bets for Draw");
            reward = (_betsDraw[msg.sender] * (_poolA+_poolB + _poolDraw) * 1e18 / _poolDraw) / 1e18;
        }

        require(reward > 0, "No reward available");

        _betsA[msg.sender] = 0;
        _betsB[msg.sender] = 0;
        _betsDraw[msg.sender] = 0;

        (bool success, ) = msg.sender.call{value: reward}("");
        require(success, "Reward transfer failed");
    }

    function getMatchInfo()
        external
        view
        returns (
            string memory teamA,
            string memory teamB,
            string memory location,
            uint256 betStart,
            uint256 betEnd,
            uint256 matchTime
        )
    {
        return (_teamA, _teamB, _matchLocation, _betStart, _betEnd, _matchTime);
    }

    function getPools() external view returns (uint256 poolA, uint256 poolB, uint256 poolDraw) {
        return (_poolA, _poolB, _poolDraw);
    }

    function getResult()
        external
        view
        returns (
            uint256 goalsA,
            uint256 goalsB,
            uint8 outcome,
            bool finalized
        )
    {
        return (_goalsA, _goalsB, _outcome, _finalized);
    }

    function guide() external pure returns (string memory) {
        return (
            "Guide: \n1. To place a bet, use the placeBet function with the following outcome codes: \n"
            "   - 1: Bet on Team A to win. \n   - 2: Bet on Team B to win. \n   - 3: Bet on a Draw. \n"
            "2. Use the getMatchInfo function to view match details, including teams, location, and times. \n"
            "3. Use the getPools function to check the current betting pools. \n"
            "4. After the match is finalized, call withdrawReward to claim your winnings. \n"
            "5. Use getResult to check the final match outcome."
        );
    }

    function withdrawIfNotFinalized() external {
        require(block.timestamp > _matchTime + 10 days, "Must wait 3 days after match time");
        require(!_finalized, "Match already finalized");

        uint256 betA = _betsA[msg.sender];
        uint256 betB = _betsB[msg.sender];
        uint256 betD = _betsDraw[msg.sender];
        uint256 totalBet = betA + betB + betD;

        require(totalBet > 0, "No funds to withdraw");

        _betsA[msg.sender] = 0;
        _betsB[msg.sender] = 0;
        _betsDraw[msg.sender] = 0;

        if (betA > 0) {
            _poolA -= betA;
        }
        if (betB > 0) {
            _poolB -= betB;
        }
        if (betD > 0) {
            _poolDraw -= betD;
        }

        (bool success, ) = msg.sender.call{value: totalBet}("");
        require(success, "Refund transfer failed");
    }


    receive() external payable {}
}