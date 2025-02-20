// SPDX-License-Identifier: MIT

pragma solidity ^0.8.27;

import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./openzeppelin_contracts_token_ERC20_ERC20.sol";
import "./openzeppelin_contracts_utils_ReentrancyGuard.sol";
import "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";
import "./openzeppelin_contracts_access_Ownable.sol";
import "./contracts_BlackSail_Interface.sol";

/**
 * @dev Implementation of a vault to deposit funds for yield optimizing.
 * This is the contract that receives funds and that users interface with.
 * The yield optimizing strategy itself is implemented in a separate 'Strategy.sol' contract.
 */
contract Blacksail_Vault is ERC20, ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    struct AccountInfo {
        uint256 actionTime;
        uint256 amount;
        string lastAction;
        bool staked;
    }

    mapping (address => AccountInfo) public accountData;
    // The last proposed strategy to switch to.
    UpgradedStrategy public stratCandidate;
    // The strategy currently in use by the vault.
    ISailStrategy public strategy;
    // The minimum time it has to pass before a strat candidate can be approved, set to 24 hours
    uint256 constant approvalDelay = 86400;

    event ProposedStrategyUpgrade(address implementation);
    event UpgradeStrat(address implementation);

    /**
     * @dev Sets the value of {token} to the token that the vault will hold.
     * @param _strategy the address of the strategy.
     * @param _name the name of the vault token.
     * @param _symbol the symbol of the vault token.
     */
    constructor (
        ISailStrategy _strategy,
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) Ownable(msg.sender) {
        strategy = _strategy;
    }

    function want() public view returns (IERC20) {
        return IERC20(strategy.staking_token());
    }

    /**
     * @dev It calculates the total underlying value of {token} held by the system.
     * It takes into account the vault contract balance, the strategy contract balance
     *  and the balance deployed in other contracts as part of the strategy.
     */
    function balance() public view returns (uint) {
        return want().balanceOf(address(this)) + (ISailStrategy(strategy).balanceOf());
    }

    /**
     * @dev Custom logic in here for how much the vault allows to be borrowed.
     * We return 100% of tokens for now. Under certain conditions we might
     * want to keep some of the system funds at hand in the vault, instead
     * of putting them to work.
     */
    function available() public view returns (uint256) {
        return want().balanceOf(address(this));
    }

    /**
     * @dev Function for various UIs to display the current value of one of our yield tokens.
     * Returns an uint256 with 18 decimals of how much underlying asset one vault share represents.
     */
    function getPricePerFullShare() public view returns (uint256) {
        return totalSupply() == 0 ? 1e18 : balance() * 1e18 / totalSupply();
    }

    /**
     * @dev A helper function to call deposit() with all the sender's funds.
     */
    function depositAll() external {
        deposit(want().balanceOf(msg.sender));
    }

    /**
     * @dev The entrypoint of funds into the system. People deposit with this function
     * into the vault. The vault is then in charge of sending funds into the strategy.
     */
    function deposit(uint _amount) public nonReentrant {
        require(_amount > 0, "Invalid amount");
        strategy.beforeDeposit();

        uint256 _pool = balance();
        want().safeTransferFrom(msg.sender, address(this), _amount);
        earn();
        uint256 _after = balance();
        _amount = _after - _pool; // Additional check for deflationary tokens
        uint256 shares = 0;
        if (totalSupply() == 0) {
            shares = _amount;
        } else {
            shares = (_amount * totalSupply()) / _pool;
        }

        updateDeposit(msg.sender, shares);
        _mint(msg.sender, shares);
    }

    /**
     * @dev Function to send funds into the strategy and put them to work. It's primarily called
     * by the vault's deposit() function.
     */
    function earn() internal {
        uint _bal = available();
        want().safeTransfer(address(strategy), _bal);
        strategy.deposit();
    }

    /**
     * @dev A helper function to call withdraw() with all the sender's funds.
     */
    function withdrawAll() external {
        withdraw(balanceOf(msg.sender));
    }

    /**
     * @dev Function to exit the system. The vault will withdraw the required tokens
     * from the strategy and pay up the token holder. A proportional number of IOU
     * tokens are burned in the process.
     */
    function withdraw(uint256 _shares) public {
        uint256 r = (balance() * _shares) / totalSupply();
        _burn(msg.sender, _shares);

        uint b = want().balanceOf(address(this));
        if (b < r) {
            uint _withdraw = r - b;
            strategy.withdraw(_withdraw);
            uint _after = want().balanceOf(address(this));
            uint _diff = _after - b;
            if (_diff < _withdraw) {
                r = b + _diff;
            }
        }

        updateDeposit(msg.sender, _shares);
        want().safeTransfer(msg.sender, r);
    }

    function updateDeposit(address _account, uint256 _shares) internal {
        accountData[_account].actionTime = block.timestamp;

        // not staked
        if (!accountData[_account].staked) {

            accountData[_account].amount = _shares * balance();
            accountData[_account].lastAction = "Deposit";
            accountData[_account].staked = true;

        // fully withdrawn
        } else if (accountData[_account].staked && IERC20(address(this)).balanceOf(_account) == 0) {

            accountData[_account].amount = 0;
            accountData[_account].lastAction = "Withdraw";
            accountData[_account].staked = false;

        // modified staking
        } else {
            
            uint256 currentShare = IERC20(address(this)).balanceOf(_account) / totalSupply() * balance();

            if (accountData[_account].amount > currentShare) {
                // deposit
                accountData[_account].lastAction = "Deposit";
            } else {
                // withdraw
                accountData[_account].lastAction = "Withdraw";
            }

            accountData[_account].amount = currentShare;
        }
    }

    // Function to get account info
    function earned(address _account) public view returns (uint256 actionTime, string memory action, uint256 difference) {
        
        uint256 currentShare = 0;

        if (IERC20(address(this)).balanceOf(_account) > 0 && totalSupply() > 0) {
            currentShare = IERC20(address(this)).balanceOf(_account) / totalSupply() * balance();
        }
        
        if (currentShare >= accountData[_account].amount) {
            return(accountData[_account].actionTime, accountData[_account].lastAction,  (currentShare - accountData[_account].amount));
        } else {
            return(0,"n/a",0);
        }
    }

    /** 
     * @dev Sets the candidate for the new strat to use with this vault.
     * @param _implementation The address of the candidate strategy.  
     */
    function proposeStrategyUpgrade(address _implementation) public onlyOwner {
        require(address(this) == ISailStrategy(_implementation).vault(), "Proposal not valid for this Vault");
        stratCandidate = UpgradedStrategy({
            implementation: _implementation,
            proposedTime: block.timestamp
         });

        emit ProposedStrategyUpgrade(_implementation);
    }

    /** 
     * @dev It switches the active strat for the strat candidate. After upgrading, the 
     * candidate implementation is set to the 0x00 address, and proposedTime to a time 
     * happening in +100 years for safety. 
     */

    function upgradeStrat() public onlyOwner {
        require(stratCandidate.implementation != address(0), "There is no candidate");
        require(stratCandidate.proposedTime + approvalDelay < block.timestamp, "Delay has not passed");

        emit UpgradeStrat(stratCandidate.implementation);

        strategy.retireStrat();
        strategy = ISailStrategy(stratCandidate.implementation);
        stratCandidate.implementation = address(0);
        stratCandidate.proposedTime = 5000000000;

        earn();
    }
}