// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./openzeppelin_contracts_utils_Strings.sol";
import "./openzeppelin_contracts_interfaces_IERC4626.sol";
import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./openzeppelin_contracts_utils_ReentrancyGuard.sol";
import "./openzeppelin_contracts-upgradeable_metatx_ERC2771ContextUpgradeable.sol";
import "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";
import "./openzeppelin_contracts-upgradeable_access_manager_AccessManagedUpgradeable.sol";

import "./majora-finance_erc-3525_contracts_ERC3525Upgradeable.sol";
import "./majora-finance_access-manager_contracts_interfaces_IMajoraAccessManager.sol";
import "./majora-finance_access-manager_contracts_interfaces_IMajoraAddressesProvider.sol";

import "./contracts_interfaces_IMajoraERC3525.sol";

/**
 * @title MajoraERC3525
 * @author Majora Development Association
 * @notice ERC3525 contract to manage vaults ownership and creator fee distribution
 */
contract MajoraERC3525 is
    ERC3525Upgradeable,
    ReentrancyGuard,
    ERC2771ContextUpgradeable,
    AccessManagedUpgradeable,
    IMajoraERC3525
{
    using Strings for uint256;
    using SafeERC20 for IERC20;

    /**
     * @notice Struct to store information about token IDs
     */
    struct TokenIdInfo {
        //// @notice The last time the token was claimed
        uint256 timeClaimed;
        //// @notice The value of totalRewards during the last claim 
        uint256 lastClaimTotalRewards;
    }

    /**
     * @notice The token used to pay the creator
     */
    IERC20 public tokenFee;

    /**
     * @notice The ratio of the creator fee
     */
    uint256 public constant RATIO = 1000;

    /**
     * @notice The total rewards accumulated
     */
    uint256 public totalRewards;

    /**
     * @notice The maximum period allowed to claim the token
     */
    uint256 public constant MAX_CLAIM_DELAY = 180 days;

    /**
     * @notice The address of the vault
     */
    address public vault;

    /**
     * @notice The factory contract that provides addresses
     */
    IMajoraAddressesProvider public immutable addressesProvider;

    /**
     * @notice Mapping from token ID to its associated information
     */
    mapping(uint256 => TokenIdInfo) public tokenIdInfo;

    constructor(
        address _addressesProvider
    ) ERC2771ContextUpgradeable(address(0)) {
        addressesProvider = IMajoraAddressesProvider(_addressesProvider);
        _disableInitializers();
    }

    /**
     * @notice Checks if the given address is a trusted forwarder.
     * @dev Overrides the ERC2771Context isTrustedForwarder function to utilize the RELAYER_ROLE.
     * @param _forwarder The address to check.
     * @return bool True if the address has the RELAYER_ROLE, false otherwise.
     */
    function isTrustedForwarder(
        address _forwarder
    ) public view override returns (bool) {
        IMajoraAccessManager _authority = IMajoraAccessManager(authority());
        (bool isMember, ) = _authority.hasRole(
            _authority.ERC2771_RELAYER_ROLE(),
            _forwarder
        );

        return isMember;
    }

    function _msgSender()
        internal
        view
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (address)
    {
        return ERC2771ContextUpgradeable._msgSender();
    }

    function _msgData()
        internal
        view
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (bytes calldata)
    {
        return ERC2771ContextUpgradeable._msgData();
    }

    function _contextSuffixLength()
        internal
        view
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (uint256)
    {
        return ERC2771ContextUpgradeable._contextSuffixLength();
    }

    /**
     * @dev Initializes the contract with the specified vault, owner, tokenFee and treasury.
     * @param _vault The address of the vault.
     * @param _owner The address of the contract owner.
     * @param _tokenFee The address of the ERC20 token to redeem for a proportional share.
     * @param _authority The address of the access manager
     */
    function initialize(
        address _vault,
        address _owner,
        address _tokenFee,
        address _authority
    ) external initializer {
        __ERC3525_init("MajoraERC3525", "SERC3525", 18);
        __AccessManaged_init(_authority);
        vault = _vault;
        tokenFee = IERC20(_tokenFee);
        _mint(_owner, 1, RATIO);
    }

    /**
     * @dev Redeems tokens in the specified token ID.
     * @param _tokenId The ID of the token to redeem.
     */
    function redeem(uint256 _tokenId) public nonReentrant {
        if (balanceOf(_tokenId) == 0) revert ZeroBalanceToken();
        _claimRewards(_tokenId);
    }

    /**
     * @dev Adds rewards to the contract.
     * @param _amount The amount of tokens to add as rewards.
     */
    function addRewards(uint256 _amount) external {
        if (msg.sender != vault) revert NotVault();
        totalRewards += _amount;
        tokenFee.safeTransferFrom(vault, address(this), _amount);

        emit MajoraERC3525Update(
            MajoraERC3525UpdateType.ReceiveRewards,
            abi.encode(address(tokenFee), _amount, block.timestamp)
        );
    }

    /**
     * @dev Function called before any token transfer occurs. Claims rewards for the sender and recipient if necessary.
     * @param _fromTokenId The ID of the token being transferred from.
     * @param _toTokenId The ID of the token being transferred to.
     */
    function _beforeValueTransfer(
        address _from,
        address _to,
        uint256 _fromTokenId,
        uint256 _toTokenId,
        uint256 _slot,
        uint256 _value
    ) internal override {
        if (_fromTokenId != 0) _claimRewards(_fromTokenId);

        if (_exists(_toTokenId)) {
            _claimRewards(_toTokenId);
        } else {
            TokenIdInfo storage info = tokenIdInfo[_toTokenId];
            info.timeClaimed = block.timestamp;
            info.lastClaimTotalRewards = totalRewards;
        }

        emit MajoraERC3525Update(
            MajoraERC3525UpdateType.Transfer,
            abi.encode(_from, _to, _fromTokenId, _toTokenId, _slot, _value)
        );
    }

    /**
     * @dev Redeems tokens in the treseaury address if token ID not claimed after 6 months.
     * @param _tokenId The ID of the token to redeem.
     */
    function pullUnclaimedToken(uint256 _tokenId) public {
        if (balanceOf(_tokenId) == 0) revert ZeroBalanceToken();
        TokenIdInfo storage info = tokenIdInfo[_tokenId];

        if (block.timestamp - info.timeClaimed <= MAX_CLAIM_DELAY) {
            revert ClaimDelayNotReached();
        }

        uint256 concernedRewards = totalRewards - info.lastClaimTotalRewards;
        uint256 feeClaimable = (concernedRewards * balanceOf(_tokenId)) /
            uint256(RATIO);

        if (feeClaimable > 0) {
            address treasury = addressesProvider.treasury();
            info.timeClaimed = block.timestamp;
            info.lastClaimTotalRewards = totalRewards;
            tokenFee.safeTransfer(treasury, feeClaimable);

            emit MajoraERC3525Update(
                MajoraERC3525UpdateType.Redeem,
                abi.encode(_tokenId, treasury, feeClaimable)
            );
        }
    }

    /**
     * @dev Returns the URI for a specific token ID.
     * @return The URI for the specified token ID.
     */
    function tokenURI(
        uint256
    ) public view virtual override returns (string memory) {
        string memory vaultName = IERC4626(vault).name();
        return string(abi.encodePacked(vaultName, " - ERC3525"));
    }

    /**
     * @dev Calculates the rewards earned by the owner of a specific token ID and transfers them to the owner if there are any rewards to claim.
     * @param _tokenId The ID of the token to claim rewards for.
     * @return A boolean indicating whether the claim was successful.
     */
    function _claimRewards(uint256 _tokenId) internal returns (bool) {
        TokenIdInfo storage info = tokenIdInfo[_tokenId];
        address owner = ownerOf(_tokenId);
        uint256 concernedRewards = totalRewards - info.lastClaimTotalRewards;
        uint256 feeClaimable = (concernedRewards * balanceOf(_tokenId)) /
            uint256(RATIO);

        info.timeClaimed = block.timestamp;
        info.lastClaimTotalRewards = totalRewards;
        if (feeClaimable > 0) {
            tokenFee.safeTransfer(owner, feeClaimable);

            emit MajoraERC3525Update(
                MajoraERC3525UpdateType.Redeem,
                abi.encode(_tokenId, owner, feeClaimable)
            );
        }

        return true;
    }
}