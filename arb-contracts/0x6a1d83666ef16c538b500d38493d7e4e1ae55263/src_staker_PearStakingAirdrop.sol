// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { IPearStaker } from "./src_interfaces_IPearStaker.sol";
import { IERC20 } from "./lib_openzeppelin-contracts_contracts_token_ERC20_IERC20.sol";
import { IERC721 } from "./lib_openzeppelin-contracts_contracts_token_ERC721_IERC721.sol";
import { Errors } from "./src_libraries_Errors.sol";
import { Events } from "./src_libraries_Events.sol";
import { ComptrollerManager } from "./src_helpers_ComptrollerManager.sol";
import { Initializable } from "./lib_openzeppelin-contracts-upgradeable_contracts_proxy_utils_Initializable.sol";
import { ISwapRouter } from "./src_interfaces_ISwapRouter.sol";

/// @title PearStakingAirdrop
/// @notice Contract for staking PEAR tokens and earning rewards.
contract PearStakingAirdrop is ComptrollerManager, Initializable {
    struct Tier {
        address tierNFTContract;
        uint256 perNFTAllocation;
    }

    IPearStaker public stPearToken;
    IERC20 public pearToken;

    address public vault;

    address public goldNFT;
    address public silverNFT;
    address public bronzeNFT;

    uint256 public goldAllocationPerNFT;
    uint256 public silverAllocationPerNFT;
    uint256 public bronzeAllocationPerNFT;

    mapping(address => bool) public hasClaimed;

    event AirdropClaimed(address indexed user, uint256 amount);
    event AirdropWithdrawn(address indexed admin);

    /// @notice Modifier to restrict access to only the contract owner.
    modifier onlyAdmin() {
        if (comptroller.admin() != msg.sender) {
            revert Errors.Airdrop_NotComptrollerAdmin();
        }
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _comptroller,
        address _stPearToken,
        address _pearToken,
        address _pearTokenValut,
        Tier memory _goldTier,
        Tier memory _silverTier,
        Tier memory _bronzeTier
    )
        external
        initializer
    {
        _comptrollerInit(_comptroller);
        stPearToken = IPearStaker(_stPearToken);
        pearToken = IERC20(_pearToken);
        vault = _pearTokenValut;
        goldNFT = _goldTier.tierNFTContract;
        silverNFT = _silverTier.tierNFTContract;
        bronzeNFT = _bronzeTier.tierNFTContract;

        goldAllocationPerNFT = _goldTier.perNFTAllocation;
        silverAllocationPerNFT = _silverTier.perNFTAllocation;
        bronzeAllocationPerNFT = _bronzeTier.perNFTAllocation;
    }

    /**
     * @dev Checks user's eligibility for airdrop
     * @param _user Address to check
     * @return Eligible amount of tokens
     */
    function checkEligibility(address _user) public view returns (uint256) {
        uint256 totalEligibleAmount = 0;

        if (IERC721(goldNFT).balanceOf(_user) > 0) {
            totalEligibleAmount +=
                goldAllocationPerNFT * IERC721(goldNFT).balanceOf(_user);
        }

        if (IERC721(silverNFT).balanceOf(_user) > 0) {
            totalEligibleAmount +=
                silverAllocationPerNFT * IERC721(silverNFT).balanceOf(_user);
        }

        if (IERC721(bronzeNFT).balanceOf(_user) > 0) {
            totalEligibleAmount +=
                bronzeAllocationPerNFT * IERC721(bronzeNFT).balanceOf(_user);
        }

        return totalEligibleAmount;
    }

    /**
     * @dev Claim tokens, mint stPEAR, and stake
     */
    function claim() external {
        if (hasClaimed[msg.sender]) {
            revert Errors.Airdrop_ALREADY_CLAIMED();
        }
        uint256 userAllocation = checkEligibility(msg.sender);
        if (userAllocation == 0) {
            revert Errors.Airdrop_NOT_ELIGIBLE();
        }
        hasClaimed[msg.sender] = true;

        // transfer PEAR tokens to this contract
        pearToken.transferFrom(vault, address(this), userAllocation);
        pearToken.approve(address(stPearToken), userAllocation);
        stPearToken.stakeFor(msg.sender, userAllocation);
        emit AirdropClaimed(msg.sender, userAllocation);
    }
}