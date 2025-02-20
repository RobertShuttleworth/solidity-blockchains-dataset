// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./lib_openzeppelin-contracts_contracts_token_ERC20_ERC20.sol";
import "./lib_openzeppelin-contracts_contracts_access_Ownable.sol";

contract DRESS is ERC20, Ownable {
    struct VestingSchedule {
        uint256 totalAmount;      // 총 베스팅 금액
        uint256 cliffDuration;    // cliff 기간 (초)
        uint256 vestingDuration;  // 베스팅 기간 (초)
        uint256 startTimestamp;   // 시작 시간
        uint256 claimedAmount;    // 청구된 금액
    }

    mapping(address => VestingSchedule) public vestingSchedules;
    mapping(address => uint256) private _transferredAmounts;

    constructor(
        address ecosystem,
        address foundation,
        address marketing,
        address liquidity,
        address teamAdvisor,
        address partnership,
        address privateSale1,
        address privateSale2
    ) ERC20("DRESS", "DRESS") Ownable(msg.sender) {
        uint256 totalSupply = 2_000_000_000 * 10**decimals();

        // 초기 토큰 분배
        _mint(ecosystem, 540_000_000 * 10**decimals());
        _mint(foundation, 400_000_000 * 10**decimals());
        _mint(marketing, 300_000_000 * 10**decimals());
        _mint(liquidity, 300_000_000 * 10**decimals());
        _mint(teamAdvisor, 200_000_000 * 10**decimals());
        _mint(partnership, 100_000_000 * 10**decimals());
        _mint(privateSale1, 37_650_000 * 10**decimals());
        _mint(privateSale2, 122_350_000 * 10**decimals());

        // 베스팅 스케줄 설정
        // Ecosystem: 6개월 클리프, 12개월 베스팅
        vestingSchedules[ecosystem] = VestingSchedule({
            totalAmount: 540_000_000 * 10**decimals(),
            cliffDuration: 180 days,
            vestingDuration: 360 days,
            startTimestamp: block.timestamp,
            claimedAmount: 0
        });

        // Foundation: 12개월 클리프, 12개월 베스팅
        vestingSchedules[foundation] = VestingSchedule({
            totalAmount: 400_000_000 * 10**decimals(),
            cliffDuration: 360 days,
            vestingDuration: 360 days,
            startTimestamp: block.timestamp,
            claimedAmount: 0
        });

        // Marketing: 즉시 해제
        vestingSchedules[marketing] = VestingSchedule({
            totalAmount: 0,
            cliffDuration: 0,
            vestingDuration: 0,
            startTimestamp: block.timestamp,
            claimedAmount: 0
        });

        // Liquidity: 즉시 해제
        vestingSchedules[liquidity] = VestingSchedule({
            totalAmount: 0,
            cliffDuration: 0,
            vestingDuration: 0,
            startTimestamp: block.timestamp,
            claimedAmount: 0
        });

        // Team & Advisor: 12개월 클리프, 48개월 베스팅
        vestingSchedules[teamAdvisor] = VestingSchedule({
            totalAmount: 200_000_000 * 10**decimals(),
            cliffDuration: 360 days,
            vestingDuration: 1440 days,
            startTimestamp: block.timestamp,
            claimedAmount: 0
        });

        // Partnership: 3개월 클리프, 12개월 베스팅
        vestingSchedules[partnership] = VestingSchedule({
            totalAmount: 100_000_000 * 10**decimals(),
            cliffDuration: 90 days,
            vestingDuration: 360 days,
            startTimestamp: block.timestamp,
            claimedAmount: 0
        });

        // Private Sale 1: 1개월 클리프, 12개월 베스팅
        vestingSchedules[privateSale1] = VestingSchedule({
            totalAmount: 37_650_000 * 10**decimals(),
            cliffDuration: 30 days,
            vestingDuration: 360 days,
            startTimestamp: block.timestamp,
            claimedAmount: 0
        });

        // Private Sale 2: 2개월 클리프, 12개월 베스팅
        vestingSchedules[privateSale2] = VestingSchedule({
            totalAmount: 122_350_000 * 10**decimals(),
            cliffDuration: 60 days,
            vestingDuration: 360 days,
            startTimestamp: block.timestamp,
            claimedAmount: 0
        });
    }

    // 현재 베스팅된 토큰 수량 계산
    function getVestedAmount(address account) public view returns (uint256) {
        VestingSchedule storage schedule = vestingSchedules[account];
        
        // Marketing과 Liquidity는 전체 잔액이 베스팅됨
        if (schedule.totalAmount == 0) {
            return balanceOf(account);
        }

        // 클리프 기간이 지나지 않았으면 0
        if (block.timestamp < schedule.startTimestamp + schedule.cliffDuration) {
            return 0;
        }

        // 베스팅 기간이 끝났으면 전체 금액
        if (block.timestamp >= schedule.startTimestamp + schedule.vestingDuration + schedule.cliffDuration) {
            return schedule.totalAmount;
        }

        // 클리프 기간이 지난 후부터 선형적으로 베스팅
        uint256 timeFromCliff = block.timestamp - (schedule.startTimestamp + schedule.cliffDuration);
        return schedule.totalAmount * timeFromCliff / schedule.vestingDuration;
    }

    // 현재 청구 가능한 토큰 수량 계산
    function getClaimableAmount(address account) public view returns (uint256) {
        VestingSchedule storage schedule = vestingSchedules[account];
        
        // Marketing과 Liquidity는 전체 잔액이 청구 가능
        if (schedule.totalAmount == 0) {
            return balanceOf(account);
        }

        uint256 vestedAmount = getVestedAmount(account);
        uint256 claimedAmount = getClaimedAmount(account);
        if (vestedAmount <= claimedAmount) {
            return 0;
        }
        return vestedAmount - claimedAmount;
    }

    // 청구한 토큰 수량 조회
    function getClaimedAmount(address account) public view returns (uint256) {
        return vestingSchedules[account].claimedAmount;
    }

    // 토큰 클레임
    function _claimTokens(address account) internal {
        uint256 claimableAmount = getClaimableAmount(account);
        require(claimableAmount > 0, "No tokens available to claim");
        
        vestingSchedules[account].claimedAmount += claimableAmount;
    }

    function _update(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        if (from != address(0)) { // 민팅이 아닌 경우에만 체크
            VestingSchedule storage schedule = vestingSchedules[from];
            
            if (schedule.totalAmount > 0) {
                // 자동으로 클레임 처리
                _claimTokens(from);
                
                uint256 transferableAmount = schedule.claimedAmount - _transferredAmounts[from];
                require(transferableAmount >= amount, "DRESS: transfer amount exceeds transferable balance");
                _transferredAmounts[from] += amount;
            }
        }
        super._update(from, to, amount);
    }

    // 전송된 토큰 수량 조회
    function getTransferredAmount(address account) public view returns (uint256) {
        return _transferredAmounts[account];
    }
}