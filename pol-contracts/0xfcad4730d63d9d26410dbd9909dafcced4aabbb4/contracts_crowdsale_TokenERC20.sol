// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "./openzeppelin_contracts-upgradeable_token_ERC20_ERC20Upgradeable.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC20_extensions_ERC20BurnableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";
import "./openzeppelin_contracts-upgradeable_access_OwnableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_proxy_utils_UUPSUpgradeable.sol";

contract AURUMToken is Initializable, ERC20Upgradeable, ERC20BurnableUpgradeable, OwnableUpgradeable, UUPSUpgradeable {
    address public stakingIncentivesAddress;
    address public marketingAddress;
    address public teamAddress;
    address public developmentAddress;
    address public licenseTokensAddress;

    mapping(address => uint256) private _burnedTokens;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize(
        string memory name,
        string memory symbol,
        uint emission,
        address _stakingIncentivesAddress,
        address _marketingAddress,
        address _teamAddress,
        address _developmentAddress,
        address _licenseTokensAddress
    ) initializer public {
        __ERC20_init(name, symbol);
        __ERC20Burnable_init();
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();

        stakingIncentivesAddress = _stakingIncentivesAddress;
        marketingAddress = _marketingAddress;
        teamAddress = _teamAddress;
        developmentAddress = _developmentAddress;
        licenseTokensAddress = _licenseTokensAddress;

        uint totalSupply = emission * 10 ** decimals();

        _mint(stakingIncentivesAddress, totalSupply * 25 / 100); // 25% for Staking Incentives
        _mint(marketingAddress, totalSupply * 10 / 100);         // 10% for Marketing
        _mint(teamAddress, totalSupply * 5 / 100);               // 5% for Team
        _mint(developmentAddress, totalSupply * 10 / 100);       // 10% for Development
        _mint(licenseTokensAddress, totalSupply * 50 / 100);     // 50% for License Tokens
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function _authorizeUpgrade(address newImplementation)
    internal
    onlyOwner
    override
    {}

    function burn(uint256 amount) public override {
        super.burn(amount);
        _burnedTokens[msg.sender] += amount;
    }

    function totalBurned(address account) external view returns (uint256) {
        return _burnedTokens[account];
    }
}