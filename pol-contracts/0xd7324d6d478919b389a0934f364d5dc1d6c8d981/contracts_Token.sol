// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./openzeppelin_contracts_token_ERC20_ERC20.sol";
import "./openzeppelin_contracts_access_Ownable.sol";

contract Token is ERC20, Ownable {
    address public presaleContract;
    address public stakingContract;
    address public airdropContract;
    address public liquidityVaultContract;
    struct LockInfo {
        uint256 amount;
        uint256 lockEndTime;
        uint256 partialUnlockTime;
    }
    
    mapping(address => LockInfo[]) public userLocks;
    uint256 public defaultPartialUnlockTime;
    uint256 public defaultFullUnlockTime;
    
    uint256 public STAKING_TAX = 2; // 2% tax for staking
    uint256 public AIRDROP_TAX = 2; // 2% tax for airdrop
    uint256 public constant INITIAL_SUPPLY = 1_000_000_000; // 1 billion tokens
    uint256 public maxWalletPercentage = 100; // 100% initially, can be changed through admin page
    bool public mintingEnabled = true;

    // Nuove variabili per IPFS e metadata
    string private _baseTokenURI;
    string private _tokenImageURI;
    mapping(string => string) private _tokenMetadata;

    constructor() ERC20("SOP", "SOP") {
        if(mintingEnabled) {
            _mint(msg.sender, INITIAL_SUPPLY * 10 ** decimals());
        }
    }

    function setMaxWalletPercentage(uint256 _percentage) external onlyOwner {
        require(_percentage > 0 && _percentage <= 100, "Invalid percentage");
        maxWalletPercentage = _percentage;
    }

    function toggleMinting() external onlyOwner {
        mintingEnabled = !mintingEnabled;
    }

    function setStakingTax(uint256 _newTax) external onlyOwner {
        require(_newTax <= 10, "Tax cannot exceed 10%");
        STAKING_TAX = _newTax;
    }

    function setAirdropTax(uint256 _newTax) external onlyOwner {
        require(_newTax <= 10, "Tax cannot exceed 10%");
        AIRDROP_TAX = _newTax;
    }

    function setDefaultUnlockTimes(uint256 _partialUnlockTime, uint256 _fullUnlockTime) external onlyOwner {
        require(_partialUnlockTime < _fullUnlockTime, "Invalid unlock times");
        defaultPartialUnlockTime = _partialUnlockTime;
        defaultFullUnlockTime = _fullUnlockTime;
    }

    function setPresaleContract(address _presale) external onlyOwner {
        presaleContract = _presale;
    }

    function setStakingContract(address _staking) external onlyOwner {
        stakingContract = _staking;
    }

    function setAirdropContract(address _airdrop) external onlyOwner {
        airdropContract = _airdrop;
    }

    function setLiquidityVaultContract(address _liquidityVault) external onlyOwner {
        liquidityVaultContract = _liquidityVault;
    }

    function lockTokens(address account, uint256 amount, uint256 fullUnlockTime, uint256 _partialUnlockTime) external {
        require(msg.sender == presaleContract, "Only presale can lock");
        userLocks[account].push(LockInfo({
            amount: amount,
            lockEndTime: fullUnlockTime > 0 ? fullUnlockTime : defaultFullUnlockTime,
            partialUnlockTime: _partialUnlockTime > 0 ? _partialUnlockTime : defaultPartialUnlockTime
        }));
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override {
        require(sender != address(0), "Transfer from zero address");
        require(recipient != address(0), "Transfer to zero address");

        // Check max wallet percentage
        if (recipient != presaleContract && 
            recipient != stakingContract && 
            recipient != airdropContract && 
            recipient != liquidityVaultContract &&
            recipient != owner()) {
            uint256 maxWalletAmount = (INITIAL_SUPPLY * maxWalletPercentage) / 100;
            require(
                balanceOf(recipient) + amount <= maxWalletAmount * 10 ** decimals(),
                "Exceeds max wallet amount"
            );
        }

        // Skip tax for special addresses
        bool skipTax = sender == presaleContract || 
                      recipient == presaleContract ||
                      sender == stakingContract || 
                      recipient == stakingContract ||
                      sender == airdropContract ||
                      recipient == airdropContract ||
                      sender == liquidityVaultContract ||
                      recipient == liquidityVaultContract ||
                      sender == owner() ||
                      recipient == owner();

        uint256 stakingTaxAmount = 0;
        uint256 airdropTaxAmount = 0;
        if (!skipTax) {
            stakingTaxAmount = (amount * STAKING_TAX) / 100;
            airdropTaxAmount = (amount * AIRDROP_TAX) / 100;
        }

        // Se il destinatario è il contratto di staking o airdrop, permetti sempre il trasferimento
        if (recipient == stakingContract || recipient == airdropContract) {
            super._transfer(sender, recipient, amount);
            return;
        }

        // Gestione dei token bloccati
        uint256 totalLocked = 0;
        for (uint i = 0; i < userLocks[sender].length; i++) {
            LockInfo storage lock = userLocks[sender][i];
            if (lock.amount > 0) {
                if (block.timestamp >= lock.lockEndTime) {
                    // Periodo di lock completamente terminato
                    lock.amount = 0;
                } else if (block.timestamp >= lock.partialUnlockTime) {
                    // Periodo di lock parziale terminato (30% sbloccato)
                    uint256 stillLocked = (lock.amount * 70) / 100;
                    totalLocked += stillLocked;
                } else {
                    totalLocked += lock.amount;
                }
            }
        }

        if (totalLocked > 0) {
            uint256 availableTokens = balanceOf(sender) - totalLocked;
            require(amount <= availableTokens, "Transfer amount exceeds unlocked balance");
        }

        uint256 totalTax = stakingTaxAmount + airdropTaxAmount;
        if (totalTax > 0) {
            if (stakingTaxAmount > 0 && stakingContract != address(0)) {
                super._transfer(sender, stakingContract, stakingTaxAmount);
            }
            if (airdropTaxAmount > 0 && airdropContract != address(0)) {
                super._transfer(sender, airdropContract, airdropTaxAmount);
            }
            super._transfer(sender, recipient, amount - totalTax);
        } else {
            super._transfer(sender, recipient, amount);
        }
    }

    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }

    // View functions per il frontend
    function getLockedTokens(address account) public view returns (uint256) {
        uint256 totalLocked = 0;
        for (uint i = 0; i < userLocks[account].length; i++) {
            LockInfo memory lock = userLocks[account][i];
            if (lock.amount > 0) {
                if (block.timestamp >= lock.lockEndTime) {
                    continue;
                } else if (block.timestamp >= lock.partialUnlockTime) {
                    totalLocked += (lock.amount * 70) / 100;
                } else {
                    totalLocked += lock.amount;
                }
            }
        }
        return totalLocked;
    }

    function getUserLockInfo(address account, uint256 index) public view returns (uint256, uint256, uint256) {
        require(index < userLocks[account].length, "Invalid lock index");
        LockInfo memory lock = userLocks[account][index];
        return (lock.amount, lock.partialUnlockTime, lock.lockEndTime);
    }

    function getUserLocksCount(address account) public view returns (uint256) {
        return userLocks[account].length;
    }

    // Funzioni IPFS e metadata
    function setBaseTokenURI(string memory baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
    }

    function setTokenImageURI(string memory imageURI) external onlyOwner {
        _tokenImageURI = imageURI;
    }

    function setTokenMetadata(string memory key, string memory value) external onlyOwner {
        _tokenMetadata[key] = value;
    }

    function tokenURI() public view returns (string memory) {
        return string(
            abi.encodePacked(
                '{',
                '"name": "', _tokenMetadata["name"], '",',
                '"description": "', _tokenMetadata["description"], '",',
                '"decimals": ', _tokenMetadata["decimals"], ',',
                '"symbol": "', _tokenMetadata["symbol"], '",',
                '"logoURI": "', _tokenImageURI, '"',
                '}'
            )
        );
    }
}