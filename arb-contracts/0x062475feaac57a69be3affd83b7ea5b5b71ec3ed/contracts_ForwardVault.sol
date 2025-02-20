// SPDX-License-Identifier: -- WISE --

pragma solidity =0.8.25;

import "./node_modules_openzeppelin_contracts_security_Pausable.sol";
import "./node_modules_openzeppelin_contracts_security_ReentrancyGuard.sol";

import "./node_modules_openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";
import "./node_modules_openzeppelin_contracts_token_ERC721_extensions_ERC721Enumerable.sol";

import "./contracts_OwnableMaster.sol";

error NoRewards();
error NotListed();
error InvalidValue();
error DepositPaused();
error InvalidPosition();
error DepositExceedCap();

contract ForwardingDepositUSDC is
    ERC721Enumerable,
    Pausable,
    OwnableMaster,
    ReentrancyGuard
{
    using SafeERC20 for IERC20;

    string public baseURI;
    string public baseExtension;

    IERC20 public immutable USDC_TOKEN;

    uint256 public rewardCycle;
    uint256 public interestRate;
    address public thirdPartyAddress;


    struct DepositPosition {
        uint256 amount;
        uint256 lastClaimed;
    }

    mapping(address => bool) public isWhitelisted;
    mapping(uint256 => DepositPosition) public positions;

    bool public depositsPaused;

    uint256 public totalDeposited;
    uint256 public nextPositionId;
    uint256 public totalDepositCap;

    uint256 constant HOURS_IN_YEAR = 8_760 hours;
    uint256 constant PRECISION_RATE = 10_000;

    event Deposited(
        address indexed depositor,
        uint256 indexed positionId,
        uint256 amount,
        uint256 lockTime
    );

    event RewardsClaimed(
        address indexed claimant,
        uint256 indexed positionId,
        uint256 rewardAmount
    );

    event FundsForwarded(
        address indexed thirdParty,
        uint256 amount
    );

    modifier onlyWhitelisted() {
        if (isWhitelisted[msg.sender] == false) {
            revert NotListed();
        }
        _;
    }

    constructor(
        address _usdcTokenAddress,
        address _thirdPartyAddress,
        uint256 _rewardCycle,
        uint256 _interestRate,
        uint256 _initialDepositCap
    )
        ERC721(
            "ForwardingDepositPosition",
            "FDP"
        )
        OwnableMaster(
            msg.sender
        )
    {
        if (_rewardCycle == 0) {
            revert InvalidValue();
        }

        if (_interestRate == 0) {
            revert InvalidValue();
        }

        if (_initialDepositCap == 0) {
            revert InvalidValue();
        }

        if (_usdcTokenAddress == ZERO_ADDRESS) {
            revert InvalidValue();
        }

        if (_thirdPartyAddress == ZERO_ADDRESS) {
            revert InvalidValue();
        }

        USDC_TOKEN = IERC20(
            _usdcTokenAddress
        );

        thirdPartyAddress = _thirdPartyAddress;
        rewardCycle = _rewardCycle;
        interestRate = _interestRate;
        totalDepositCap = _initialDepositCap;
    }

    /**
     * @dev Deposits USDC into the contract.
     * The USDC is forwarded to a third party address.
     */
    function deposit(
        uint256 _amount
    )
        external
        nonReentrant
        whenNotPaused
    {
        if (_amount == 0) {
            revert InvalidValue();
        }

        if (depositsPaused == true) {
            revert DepositPaused();
        }

        if (totalDeposited + _amount > totalDepositCap) {
            revert DepositExceedCap();
        }

        totalDeposited = totalDeposited
            + _amount;

        uint256 positionId = nextPositionId++;

        positions[positionId] = DepositPosition({
            amount: _amount,
            lastClaimed: block.timestamp
        });

        _mint(
            msg.sender,
            positionId
        );

        USDC_TOKEN.safeTransferFrom(
            msg.sender,
            address(this),
            _amount
        );

        USDC_TOKEN.safeTransfer(
            thirdPartyAddress,
            _amount
        );

        emit Deposited(
            msg.sender,
            positionId,
            _amount,
            rewardCycle
        );

        emit FundsForwarded(
            thirdPartyAddress,
            _amount
        );
    }

    /**
     * @dev Returns the rewards for a position.
     */
    function getRewards(
        uint256 _positionId
    )
        public
        view
        returns (
            uint256 cycleCount,
            uint256 lastClaimed,
            uint256 totalRewards
        )
    {
        DepositPosition memory position = positions[
            _positionId
        ];

        lastClaimed = position.lastClaimed;

        uint256 elapsedTime = block.timestamp
            - lastClaimed;

        if (elapsedTime < rewardCycle) {
            return (
                0,
                lastClaimed,
                0
            );
        }

        uint256 interestPerCycle = position.amount
            * interestRate
            * rewardCycle
            / HOURS_IN_YEAR
            / PRECISION_RATE;

        cycleCount = elapsedTime
            / rewardCycle;

        totalRewards = cycleCount
            * interestPerCycle;
    }

    /**
     * @dev Claims the rewards for a position.
     */
    function claimRewards(
        uint256 _positionId
    )
        external
        nonReentrant
        whenNotPaused
    {
        require(
            ownerOf(_positionId) == msg.sender,
            "Not the owner of this position"
        );

        (
            uint256 cycleCount,
            uint256 lastClaimed,
            uint256 totalRewards
        ) = getRewards(
            _positionId
        );

        if (totalRewards == 0) {
            revert NoRewards();
        }

        positions[_positionId].lastClaimed = cycleCount
            * rewardCycle
            + lastClaimed;

        USDC_TOKEN.safeTransfer(
            msg.sender,
            totalRewards
        );

        emit RewardsClaimed(
            msg.sender,
            _positionId,
            totalRewards
        );
    }

    /**
     * @dev Sets the deposit cap.
     */
    function setDepositCap(
        uint256 _newDepositCap
    )
        external
        onlyMaster
    {
        if (_newDepositCap == 0) {
            revert InvalidValue();
        }

        totalDepositCap = _newDepositCap;
    }

    /**
     * @dev Pauses the deposits.
     */
    function pauseDeposits(
        bool _paused
    )
        external
        onlyWhitelisted
    {
        depositsPaused = _paused;
    }

    /**
     * @dev Pauses the contract.
     */
    function pause()
        external
        onlyWhitelisted
    {
        _pause();
    }

    /**
     * @dev Unpauses the contract.
     */
    function unpause()
        external
        onlyWhitelisted
    {
        _unpause();
    }

    /**
     * @dev Sets the third party address for the deposits.
     */
    function setDepositWallet(
        address _newThirdPartyAddress
    )
        external
        onlyMaster
    {
        if (_newThirdPartyAddress == ZERO_ADDRESS) {
            revert InvalidValue();
        }

        thirdPartyAddress = _newThirdPartyAddress;
    }

    /**
     * @dev Sets the reward cycle for the deposits.
     */
    function setRewardCycle(
        uint256 _newRewardCycle
    )
        external
        onlyMaster
    {
        if (_newRewardCycle == 0) {
            revert InvalidValue();
        }

        rewardCycle = _newRewardCycle;
    }

    /**
     * @dev Sets the interest rate for the deposits.
     */
    function setInterestRate(
        uint256 _newInterestRate
    )
        external
        onlyMaster
    {
        if (_newInterestRate == 0) {
            revert InvalidValue();
        }

        interestRate = _newInterestRate;
    }

    /**
     * @dev Whitelists an address.
     */
    function whitelistAddress(
        address _address
    )
        external
        onlyMaster
    {
        isWhitelisted[_address] = true;
    }

    /**
     * @dev Removes an address from the whitelist.
     */
    function removeWhitelistedAddress(
        address _address
    )
        external
        onlyMaster
    {
        isWhitelisted[_address] = false;
    }

    /**
     * @dev Checks if the contract supports an interface.
     */
    function supportsInterface(
        bytes4 _interfaceId
    )
        public
        view
        override(ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(
            _interfaceId
        );
    }

    /**
     * @dev Allows to update base target for MetaData.
     */
    function setBaseURI(
        string memory _newBaseURI
    )
        external
        onlyMaster
    {
        baseURI = _newBaseURI;
    }

    function setBaseExtension(
        string memory _newBaseExtension
    )
        external
        onlyMaster
    {
        baseExtension = _newBaseExtension;
    }

    /**
     * @dev Returns path to MetaData URI
     */
    function tokenURI(
        uint256 _tokenId
    )
        public
        view
        override
        returns (string memory)
    {
        if (_exists(_tokenId) == false) {
            revert InvalidPosition();
        }

        string memory currentBaseURI = baseURI;

        if (bytes(currentBaseURI).length == 0) {
            return "";
        }

        return string(
            abi.encodePacked(
                currentBaseURI,
                _toString(_tokenId),
                baseExtension
            )
        );
    }

    /**
     * @dev Converts tokenId uint to string.
     */
    function _toString(
        uint256 _tokenId
    )
        internal
        pure
        returns (string memory str)
    {
        if (_tokenId == 0) {
            return "0";
        }

        uint256 j = _tokenId;
        uint256 length;

        while (j != 0) {
            length++;
            j /= 10;
        }

        bytes memory bstr = new bytes(
            length
        );

        uint256 k = length;
        j = _tokenId;

        while (j != 0) {
            bstr[--k] = bytes1(
                uint8(
                    48 + (j % 10)
                )
            );
            j /= 10;
        }

        str = string(
            bstr
        );
    }
}