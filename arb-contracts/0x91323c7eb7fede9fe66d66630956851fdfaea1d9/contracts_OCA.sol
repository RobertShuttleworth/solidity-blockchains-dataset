// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {ERC20UpgradeableCustom} from "./contracts_ERC20Custom_ERC20UpgradeableCustom.sol";
import {ERC20PermitUpgradeableCustom} from "./contracts_ERC20Custom_ERC20PermitUpgradeableCustom.sol";
import {ERC20VotesUpgradeableCustom} from "./contracts_ERC20Custom_ERC20VotesUpgradeableCustom.sol";
import {Initializable} from "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";
import {NoncesUpgradeable} from "./openzeppelin_contracts-upgradeable_utils_NoncesUpgradeable.sol";
import {OwnableUpgradeable} from "./openzeppelin_contracts-upgradeable_access_OwnableUpgradeable.sol";

/// @custom:security-contact info@onchainaustria.at
contract OCA is
    Initializable,
    ERC20UpgradeableCustom,
    OwnableUpgradeable,
    ERC20PermitUpgradeableCustom,
    ERC20VotesUpgradeableCustom
{
    address public WrappingContractAddress;
    uint256 public globalRatio; // set this to desired total OCA token amount

    event Rebase(uint256 value);
    event NewWrappingContractAddress(address newAddress);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner) public initializer {
        __ERC20_init("onchainaustria_DAO", "OCA");
        __Ownable_init(initialOwner);
        __ERC20Permit_init("onchainaustria_DAO");
        __ERC20Votes_init();
        globalRatio = 1e26;
    }

    function clock() public view override returns (uint48) {
        return uint48(block.timestamp);
    }

    // solhint-disable-next-line func-name-mixedcase
    function CLOCK_MODE() public pure override returns (string memory) {
        return "mode=timestamp";
    }

    function nonces(
        address owner
    )
        public
        view
        override(ERC20PermitUpgradeableCustom, NoncesUpgradeable)
        returns (uint256)
    {
        return super.nonces(owner);
    }

    function changeWrappingContractAddress(
        address newAddress
    ) public onlyOwner returns (bool) {
        WrappingContractAddress = newAddress;
        emit NewWrappingContractAddress(newAddress);
        return true;
    }

    function sharesToRaw(uint256 value) public view returns (uint256) {
        uint256 rawSupply = super.totalSupply();
        if (rawSupply <= globalRatio) return value;
        uint256 result = (value * rawSupply) / globalRatio; // Convert amount to shares
        return result;
    }

    function rawToShares(uint256 value) public view returns (uint256) {
        uint256 rawSupply = super.totalSupply();
        if (rawSupply <= globalRatio) return value;
        uint256 result = (value * globalRatio) / rawSupply; // Devide by globalRatio
        return result;
    }

    /**
     * @dev Returns the scaled value for a specific timepoint
     */
    function pastRawToShares(
        uint256 value,
        uint256 timepoint
    ) public view returns (uint256) {
        uint256 rawSupply = super.getPastTotalSupply(timepoint);
        if (rawSupply <= globalRatio) return value;
        uint256 result = (value * globalRatio) / rawSupply; // Devide by globalRatio
        return result;
    }

    function mint(uint256 value) public returns (bool) {
        uint256 currentSupply = super.totalSupply();
        require(currentSupply + value <= globalRatio, "Max supply reached!");
        _mint(_msgSender(), value);
        return true;
    }

    function balanceOf(address account) public view override returns (uint256) {
        uint256 userBalance = super.balanceOf(account); // Fetch balance from the parent implementation
        return rawToShares(userBalance); // Convert raw balance to shares
    }

    function totalSupply() public view override returns (uint256) {
        uint256 rawSupply = super.totalSupply();
        if (rawSupply <= globalRatio) return rawSupply;
        return globalRatio;
    }

    function rebase(address account, uint256 newTokens) external onlyOwner {
        require(newTokens > 0, "Invalid token value");
        _mint(account, newTokens);
        emit Rebase(newTokens);
    }

    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20UpgradeableCustom, ERC20VotesUpgradeableCustom) {
        uint256 _sharesToTransfer = sharesToRaw(value); // Convert amount to shares
        if (from == address(0) || from == WrappingContractAddress) {
            super._update(from, to, _sharesToTransfer);
            emit Transfer(from, to, value);
            return;
        }
        if (to != WrappingContractAddress) {
            revert ERC20InvalidReceiver(to);
        }
        super._update(from, to, _sharesToTransfer);

        // Emit Transfer event with shares not raw token amount
        emit Transfer(from, to, value);
    }

    /**
     * @dev Moves delegated votes from one delegate to another.
     * @dev Emit event based on shares not raw values.
     */
    function _moveDelegateVotes(
        address from,
        address to,
        uint256 amount
    ) internal override {
        uint256 oldDelegateVotesFrom = getVotes(from);
        uint256 oldDelegateVotesTo = getVotes(to);
        super._moveDelegateVotes(from, to, amount);
        if (from != to && amount > 0) {
            if (from != address(0)) {
                uint256 newDelegateVotesFrom = getVotes(from);
                emit DelegateVotesChanged(
                    from,
                    oldDelegateVotesFrom,
                    newDelegateVotesFrom
                );
            }
            if (to != address(0)) {
                uint256 newDelegateVotesTo = getVotes(to);
                emit DelegateVotesChanged(
                    to,
                    oldDelegateVotesTo,
                    newDelegateVotesTo
                );
            }
        }
    }

    /**
     * @dev Returns the current amount of votes that `account` has.
     */
    function getVotes(address account) public view override returns (uint256) {
        uint256 rawVotes = super.getVotes(account);
        uint256 votes = rawToShares(rawVotes);
        return votes;
    }

    /**
     * @dev Returns the scaled amount of votes that `account` had at a specific moment in the past.
     */
    function getPastVotes(
        address account,
        uint256 timepoint
    ) public view override returns (uint256) {
        uint256 rawVotes = super.getPastVotes(account, timepoint);
        uint256 votes = pastRawToShares(rawVotes, timepoint);
        return votes;
    }

    /**
     * @dev Returns the scaled total supply of votes available at a specific moment in the past.
     */
    function getPastTotalSupply(
        uint256 timepoint
    ) public view override returns (uint256) {
        uint256 rawSupply = super.getPastTotalSupply(timepoint);
        if (rawSupply <= globalRatio) return rawSupply;
        return globalRatio;
    }
}