// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";
import "./contracts_interfaces_IWETHGateway.sol";
import "./contracts_interfaces_ILendingPool.sol";

import "./openzeppelin_contracts-upgradeable_proxy_utils_UUPSUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_access_AccessControlEnumerableUpgradeable.sol";

contract LendingStaking is AccessControlEnumerableUpgradeable, UUPSUpgradeable {
    using SafeERC20 for IERC20;

    struct TokenInfo {
        uint256 accTokenPerShare; // Accrued token per share
        uint256 totalStaked; // current deposited amount in lending protocol
        uint256 totalShares; // total shares
    }

    struct PositionInfo {
        uint256 amount;
        uint256 shares;
        uint256 rewardDebt; // Reward debt
    }

    bytes32 public constant LAUNCHPAD_ROLE = keccak256("LAUNCHPAD_ROLE");
    address public constant wETH = 0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c; // eth sepolia
    IWETHGateway public aaveWETHGateway;
    ILendingPool public aaveLendingPoolV3;

    // The block number of the last pool update (tokenAddress => _tokenInfo)
    mapping(address => TokenInfo) public _tokenInfo;

    // tokenAddress -> internalIdFromCoinAvatarCore -> PositionInfo
    mapping(address => mapping(uint256 => PositionInfo)) public positions;

    address public wMatic; // wMatic

    event Deposited(
        address indexed user,
        address indexed token,
        uint256 amount,
        uint256 internalTokenId
    );
    event Withdrawn(
        address indexed user,
        address indexed token,
        uint256 amount,
        uint256 internalTokenId
    );
    event Compounded(
        address indexed user,
        address indexed token,
        uint256 amount
    );
    event RewardsClaimed(
        address indexed user,
        address indexed token,
        uint256 amount
    );

    modifier onlyCoinAvatarCore() {
        require(
            hasRole(LAUNCHPAD_ROLE, msg.sender),
            "Caller has no launchpad role."
        );
        _;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _launchpad,
        address _aaveLendingPoolV3,
        address _aaveWETHGateway
    ) public initializer {
        __UUPSUpgradeable_init();
        __AccessControlEnumerable_init();

        require(
            _launchpad != address(0),
            "CoinAvatarCore address cannot be zero"
        );
        require(
            _aaveLendingPoolV3 != address(0),
            "AAVE Lending Pool address cannot be zero"
        );
        require(
            _aaveWETHGateway != address(0),
            "AAVE WMatic Gateway address cannot be zero"
        );

        wMatic = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270; // wMatic

        aaveLendingPoolV3 = ILendingPool(_aaveLendingPoolV3);
        aaveWETHGateway = IWETHGateway(_aaveWETHGateway);

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(LAUNCHPAD_ROLE, _msgSender());
        _setupRole(LAUNCHPAD_ROLE, _launchpad);
    }

    function setNewWETHAddress(
        address _wMatic
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_wMatic != address(0), "wMatic address cannot be zero");
        wMatic = _wMatic;
    }

    function setNewAaveAddresses(
        address _aaveLendingPoolV3,
        address _aaveWETHGateway
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(
            _aaveLendingPoolV3 != address(0),
            "AAVE Lending Pool address cannot be zero"
        );
        require(
            _aaveWETHGateway != address(0),
            "AAVE WMatic Gateway address cannot be zero"
        );

        aaveLendingPoolV3 = ILendingPool(_aaveLendingPoolV3);
        aaveWETHGateway = IWETHGateway(_aaveWETHGateway);
    }

    function compound(address _token) external onlyCoinAvatarCore {
        _compound(_token);
    }

    function _compound(address _token) internal {
        uint256 balanceBefore;
        uint256 balanceAfter;
        uint256 totalWithdraw;
        uint256 totalReward;
        TokenInfo memory tokenInfo = _tokenInfo[_token];

        if (tokenInfo.totalShares == 0) {
            return;
        }

        if (_token == address(0)) {
            balanceBefore = address(this).balance;
            ILendingPool.ReserveData memory aTokenData = getAssetData(wMatic);
            uint256 allowance = IERC20(aTokenData.aTokenAddress).allowance(
                address(this),
                address(aaveWETHGateway)
            );
            if (allowance != type(uint256).max) {
                if (allowance != 0) {
                    IERC20(aTokenData.aTokenAddress).safeApprove(
                        address(aaveWETHGateway),
                        0
                    );
                }
                IERC20(aTokenData.aTokenAddress).safeApprove(
                    address(aaveWETHGateway),
                    type(uint256).max
                );
            }
            aaveWETHGateway.withdrawETH(
                address(aaveLendingPoolV3),
                type(uint256).max,
                address(this)
            );
            balanceAfter = address(this).balance;
            totalWithdraw = balanceAfter - balanceBefore;
            totalReward = totalWithdraw > tokenInfo.totalStaked
                ? totalWithdraw - tokenInfo.totalStaked
                : 0;
            tokenInfo.totalStaked = balanceAfter;
            if (totalReward > 0) {
                tokenInfo.accTokenPerShare +=
                    (totalReward * 1e18) /
                    tokenInfo.totalShares;
            }
            aaveWETHGateway.depositETH{value: totalWithdraw}(
                address(aaveLendingPoolV3),
                address(this),
                0
            );
        } else {
            balanceBefore = IERC20(_token).balanceOf(address(this));
            ILendingPool.ReserveData memory aTokenData = getAssetData(_token);
            uint256 allowance = IERC20(aTokenData.aTokenAddress).allowance(
                address(this),
                address(aaveLendingPoolV3)
            );
            if (allowance != type(uint256).max) {
                if (allowance != 0) {
                    IERC20(aTokenData.aTokenAddress).safeApprove(
                        address(aaveLendingPoolV3),
                        0
                    );
                }
                IERC20(aTokenData.aTokenAddress).safeApprove(
                    address(aaveLendingPoolV3),
                    type(uint256).max
                );
            }

            totalWithdraw = aaveLendingPoolV3.withdraw(
                _token,
                type(uint256).max,
                address(this)
            );
            balanceAfter = IERC20(_token).balanceOf(address(this));
            totalReward = totalWithdraw > tokenInfo.totalStaked
                ? totalWithdraw - tokenInfo.totalStaked
                : 0;
            tokenInfo.totalStaked = balanceAfter;
            if (totalReward > 0) {
                tokenInfo.accTokenPerShare +=
                    (totalReward * 1e18) /
                    tokenInfo.totalShares;
            }
            aaveLendingPoolV3.supply(_token, totalWithdraw, address(this), 0);
        }

        _tokenInfo[_token] = tokenInfo;

        emit Compounded(msg.sender, _token, totalWithdraw);
    }

    function getAssetData(
        address _asset
    ) public view returns (ILendingPool.ReserveData memory) {
        return aaveLendingPoolV3.getReserveData(_asset);
    }

    function deposit(
        address _token,
        uint256 _amount,
        uint256 _internalTokenId
    ) external payable onlyCoinAvatarCore {
        if (_tokenInfo[_token].totalStaked != 0) {
            _compound(_token);
        }

        require(
            positions[_token][_internalTokenId].amount == 0,
            "Token already deposited"
        );

        uint256 shares = _calculateShares(
            _token,
            _amount,
            _tokenInfo[_token].totalShares
        );

        positions[_token][_internalTokenId].amount += _amount;
        positions[_token][_internalTokenId].shares += shares;
        positions[_token][_internalTokenId].rewardDebt +=
            (shares * _tokenInfo[_token].accTokenPerShare) /
            1e18;

        _tokenInfo[_token].totalShares += shares;
        _tokenInfo[_token].totalStaked += _amount;

        if (_token == address(0)) {
            aaveWETHGateway.depositETH{value: _amount}(
                address(aaveLendingPoolV3),
                address(this),
                0
            );
        } else {
            uint256 allowance = IERC20(_token).allowance(
                address(this),
                address(aaveLendingPoolV3)
            );
            if (allowance != type(uint256).max) {
                IERC20(_token).safeApprove(address(aaveLendingPoolV3), 0);
                IERC20(_token).safeApprove(
                    address(aaveLendingPoolV3),
                    type(uint256).max
                );
            }
            aaveLendingPoolV3.supply(_token, _amount, address(this), 0);
        }

        emit Deposited(msg.sender, _token, _amount, _internalTokenId);
    }

    function withdraw(
        address _token,
        uint256 _internalTokenId,
        address receiver
    ) external onlyCoinAvatarCore {
        _compound(_token);
        PositionInfo storage position = positions[_token][_internalTokenId];
        uint256 shares = position.shares;
        uint256 amount = calculateSharesToAmount(_token, shares);

        uint256 pendingReward = (shares * _tokenInfo[_token].accTokenPerShare) /
            1e18 -
            position.rewardDebt;

        _tokenInfo[_token].totalShares -= shares;
        _tokenInfo[_token].totalStaked -= amount;
        delete positions[_token][_internalTokenId];

        if (pendingReward > 0) {
            amount -= pendingReward;
            if (_token == address(0)) {
                aaveWETHGateway.withdrawETH(
                    address(aaveLendingPoolV3),
                    pendingReward,
                    receiver
                );
            } else {
                aaveLendingPoolV3.withdraw(_token, pendingReward, receiver);
            }
        }

        if (_token == address(0)) {
            aaveWETHGateway.withdrawETH(
                address(aaveLendingPoolV3),
                amount,
                msg.sender
            );
        } else {
            aaveLendingPoolV3.withdraw(_token, amount, msg.sender);
        }

        emit Withdrawn(receiver, _token, amount, _internalTokenId);
    }

    function claimRewards(
        address token,
        uint256 internalTokenId,
        address receiver
    ) public onlyCoinAvatarCore returns (uint256) {
        _compound(token);
        PositionInfo storage position = positions[token][internalTokenId];
        uint256 accTokenPerShare = _tokenInfo[token].accTokenPerShare;
        uint256 pending = (position.shares * accTokenPerShare) /
            1e18 -
            position.rewardDebt;

        if (pending > 0) {
            position.rewardDebt = (position.shares * accTokenPerShare) / 1e18;

            if (token == address(0)) {
                aaveWETHGateway.withdrawETH(
                    address(aaveLendingPoolV3),
                    pending,
                    receiver
                );
            } else {
                aaveLendingPoolV3.withdraw(token, pending, receiver);
            }
        }

        emit RewardsClaimed(msg.sender, token, pending);
        return pending;
    }

    function getAvialableRewards(
        address token,
        uint256 internalTokenId
    ) public view returns (uint256) {
        PositionInfo storage position = positions[token][internalTokenId];
        uint256 accTokenPerShare = _tokenInfo[token].accTokenPerShare;
        uint256 pending = (position.shares * accTokenPerShare) /
            1e18 -
            position.rewardDebt;

        return pending;
    }

    function _calculateShares(
        address _token,
        uint256 amount,
        uint256 totalShares
    ) private view returns (uint256) {
        return
            totalShares == 0
                ? amount
                : (amount * totalShares) / _tokenInfo[_token].totalStaked;
    }

    function calculateAmountToShares(
        address token,
        uint256 amount
    ) public view returns (uint256) {
        return _calculateShares(token, amount, _tokenInfo[token].totalShares);
    }

    function calculateSharesToAmount(
        address token,
        uint256 shares
    ) public view returns (uint256) {
        return
            _tokenInfo[token].totalShares == 0
                ? 0
                : (_tokenInfo[token].totalStaked * shares) /
                    _tokenInfo[token].totalShares;
    }

    receive() external payable {}
    fallback() external payable {}

    uint256[99] private __gap;
}