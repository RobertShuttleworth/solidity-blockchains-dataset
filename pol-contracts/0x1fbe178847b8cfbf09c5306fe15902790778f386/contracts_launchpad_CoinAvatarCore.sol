// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./openzeppelin_contracts-upgradeable_access_AccessControlEnumerableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_utils_structs_EnumerableSetUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_utils_CountersUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_security_PausableUpgradeable.sol";
import "./openzeppelin_contracts_interfaces_IERC20.sol";
import "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";
import "./openzeppelin_contracts-upgradeable_security_ReentrancyGuardUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_proxy_utils_UUPSUpgradeable.sol";

import "./contracts_launchpad_CoinAvatarCoreSignature.sol";
import "./contracts_interfaces_IERC721.sol";
import "./contracts_interfaces_IMatrix.sol";
import "./contracts_interfaces_ICAVStaking.sol";
import "./contracts_interfaces_IRouter.sol";
import "./contracts_staking_LendingStaking.sol";

contract CoinAvatarCore is
    AccessControlEnumerableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    CoinAvatarCoreSignature,
    UUPSUpgradeable
{
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
    using SafeERC20 for IERC20;
    using CountersUpgradeable for CountersUpgradeable.Counter;

    struct TokenData {
        uint256 balance;
        uint256 fusion;
        address tokenAddress;
        bool staked;
        bool notFirstTimeStaked;
        bool lendingStaked;
    }

    struct CreateCoinArgs {
        address tokenFee;
        address tokenAddress;
        uint256 nonce;
        uint256 matrixId;
        uint256 amount;
        uint256 feeAmount;
        string uri;
    }

    // Keep all original storage variables in the same order to ensure upgrade compatibility
    IRouter public routerContract; // address of router
    IERC721 public coinToken721; // cav721 coin
    IMatrix public matrixToken; // matrix nft token
    IERC20 public feeToken; // ERC20 fee token (legacy field, kept for compatibility)
    IERC20 public cavToken; // ERC20 CAV token for fee
    ICAVStaking public cavStaking; // staking contract
    uint256 public platformFee; // amount of platform fee in USDT
    uint256 public cavFee; // amount of CAV fee
    uint32 public duration; // duration time for staking refill
    uint32 public sendAt; // last time of staking refill
    uint16 public stakingPercentage; // 1% = 1000
    uint32 public reservePercentage; // reserve percentage 1% = 1000
    uint256 public reserveBalance; // reserve balance
    uint256 public stakingBalance; // balance for staking
    LendingStaking public lendingStaking; // lending staking contract address
    CountersUpgradeable.Counter private _tokenIds; // ids counter
    EnumerableSetUpgradeable.AddressSet private whitelistedTokens20; // erc20 tokens whitelist
    EnumerableSetUpgradeable.AddressSet private whitelistedTokens721; // erc721 tokens whitelist
    mapping(uint256 => uint256) public matrixWeave; // matrix fusion counter
    mapping(address => uint256) public feeBalances;
    mapping(address => uint256) public coinNonce; // user => nonceCounter
    mapping(address => uint256) public matrixNonce; // user => nonceCounter
    mapping(uint256 => TokenData) public freezingBalances; // internalId => TokenData
    mapping(uint256 => uint256) public nonceToCoin; // nonce => coinId
    mapping(uint256 => uint256) public nonceToMold; // nonce => coinId

    // New mappings added at the end for upgrade compatibility
    mapping(address => uint256) public lendingStakeNonce; // user => nonceCounter
    mapping(address => uint256) public unfreezeNonce; // user => nonceCounter

    bytes32 public constant OWNER_LAUNCHPAD_ROLE =
        keccak256("OWNER_LAUNCHPAD_ROLE");
    bytes32 public constant SINGLE_STAKING_ROLE =
        keccak256("SINGLE_STAKING_ROLE");
    bytes32 public constant SIGNER_ROLE = keccak256("SIGNER_ROLE");

    event SetNewStakingAddress(address singleStakingContract);
    event SetDuration(uint32 newDuration);
    event SetNewStakingPercentage(uint16 newStakingPercentage);
    event SetNewReservePercentage(uint32 newReservePercentage);
    event SetPlatformToken(address coinToken721);
    event SetMatrixToken(address matrixToken);
    event SetFeeToken(address feeToken);
    event SetCavToken(address cavToken);
    event SetPlatformFee(uint256 platformFee);
    event SetCavFee(uint256 cavFee);
    event SetNewRouter(address router);
    event CreateCoin(
        address user,
        uint256 tokenId,
        uint256 matrixId,
        address tokenAddress,
        uint256 amount,
        string uri
    );
    event UnfreezeCoin(address user, uint256 tokenId);
    event Staked(address user, uint256 tokenId, uint256 balance);
    event UnStaked(address user, uint256 tokenId, uint256 balance);
    event CreatedMatrix(
        address user,
        string uri,
        uint256 matrixId,
        uint256 matrixWeave
    );
    event BalanceAddedToSkating(uint256 addedBalance);
    event ClaimLendingReward(address user, uint256 tokenId, uint256 reward);
    event Compound(address user, uint256 tokenId);

    modifier onlyOwner() {
        require(
            hasRole(OWNER_LAUNCHPAD_ROLE, msg.sender),
            "Caller is not an owner."
        );
        _;
    }

    modifier onlySingleStakingContract() {
        require(
            hasRole(SINGLE_STAKING_ROLE, msg.sender),
            "Caller is not a single staking contract."
        );
        _;
    }

    receive() external payable {}

    fallback() external payable {}

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(OWNER_LAUNCHPAD_ROLE) {}

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        string memory _name,
        string memory _version
    ) public initializer {
        __AccessControlEnumerable_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        __Signature_init(_name, _version);
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(OWNER_LAUNCHPAD_ROLE, _msgSender());
        _setRoleAdmin(OWNER_LAUNCHPAD_ROLE, OWNER_LAUNCHPAD_ROLE);
        _setRoleAdmin(DEFAULT_ADMIN_ROLE, OWNER_LAUNCHPAD_ROLE);
        sendAt = uint32(block.timestamp) + 30 days;
    }

    /// @dev Set staking contract address
    function setSingleStakingAddress(
        address singleStakingContract
    ) external onlyOwner {
        _setupRole(SINGLE_STAKING_ROLE, singleStakingContract);
        cavStaking = ICAVStaking(singleStakingContract);
        emit SetNewStakingAddress(singleStakingContract);
    }

    /// @dev Used by staking contract to pay fee if token is staked not for the first time
    function receiveFeeFromStakingContract(
        address payer,
        address tokenFeeAddress,
        uint256 feeAmount
    ) external onlySingleStakingContract {
        _feePayment(payer, tokenFeeAddress, feeAmount);
    }

    /// @dev Set new duration for staking refill
    function setDuration(uint32 newDuration) external onlyOwner {
        duration = newDuration;
        emit SetDuration(newDuration);
    }

    /// @dev Set new staking percentage
    function setNewStakingPercentage(
        uint16 newStakingPercentage
    ) external onlyOwner {
        require(newStakingPercentage <= 100000, "Incorrect percentage.");
        stakingPercentage = newStakingPercentage;
        emit SetNewStakingPercentage(newStakingPercentage);
    }

    /// @dev Set new reserve percentage
    function setNewReservePercentage(
        uint32 newReservePercentage
    ) external onlyOwner {
        require(newReservePercentage <= 100000, "Incorrect percentage.");
        reservePercentage = newReservePercentage;
        emit SetNewReservePercentage(newReservePercentage);
    }

    /// @dev Set or unset staking action (only staking contract)
    function setSingleStakingAction(
        uint256 tokenId,
        bool action
    ) external onlySingleStakingContract {
        freezingBalances[tokenId].staked = action;
        if (!action) freezingBalances[tokenId].notFirstTimeStaked = true;
    }

    /// @dev Get coin info
    function getFreezingBalance(
        uint256 tokenId
    ) external view returns (TokenData memory) {
        return freezingBalances[tokenId];
    }

    /// @dev Set platform NFT token
    function setPlatformToken(address _coinToken721) external onlyOwner {
        coinToken721 = IERC721(_coinToken721);
        emit SetPlatformToken(_coinToken721);
    }

    /// @dev Set matrix NFT token
    function setMatrixToken(address _matrixToken) external onlyOwner {
        matrixToken = IMatrix(_matrixToken);
        emit SetMatrixToken(_matrixToken);
    }

    /// @dev Set new lending staking contract address
    function setNewLendingStakingAddresses(
        address payable _lendingStaking
    ) external onlyOwner {
        lendingStaking = LendingStaking(_lendingStaking);
    }

    /// @dev Set fee token (legacy method, keeps storage stable)
    function setFeeToken(address _feeToken) external onlyOwner {
        feeToken = IERC20(_feeToken);
        emit SetFeeToken(_feeToken);
    }

    /// @dev Set CAV token
    function setCavToken(address _cavToken) external onlyOwner {
        cavToken = IERC20(_cavToken);
        emit SetCavToken(_cavToken);
    }

    /// @dev Set platform fee (USDT)
    function setPlatformFee(uint256 _platformFee) external onlyOwner {
        platformFee = _platformFee;
        emit SetPlatformFee(_platformFee);
    }

    /// @dev Set CAV fee
    function setCavFee(uint256 _cavFee) external onlyOwner {
        cavFee = _cavFee;
        emit SetCavFee(_cavFee);
    }

    /// @dev Set router address (legacy)
    function setNewRouter(address router) external onlyOwner {
        routerContract = IRouter(router);
        emit SetNewRouter(router);
    }

    /// @dev Add tokens to whitelist
    function addTokensToWhitelist(
        address[] calldata tokens,
        bool[] calldata tokensType
    ) external onlyOwner {
        require(tokens.length == tokensType.length, "Unequal length.");
        for (uint256 i; i < tokens.length; ++i) {
            if (!tokensType[i]) {
                require(whitelistedTokens20.add(tokens[i]), "Set add error");
            } else {
                require(whitelistedTokens721.add(tokens[i]), "Set add error");
            }
        }
    }

    /// @dev Remove tokens from whitelist
    function removeTokensFromWhitelist(
        address[] calldata tokens,
        bool[] calldata tokensType
    ) external onlyOwner {
        require(tokens.length == tokensType.length, "Unequal length.");
        for (uint256 i; i < tokens.length; ++i) {
            if (!tokensType[i]) {
                require(
                    whitelistedTokens20.remove(tokens[i]),
                    "Set remove error"
                );
            } else {
                require(
                    whitelistedTokens721.remove(tokens[i]),
                    "Set remove error"
                );
            }
        }
    }

    /// @dev Get list of whitelisted tokens
    function getWhitelistedTokens(
        bool tokenType
    ) external view returns (address[] memory) {
        if (tokenType) {
            return whitelistedTokens721.values();
        } else {
            return whitelistedTokens20.values();
        }
    }

    /// @dev Pause or unpause contract
    function setPause(bool pause) external onlyOwner {
        if (pause) {
            _pause();
        } else {
            _unpause();
        }
    }

    /// @dev Claim lending reward
    function claimLendingReward(uint256 tokenId) external nonReentrant {
        require(
            IERC721(coinToken721).ownerOf(tokenId) == msg.sender,
            "You are not owner of this token."
        );
        TokenData storage data = freezingBalances[tokenId];
        uint256 reward = lendingStaking.claimRewards(
            data.tokenAddress,
            tokenId,
            msg.sender
        );
        emit ClaimLendingReward(msg.sender, tokenId, reward);
    }

    /// @dev Compound lending reward
    function compound(uint256 tokenId) external nonReentrant {
        require(
            IERC721(coinToken721).ownerOf(tokenId) == msg.sender,
            "You are not owner of this token."
        );
        TokenData storage data = freezingBalances[tokenId];
        lendingStaking.compound(data.tokenAddress);
        emit Compound(msg.sender, tokenId);
    }

    /// @dev Stake or withdraw from lending platform with signature authorization
    function lendingStake(
        uint256 tokenId,
        bool action,
        address tokenFeeAddress,
        uint256 feeAmount,
        uint256 nonce,
        Signature calldata signature
    ) external payable nonReentrant {
        require(
            IERC721(coinToken721).ownerOf(tokenId) == msg.sender,
            "You are not owner of this token."
        );
        require(
            hasRole(
                SIGNER_ROLE,
                _getLendingStakeSigner(
                    msg.sender,
                    tokenId,
                    action,
                    tokenFeeAddress,
                    feeAmount,
                    nonce,
                    signature.v,
                    signature.r,
                    signature.s
                )
            ),
            "Action is inconsistent."
        );

        require(lendingStakeNonce[msg.sender] < nonce, "Wrong nonce.");
        lendingStakeNonce[msg.sender] = nonce;

        TokenData memory data = freezingBalances[tokenId];
        if (action) {
            require(
                !data.staked && !data.lendingStaked,
                "Token is already staked."
            );
            if (data.notFirstTimeStaked) {
                _feePayment(msg.sender, tokenFeeAddress, feeAmount);
            }
            data.lendingStaked = true;
            if (data.tokenAddress != address(0)) {
                IERC20(data.tokenAddress).safeTransfer(
                    address(lendingStaking),
                    data.balance
                );
            }
            lendingStaking.deposit{
                value: (data.tokenAddress == address(0)) ? data.balance : 0
            }(data.tokenAddress, data.balance, tokenId);
            emit Staked(msg.sender, tokenId, data.balance);
        } else {
            require(data.lendingStaked, "Token is not staked.");
            data.notFirstTimeStaked = true;
            data.lendingStaked = false;
            lendingStaking.withdraw(data.tokenAddress, tokenId, msg.sender);
            emit UnStaked(msg.sender, tokenId, data.balance);
        }
        freezingBalances[tokenId] = data;
    }

    /// @dev Create a coin with signature authorization
    function createCoin(
        CreateCoinArgs calldata args,
        Signature calldata signature
    ) external payable whenNotPaused nonReentrant {
        require(
            hasRole(
                SIGNER_ROLE,
                _getCreateCoinSigner(
                    msg.sender,
                    args.tokenAddress,
                    args.tokenFee,
                    args.feeAmount,
                    args.matrixId,
                    args.uri,
                    args.nonce,
                    signature.v,
                    signature.r,
                    signature.s
                )
            ),
            "Action is inconsistent."
        );

        require(coinNonce[msg.sender] < args.nonce, "Wrong nonce.");
        require(
            matrixToken.ownerOf(args.matrixId) == msg.sender,
            "You are not the owner of the matrix."
        );

        coinNonce[msg.sender] = args.nonce;

        freezingBalances[_tokenIds.current()] = TokenData(
            args.amount,
            matrixWeave[args.matrixId],
            args.tokenAddress,
            false,
            false,
            false
        );

        uint256 currentId = _tokenIds.current();
        nonceToCoin[args.nonce] = currentId;
        _tokenIds.increment();
        matrixToken.burn(args.matrixId);
        coinToken721.mint(msg.sender, currentId, args.uri);
        _feePayment(msg.sender, args.tokenFee, args.feeAmount);

        if (args.tokenAddress == address(0)) {
            if (args.tokenFee == address(0)) {
                require(
                    args.amount + args.feeAmount == msg.value,
                    "Value is not equal (amount + fee)"
                );
            } else {
                require(args.amount == msg.value, "Value is not equal");
            }
        } else {
            require(
                whitelistedTokens20.contains(args.tokenAddress),
                "Cannot be sold for this token."
            );
            IERC20(args.tokenAddress).safeTransferFrom(
                msg.sender,
                address(this),
                args.amount
            );
        }

        if (uint32(block.timestamp) >= sendAt) {
            _sendFeeToStakingContract();
        }

        emit CreateCoin(
            msg.sender,
            currentId,
            args.matrixId,
            args.tokenAddress,
            args.amount,
            args.uri
        );
    }

    /// @dev Unfreeze coin with signature authorization, returning locked tokens
    function unfreezeCoin(
        uint256 tokenId,
        address tokenFeeAddress,
        uint256 feeAmount,
        uint256 nonce,
        Signature calldata signature
    ) external payable nonReentrant {
        require(
            hasRole(
                SIGNER_ROLE,
                _getUnfreezeCoinSigner(
                    msg.sender,
                    tokenId,
                    tokenFeeAddress,
                    feeAmount,
                    nonce,
                    signature.v,
                    signature.r,
                    signature.s
                )
            ),
            "Action is inconsistent."
        );

        require(
            coinToken721.ownerOf(tokenId) == msg.sender,
            "You are not owner of this token."
        );

        require(unfreezeNonce[msg.sender] < nonce, "Wrong nonce.");
        unfreezeNonce[msg.sender] = nonce;

        TokenData memory data = freezingBalances[tokenId];
        require(data.balance != 0, "Balance is zero.");
        require(
            !data.staked && !data.lendingStaked,
            "Token is already staked."
        );
        delete freezingBalances[tokenId];

        if (data.tokenAddress == address(0)) {
            (bool sent, ) = payable(msg.sender).call{value: data.balance}("");
            require(sent, "Failed to send Ether.");
        } else {
            IERC20(data.tokenAddress).safeTransfer(msg.sender, data.balance);
        }

        _feePayment(msg.sender, tokenFeeAddress, feeAmount);
        coinToken721.burn(tokenId);

        if (uint32(block.timestamp) >= sendAt) {
            _sendFeeToStakingContract();
        }

        emit UnfreezeCoin(msg.sender, tokenId);
    }

    /// @dev Create a matrix with signature authorization
    function createMatrix(
        uint256 nonce,
        string calldata uri,
        address tokenFeeAddress,
        uint256 feeAmount,
        Signature calldata signature
    ) public payable nonReentrant {
        require(
            hasRole(
                SIGNER_ROLE,
                _getCreateMatrixSigner(
                    msg.sender,
                    uri,
                    nonce,
                    tokenFeeAddress,
                    feeAmount,
                    signature.v,
                    signature.r,
                    signature.s
                )
            ),
            "Action is inconsistent."
        );
        _createMatrix(msg.sender, tokenFeeAddress, nonce, uri, 1, feeAmount);
    }

    /// @dev Combine two matrices with signature authorization
    function combineMatrix(
        uint256[] calldata matrixIds,
        address tokenFeeAddress,
        uint256 feeAmount,
        uint256 nonce,
        string calldata uri,
        Signature calldata signature
    ) external nonReentrant {
        require(
            hasRole(
                SIGNER_ROLE,
                _getCombineMatrixSigner(
                    msg.sender,
                    uri,
                    nonce,
                    matrixIds,
                    tokenFeeAddress,
                    feeAmount,
                    signature.v,
                    signature.r,
                    signature.s
                )
            ),
            "Action is inconsistent."
        );
        require(matrixIds.length == 2, "Only two matrices can be combined.");
        require(
            matrixToken.ownerOf(matrixIds[0]) == msg.sender &&
                matrixToken.ownerOf(matrixIds[1]) == msg.sender,
            "You are not the owner of the matrix."
        );

        uint256 newWeave = matrixWeave[matrixIds[0]] +
            matrixWeave[matrixIds[1]];

        delete matrixWeave[matrixIds[0]];
        delete matrixWeave[matrixIds[1]];

        matrixToken.burn(matrixIds[0]);
        matrixToken.burn(matrixIds[1]);

        _createMatrix(
            msg.sender,
            tokenFeeAddress,
            nonce,
            uri,
            newWeave,
            feeAmount
        );
    }

    function _createMatrix(
        address receiver,
        address tokenFeeAddress,
        uint256 nonce,
        string calldata uri,
        uint256 _matrixWeave,
        uint256 feeAmount
    ) private {
        require(matrixNonce[receiver] < nonce, "Wrong nonce.");
        matrixNonce[receiver] = nonce;

        uint256 matrixId = matrixToken.mint(receiver, uri);
        nonceToMold[nonce] = matrixId;
        matrixWeave[matrixId] = _matrixWeave;

        _feePayment(receiver, tokenFeeAddress, feeAmount);

        if (uint32(block.timestamp) >= sendAt) {
            _sendFeeToStakingContract();
        }
        emit CreatedMatrix(receiver, uri, matrixId, _matrixWeave);
    }

    function _feePayment(
        address payer,
        address tokenFeeAddress,
        uint256 amount
    ) private {
        if (tokenFeeAddress == address(cavToken)) {
            uint256 stakingPool = _calculatePercentage(
                amount,
                stakingPercentage
            );
            uint256 reservePool = _calculatePercentage(
                amount,
                reservePercentage
            );
            stakingBalance += stakingPool;
            reserveBalance += reservePool;

            uint256 finalFeeAmount = amount - stakingPool - reservePool;
            feeBalances[tokenFeeAddress] += finalFeeAmount;

            cavToken.safeTransferFrom(payer, address(this), amount);
        } else if (tokenFeeAddress == address(0)) {
            feeBalances[tokenFeeAddress] += amount;
        } else {
            feeBalances[tokenFeeAddress] += amount;
            IERC20(tokenFeeAddress).safeTransferFrom(
                payer,
                address(this),
                amount
            );
        }
    }

    function _sendFeeToStakingContract() internal {
        if (stakingPercentage > 0) {
            uint256 oldBalance = stakingBalance;
            sendAt = uint32(block.timestamp) + duration;
            if (oldBalance > 0) {
                require(
                    cavToken.approve(address(cavStaking), oldBalance),
                    "Not Approved."
                );
                stakingBalance = 0;
                cavStaking.addBalance(oldBalance);
                emit BalanceAddedToSkating(oldBalance);
            }
        }
    }

    /// @dev Unlock fee tokens from contract by owner
    function unlockTokens(
        uint256 amount,
        address tokenFeeAddress
    ) external onlyOwner {
        require(
            feeBalances[tokenFeeAddress] >= amount,
            "Not enough balance for this token."
        );
        feeBalances[tokenFeeAddress] -= amount;
        IERC20(tokenFeeAddress).safeTransfer(msg.sender, amount);
    }

    /// @dev Unlock reserve tokens
    function unlockReserveTokens(uint256 amount) external onlyOwner {
        require(reserveBalance >= amount, "Not enough balance");
        reserveBalance -= amount;
        cavToken.safeTransfer(msg.sender, amount);
    }

    function _calculatePercentage(
        uint256 amt,
        uint32 percent
    ) internal pure returns (uint256) {
        return (amt * percent) / 100000;
    }

    /// @dev Get coin by nonce
    function getCoinByNonce(uint256 _nonce) external view returns (uint256) {
        return nonceToCoin[_nonce];
    }

    /// @dev Get mold by nonce
    function getMoldByNonce(uint256 _nonce) external view returns (uint256) {
        return nonceToMold[_nonce];
    }

    /// @dev Get fee balance
    function getFeeBalance(address token) external view returns (uint256) {
        return feeBalances[token];
    }

    /// @dev Check interface support
    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(AccessControlEnumerableUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    uint256[98] __gap;
}