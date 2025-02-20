// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import { Ownable } from "./openzeppelin_contracts_access_Ownable.sol";
import { OFT } from "./layerzerolabs_oft-evm_contracts_OFT.sol";
import { RateLimiter } from "./layerzerolabs_oapp-evm_contracts_oapp_utils_RateLimiter.sol";

contract FuegoOFT is OFT, RateLimiter {
    address public rateLimiter;

    event RateLimiterSet(address indexed rateLimiter);

    error OnlyRateLimiter();

    constructor(
        string memory _name,
        string memory _symbol,
        address _lzEndpoint,
        address _delegate
    ) OFT(_name, _symbol, _lzEndpoint, _delegate) Ownable(_delegate) {}

    /**
     * @dev Sets the rate limiter contract address. Only callable by the owner.
     * @param _rateLimiter Address of the rate limiter contract.
     */
    function setRateLimiter(address _rateLimiter) external onlyOwner {
        rateLimiter = _rateLimiter;
        emit RateLimiterSet(_rateLimiter);
    }

    /**
     * @dev Sets the rate limits based on RateLimitConfig array. Only callable by the owner or the rate limiter.
     * @param _rateLimitConfigs An array of RateLimitConfig structures defining the rate limits.
     */
    function setRateLimits(RateLimitConfig[] calldata _rateLimitConfigs) external {
        if (msg.sender != rateLimiter && msg.sender != owner()) revert OnlyRateLimiter();
        _setRateLimits(_rateLimitConfigs);
    }

    function _debit(
        address _from,
        uint256 _amountLD,
        uint256 _minAmountLD,
        uint32 _dstEid
    ) internal virtual override returns (uint256 amountSentLD, uint256 amountReceivedLD) {
        _outflow(_dstEid, _amountLD);
        return super._debit(_from, _amountLD, _minAmountLD, _dstEid);
    }
}