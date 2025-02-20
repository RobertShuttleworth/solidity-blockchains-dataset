// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {HeyMintERC721AUpgradeable} from "./contracts_implementations_HeyMintERC721AUpgradeable.sol";
import {BaseConfig, AdvancedConfig, BurnToken, HeyMintStorage} from "./contracts_libraries_HeyMintStorage.sol";

contract HeyMintERC721AExtensionA is HeyMintERC721AUpgradeable {
    using HeyMintStorage for HeyMintStorage.State;

    event Stake(uint256 indexed tokenId);
    event Unstake(uint256 indexed tokenId);
    event Loan(address from, address to, uint256 tokenId);
    event LoanRetrieved(address from, address to, uint256 tokenId);

    // ============ BASE FUNCTIONALITY ============

    /**
     * @notice Returns all storage variables for the contract
     */
    function getSettings()
        external
        view
        returns (
            BaseConfig memory,
            AdvancedConfig memory,
            BurnToken[] memory,
            bool,
            bool,
            bool,
            uint256
        )
    {
        HeyMintStorage.State storage state = HeyMintStorage.state();
        return (
            state.cfg,
            state.advCfg,
            state.burnTokens,
            state.data.advancedConfigInitialized,
            state.data.fundingTargetReached,
            state.data.fundingSuccessDetermined,
            state.data.currentLoanTotal
        );
    }

    /**
     * @notice Updates the address configuration for the contract
     */
    function updateBaseConfig(
        BaseConfig memory _baseConfig
    ) external onlyOwner {
        HeyMintStorage.State storage state = HeyMintStorage.state();
        require(
            _baseConfig.projectId == state.cfg.projectId,
            "CANNOT_UPDATE_CONSTANT_VARIABLE"
        );
        require(
            _baseConfig.maxSupply <= state.cfg.maxSupply,
            "CANNOT_UPDATE_CONSTANT_VARIABLE"
        );
        require(
            _baseConfig.presaleMaxSupply <= state.cfg.presaleMaxSupply,
            "CANNOT_UPDATE_CONSTANT_VARIABLE"
        );
        require(
            _baseConfig.fundingEndsAt == state.cfg.fundingEndsAt,
            "CANNOT_UPDATE_CONSTANT_VARIABLE"
        );
        require(
            _baseConfig.fundingTarget == state.cfg.fundingTarget,
            "CANNOT_UPDATE_CONSTANT_VARIABLE"
        );
        require(
            _baseConfig.heyMintFeeActive == state.cfg.heyMintFeeActive,
            "CANNOT_UPDATE_CONSTANT_VARIABLE"
        );
        require(
            _baseConfig.affiliateBasisPoints == state.cfg.affiliateBasisPoints,
            "CANNOT_UPDATE_CONSTANT_VARIABLE"
        );
        require(
            _baseConfig.presaleAffiliateMintEnabled ==
                state.cfg.presaleAffiliateMintEnabled,
            "CANNOT_UPDATE_CONSTANT_VARIABLE"
        );
        require(
            _baseConfig.publicSaleAffiliateMintEnabled ==
                state.cfg.publicSaleAffiliateMintEnabled,
            "CANNOT_UPDATE_CONSTANT_VARIABLE"
        );
        if (state.advCfg.metadataFrozen) {
            require(
                keccak256(abi.encode(_baseConfig.uriBase)) ==
                    keccak256(abi.encode(state.cfg.uriBase)),
                "CANNOT_UPDATE_CONSTANT_VARIABLE"
            );
        }
        state.cfg = _baseConfig;
    }

    /**
     * @notice Updates the advanced configuration for the contract
     */
    function updateAdvancedConfig(
        AdvancedConfig memory _advancedConfig
    ) external onlyOwner {
        HeyMintStorage.State storage state = HeyMintStorage.state();
        if (state.advCfg.metadataFrozen) {
            require(
                _advancedConfig.metadataFrozen,
                "CANNOT_UPDATE_CONSTANT_VARIABLE"
            );
        }
        if (state.advCfg.soulbindAdminTransfersPermanentlyDisabled) {
            require(
                _advancedConfig.soulbindAdminTransfersPermanentlyDisabled,
                "CANNOT_UPDATE_CONSTANT_VARIABLE"
            );
        }
        if (state.advCfg.refundEndsAt > 0) {
            require(
                _advancedConfig.refundPrice == state.advCfg.refundPrice,
                "CANNOT_UPDATE_CONSTANT_VARIABLE"
            );
            require(
                _advancedConfig.refundEndsAt >= state.advCfg.refundEndsAt,
                "CANNOT_UPDATE_CONSTANT_VARIABLE"
            );
        } else if (
            _advancedConfig.refundEndsAt > 0 || _advancedConfig.refundPrice > 0
        ) {
            require(
                _advancedConfig.refundPrice > 0,
                "REFUND_PRICE_MUST_BE_SET"
            );
            require(
                _advancedConfig.refundEndsAt > 0,
                "REFUND_DURATION_MUST_BE_SET"
            );
        }
        if (!state.data.advancedConfigInitialized) {
            state.data.advancedConfigInitialized = true;
        }
        uint256 payoutAddressesLength = _advancedConfig.payoutAddresses.length;
        uint256 payoutBasisPointsLength = _advancedConfig
            .payoutBasisPoints
            .length;
        if (state.advCfg.payoutAddressesFrozen) {
            require(
                _advancedConfig.payoutAddressesFrozen,
                "CANNOT_UPDATE_CONSTANT_VARIABLE"
            );
            require(
                payoutAddressesLength == state.advCfg.payoutAddresses.length,
                "CANNOT_UPDATE_CONSTANT_VARIABLE"
            );
            require(
                payoutBasisPointsLength ==
                    state.advCfg.payoutBasisPoints.length,
                "CANNOT_UPDATE_CONSTANT_VARIABLE"
            );
            for (uint256 i = 0; i < payoutAddressesLength; i++) {
                require(
                    _advancedConfig.payoutAddresses[i] ==
                        state.advCfg.payoutAddresses[i],
                    "CANNOT_UPDATE_CONSTANT_VARIABLE"
                );
                require(
                    _advancedConfig.payoutBasisPoints[i] ==
                        state.advCfg.payoutBasisPoints[i],
                    "CANNOT_UPDATE_CONSTANT_VARIABLE"
                );
            }
        } else if (payoutAddressesLength > 0) {
            require(
                payoutAddressesLength == payoutBasisPointsLength,
                "ARRAY_LENGTHS_MUST_MATCH"
            );
            uint256 totalBasisPoints = 0;
            for (uint256 i = 0; i < payoutBasisPointsLength; i++) {
                totalBasisPoints += _advancedConfig.payoutBasisPoints[i];
            }
            require(totalBasisPoints == 10000, "BASIS_POINTS_MUST_EQUAL_10000");
        }
        require(
            (state.advCfg.subscriptionPeriod == 0 ||
                _advancedConfig.subscriptionPeriod ==
                state.advCfg.subscriptionPeriod),
            "CANNOT_UPDATE_CONSTANT_VARIABLE"
        );
        require(
            (state.advCfg.subscriptionPrice == 0 ||
                _advancedConfig.subscriptionPrice ==
                state.advCfg.subscriptionPrice),
            "CANNOT_UPDATE_CONSTANT_VARIABLE"
        );
        require(
            state.advCfg.subscriptionErc20Address == address(0) ||
                _advancedConfig.subscriptionErc20Address ==
                state.advCfg.subscriptionErc20Address,
            "CANNOT_UPDATE_CONSTANT_VARIABLE"
        );
        state.advCfg = _advancedConfig;
    }
}