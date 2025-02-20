// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {HeyMintERC721AUpgradeable} from "./contracts_implementations_HeyMintERC721AUpgradeable.sol";
import {HeyMintStorage, BaseConfig, AdvancedConfig, BurnToken} from "./contracts_libraries_HeyMintStorage.sol";
import {IERC721} from "./openzeppelin_contracts_token_ERC721_IERC721.sol";
import {IERC1155} from "./openzeppelin_contracts_token_ERC1155_IERC1155.sol";
import {IDelegateRegistry} from "./contracts_interfaces_IDelegateRegistry.sol";

contract HeyMintERC721AExtensionE is HeyMintERC721AUpgradeable {
    using HeyMintStorage for HeyMintStorage.State;

    event HeyMintAffiliatePaid(address to, uint256 numTokens, uint256 value);

    // Address where burnt tokens are sent.
    address public constant burnAddress =
        0x000000000000000000000000000000000000dEaD;
    // Address of the HeyMint admin address
    address public constant heymintAdminAddress =
        0x52EA5F96f004d174470901Ba3F1984D349f0D3eF;
    // Address for delegation registry
    address public constant delegationRegistryAddress =
        0x00000000000000447e69651d841bD8D104Bed493;

    // ============ PUBLIC MINT ============

    /**
     * @notice Checks if the public sale affiliate minting is currently active.
     * @return A boolean indicating whether public sale affiliate minting is active.
     */
    function isPublicAffiliateMintActive() public view returns (bool) {
        HeyMintStorage.State storage state = HeyMintStorage.state();
        return (state.cfg.presaleSignerAddress != address(0) &&
            state.cfg.publicSaleAffiliateMintEnabled &&
            state.cfg.publicSaleActive &&
            state.cfg.publicPrice > 0 &&
            state.cfg.affiliateBasisPoints > 0 &&
            (!state.cfg.usePublicSaleTimes ||
                block.timestamp >= state.cfg.publicSaleStartTime) &&
            (!state.cfg.usePublicSaleTimes ||
                block.timestamp < state.cfg.publicSaleEndTime));
    }

    /**
     * @notice Returns if public sale times are active. If required config settings are not set, returns true.
     */
    function publicSaleTimeIsActive() public view returns (bool) {
        HeyMintStorage.State storage state = HeyMintStorage.state();
        if (
            state.cfg.usePublicSaleTimes == false ||
            state.cfg.publicSaleStartTime == 0 ||
            state.cfg.publicSaleEndTime == 0
        ) {
            return true;
        }
        return
            block.timestamp >= state.cfg.publicSaleStartTime &&
            block.timestamp <= state.cfg.publicSaleEndTime;
    }

    /**
     * @notice Allow for public minting of tokens
     * @param _numTokens The number of tokens to mint
     */
    function _publicMint(uint256 _numTokens) internal {
        BaseConfig storage cfg = HeyMintStorage.state().cfg;
        require(cfg.publicSaleActive, "NOT_ACTIVE");
        require(publicSaleTimeIsActive(), "NOT_ACTIVE");
        require(
            cfg.publicMintsAllowedPerAddress == 0 ||
                _numberMinted(msg.sender) + _numTokens <=
                cfg.publicMintsAllowedPerAddress,
            "MAX_MINTS_EXCEEDED"
        );
        require(
            cfg.publicMintsAllowedPerTransaction == 0 ||
                _numTokens <= cfg.publicMintsAllowedPerTransaction,
            "MAX_MINTS_EXCEEDED"
        );
        require(
            totalSupply() + _numTokens <= cfg.maxSupply,
            "MAX_SUPPLY_EXCEEDED"
        );
        uint256 publicPrice = publicPriceInWei();
        if (cfg.heyMintFeeActive) {
            uint256 heymintFee = _numTokens * heymintFeePerToken();
            require(
                msg.value == publicPrice * _numTokens + heymintFee,
                "INVALID_PRICE_PAID"
            );
            (bool success, ) = heymintPayoutAddress.call{value: heymintFee}("");
            require(success, "TRANSFER_FAILED");
        } else {
            require(
                msg.value == publicPrice * _numTokens,
                "INVALID_PRICE_PAID"
            );
        }

        if (cfg.fundingEndsAt > 0) {
            uint256 firstTokenIdToMint = _nextTokenId();
            for (uint256 i = 0; i < _numTokens; i++) {
                HeyMintStorage.state().data.pricePaid[
                    firstTokenIdToMint + i
                ] = publicPrice;
            }
        }

        _safeMint(msg.sender, _numTokens);

        if (totalSupply() >= cfg.maxSupply) {
            cfg.publicSaleActive = false;
        }
    }

    /**
     * @notice Allow for public minting of tokens
     * @param _numTokens The number of tokens to mint
     */
    function publicMint(uint256 _numTokens) external payable nonReentrant {
        _publicMint(_numTokens);
    }

    /**
     * @notice Allow for public minting of tokens with affiliate payment
     * @param _affPaymentAddress The address to receive affiliate fees
     * @param _affMessageHash The hash of the affiliate message containing the affiliate payment address & projectId
     * @param _affSignature The signature for the affiliate payment message to verify
     * @param _numTokens The number of tokens to mint
     */
    function affiliatePublicMint(
        address _affPaymentAddress,
        bytes32 _affMessageHash,
        bytes calldata _affSignature,
        uint256 _numTokens
    ) external payable nonReentrant {
        require(isPublicAffiliateMintActive(), "NOT_ACTIVE");
        HeyMintStorage.State storage state = HeyMintStorage.state();
        require(
            keccak256(abi.encode(state.cfg.projectId, _affPaymentAddress)) ==
                _affMessageHash,
            "MESSAGE_INVALID"
        );
        require(
            verifySignerAddress(_affMessageHash, _affSignature),
            "INVALID_SIGNATURE"
        );
        _publicMint(_numTokens);
        uint256 affFee = (_numTokens *
            publicPriceInWei() *
            state.cfg.affiliateBasisPoints) / 10000;
        (bool ok, ) = _affPaymentAddress.call{value: affFee}("");
        require(ok, "TRANSFER_FAILED");
        emit HeyMintAffiliatePaid(_affPaymentAddress, _numTokens, affFee);
    }

    // ============ GIFT ============

    /**
     * @notice Allow owner to send 'mintNumber' tokens without cost to multiple addresses
     * @param _receivers The addresses to send the tokens to
     * @param _mintNumber The number of tokens to send to each address
     */
    function gift(
        address[] calldata _receivers,
        uint256[] calldata _mintNumber
    ) external payable onlyOwner {
        HeyMintStorage.State storage state = HeyMintStorage.state();
        require(
            _receivers.length == _mintNumber.length,
            "ARRAY_LENGTHS_MUST_MATCH"
        );
        uint256 totalMints = 0;
        for (uint256 i = 0; i < _mintNumber.length; i++) {
            totalMints += _mintNumber[i];
        }
        require(
            totalSupply() + totalMints <= state.cfg.maxSupply,
            "MAX_SUPPLY_EXCEEDED"
        );
        if (state.cfg.heyMintFeeActive) {
            uint256 heymintFee = (totalMints * heymintFeePerToken()) / 10;
            require(msg.value == heymintFee, "PAYMENT_INCORRECT");
            (bool success, ) = heymintPayoutAddress.call{value: heymintFee}("");
            require(success, "TRANSFER_FAILED");
        }
        for (uint256 i = 0; i < _receivers.length; i++) {
            _safeMint(_receivers[i], _mintNumber[i]);
        }
    }

    // ============ BURN TO MINT ============

    /**
     * @notice Returns the burn payment in wei. Price is stored with 5 decimals (1 = 0.00001 ETH), so total 5 + 13 == 18 decimals
     */
    function burnPaymentInWei() public view returns (uint256) {
        return uint256(HeyMintStorage.state().advCfg.burnPayment) * 10 ** 13;
    }

    /**
     * @notice To be updated by contract owner to allow burning to claim a token
     * @param _burnClaimActive If true tokens can be burned in order to mint
     */
    function setBurnClaimState(bool _burnClaimActive) external onlyOwner {
        HeyMintStorage.State storage state = HeyMintStorage.state();
        if (_burnClaimActive) {
            require(state.burnTokens.length != 0, "NOT_CONFIGURED");
            require(state.advCfg.mintsPerBurn != 0, "NOT_CONFIGURED");
        }
        state.advCfg.burnClaimActive = _burnClaimActive;
    }

    /**
     * @notice Set the contract address of the NFT to be burned in order to mint
     * @param _burnTokens An array of all tokens required for burning
     */
    function updateBurnTokens(
        BurnToken[] calldata _burnTokens
    ) external onlyOwner {
        BurnToken[] storage burnTokens = HeyMintStorage.state().burnTokens;
        uint256 oldBurnTokensLength = burnTokens.length;
        uint256 newBurnTokensLength = _burnTokens.length;

        // Update the existing BurnTokens and push any new BurnTokens
        for (uint256 i = 0; i < newBurnTokensLength; i++) {
            if (i < oldBurnTokensLength) {
                burnTokens[i] = _burnTokens[i];
            } else {
                burnTokens.push(_burnTokens[i]);
            }
        }

        // Pop any extra BurnTokens if the new array is shorter
        for (uint256 i = oldBurnTokensLength; i > newBurnTokensLength; i--) {
            burnTokens.pop();
        }
    }

    /**
     * @notice Update the number of free mints claimable per token burned
     * @param _mintsPerBurn The new number of tokens that can be minted per burn transaction
     */
    function updateMintsPerBurn(uint8 _mintsPerBurn) external onlyOwner {
        HeyMintStorage.state().advCfg.mintsPerBurn = _mintsPerBurn;
    }

    /**
     * @notice Update the price required to be paid alongside a burn tx to mint (payment is per tx, not per token in the case of >1 mintsPerBurn)
     * @param _burnPayment The new amount of payment required per burn transaction
     */
    function updatePaymentPerBurn(uint32 _burnPayment) external onlyOwner {
        HeyMintStorage.state().advCfg.burnPayment = _burnPayment;
    }

    /**
     * @notice If true, real token ids are used for metadata. If false, burn token ids are used for metadata if they exist.
     * @param _useBurnTokenIdForMetadata If true, burn token ids are used for metadata if they exist. If false, real token ids are used.
     */
    function setUseBurnTokenIdForMetadata(
        bool _useBurnTokenIdForMetadata
    ) external onlyOwner {
        HeyMintStorage
            .state()
            .advCfg
            .useBurnTokenIdForMetadata = _useBurnTokenIdForMetadata;
    }

    /**
     * @notice Burn tokens from other contracts in order to mint tokens on this contract
     * @dev This contract must be approved by the caller to transfer the tokens being burned
     * @param _contracts The contracts of the tokens to burn in the same order as the array burnTokens
     * @param _tokenIds Nested array of token ids to burn for 721 and amounts to burn for 1155 corresponding to _contracts
     * @param _tokensToMint The number of tokens to mint
     * @param _vault The address of the cold wallet (or zero address if not using delegation)
     */
    function _burnToMint(
        address[] calldata _contracts,
        uint256[][] calldata _tokenIds,
        uint256 _tokensToMint,
        address _vault
    ) internal {
        HeyMintStorage.State storage state = HeyMintStorage.state();
        IDelegateRegistry delegateContract = IDelegateRegistry(
            delegationRegistryAddress
        );
        require(state.burnTokens.length > 0, "NOT_CONFIGURED");
        require(state.advCfg.mintsPerBurn != 0, "NOT_CONFIGURED");
        require(state.advCfg.burnClaimActive, "NOT_ACTIVE");
        require(
            _contracts.length == _tokenIds.length,
            "ARRAY_LENGTHS_MUST_MATCH"
        );
        require(
            _contracts.length == state.burnTokens.length,
            "ARRAY_LENGTHS_MUST_MATCH"
        );
        require(
            totalSupply() + _tokensToMint <= state.cfg.maxSupply,
            "MAX_SUPPLY_EXCEEDED"
        );
        address mintWallet = _vault == address(0) ? msg.sender : _vault;

        uint256 burnPaymentTotal = burnPaymentInWei() *
            (_tokensToMint / state.advCfg.mintsPerBurn);
        if (state.cfg.heyMintFeeActive) {
            uint256 heymintFee = _tokensToMint * heymintFeePerToken();
            require(
                msg.value == burnPaymentTotal + heymintFee,
                "INVALID_PRICE_PAID"
            );
            (bool success, ) = heymintPayoutAddress.call{value: heymintFee}("");
            require(success, "TRANSFER_FAILED");
        } else {
            require(msg.value == burnPaymentTotal, "INVALID_PRICE_PAID");
        }

        for (uint256 i = 0; i < state.burnTokens.length; i++) {
            BurnToken memory burnToken = state.burnTokens[i];
            require(
                burnToken.contractAddress == _contracts[i],
                "INCORRECT_CONTRACT"
            );
            require(
                _vault == address(0) ||
                    delegateContract.checkDelegateForContract(
                        msg.sender,
                        _vault,
                        _contracts[i],
                        ""
                    )
            );
            if (burnToken.tokenType == 1) {
                uint256 _tokenIdsLength = _tokenIds[i].length;
                require(
                    (_tokenIdsLength / burnToken.tokensPerBurn) *
                        state.advCfg.mintsPerBurn ==
                        _tokensToMint,
                    "INCORRECT_NO_OF_TOKENS_TO_BURN"
                );
                for (uint256 j = 0; j < _tokenIdsLength; j++) {
                    IERC721 burnContract = IERC721(_contracts[i]);
                    uint256 tokenId = _tokenIds[i][j];
                    require(
                        burnContract.ownerOf(tokenId) == mintWallet,
                        "MUST_OWN_TOKEN"
                    );
                    burnContract.transferFrom(mintWallet, burnAddress, tokenId);
                }
            } else if (burnToken.tokenType == 2) {
                uint256 amountToBurn = _tokenIds[i][0];
                require(
                    (amountToBurn / burnToken.tokensPerBurn) *
                        state.advCfg.mintsPerBurn ==
                        _tokensToMint,
                    "INCORRECT_NO_OF_TOKENS_TO_BURN"
                );
                IERC1155 burnContract = IERC1155(_contracts[i]);
                require(
                    burnContract.balanceOf(mintWallet, burnToken.tokenId) >=
                        amountToBurn,
                    "MUST_OWN_TOKEN"
                );
                burnContract.safeTransferFrom(
                    mintWallet,
                    burnAddress,
                    burnToken.tokenId,
                    amountToBurn,
                    ""
                );
            }
        }
        if (state.advCfg.useBurnTokenIdForMetadata) {
            require(
                _tokenIds[0].length == _tokensToMint,
                "BURN_TOKENS_MUST_MATCH_MINT_NO"
            );
            uint256 firstNewTokenId = _nextTokenId();
            for (uint256 i = 0; i < _tokensToMint; i++) {
                state.data.tokenIdToBurnTokenId[
                    firstNewTokenId + i
                ] = _tokenIds[0][i];
            }
        }
        _safeMint(mintWallet, _tokensToMint);
    }

    /**
     * @notice Burn tokens from other contracts in order to mint tokens on this contract
     * @dev This contract must be approved by the caller to transfer the tokens being burned
     * @param _contracts The contracts of the tokens to burn in the same order as the array burnTokens
     * @param _tokenIds Nested array of token ids to burn for 721 and amounts to burn for 1155 corresponding to _contracts
     * @param _tokensToMint The number of tokens to mint
     */
    function burnToMint(
        address[] calldata _contracts,
        uint256[][] calldata _tokenIds,
        uint256 _tokensToMint
    ) external payable nonReentrant {
        _burnToMint(_contracts, _tokenIds, _tokensToMint, address(0));
    }

    /**
     * @notice Burn tokens from other contracts in order to mint tokens on this contract using delegation
     * @dev This contract must be approved by the caller to transfer the tokens being burned
     * @param _contracts The contracts of the tokens to burn in the same order as the array burnTokens
     * @param _tokenIds Nested array of token ids to burn for 721 and amounts to burn for 1155 corresponding to _contracts
     * @param _tokensToMint The number of tokens to mint
     * @param _vault The address of the cold wallet
     */
    function burnToMintDelegated(
        address[] calldata _contracts,
        uint256[][] calldata _tokenIds,
        uint256 _tokensToMint,
        address _vault
    ) external payable nonReentrant {
        _burnToMint(_contracts, _tokenIds, _tokensToMint, _vault);
    }

    // ============ ERC-2981 ROYALTY ============

    /**
     * @notice Updates royalty basis points
     * @param _royaltyBps The new royalty basis points to use
     */
    function setRoyaltyBasisPoints(uint16 _royaltyBps) external onlyOwner {
        HeyMintStorage.state().cfg.royaltyBps = _royaltyBps;
    }

    /**
     * @notice Updates royalty payout address
     * @param _royaltyPayoutAddress The new royalty payout address to use
     */
    function setRoyaltyPayoutAddress(
        address _royaltyPayoutAddress
    ) external onlyOwner {
        HeyMintStorage
            .state()
            .advCfg
            .royaltyPayoutAddress = _royaltyPayoutAddress;
    }

    // ============ PAYOUT ============

    /**
     * @notice Freeze all payout addresses so they can never be changed again
     */
    function freezePayoutAddresses() external onlyOwner {
        HeyMintStorage.state().advCfg.payoutAddressesFrozen = true;
    }

    /**
     * @notice Update payout addresses and basis points for each addresses' respective share of contract funds
     * @param _payoutAddresses The new payout addresses to use
     * @param _payoutBasisPoints The amount to pay out to each address in _payoutAddresses (in basis points)
     */
    function updatePayoutAddressesAndBasisPoints(
        address[] calldata _payoutAddresses,
        uint16[] calldata _payoutBasisPoints
    ) external onlyOwner {
        AdvancedConfig storage advCfg = HeyMintStorage.state().advCfg;
        uint256 payoutBasisPointsLength = _payoutBasisPoints.length;
        require(
            !advCfg.payoutAddressesFrozen,
            "CANNOT_UPDATE_CONSTANT_VARIABLE"
        );
        require(
            _payoutAddresses.length == payoutBasisPointsLength,
            "ARRAY_LENGTHS_MUST_MATCH"
        );
        uint256 totalBasisPoints = 0;
        for (uint256 i = 0; i < payoutBasisPointsLength; i++) {
            totalBasisPoints += _payoutBasisPoints[i];
        }
        require(totalBasisPoints == 10000, "BASIS_POINTS_MUST_EQUAL_10000");
        advCfg.payoutAddresses = _payoutAddresses;
        advCfg.payoutBasisPoints = _payoutBasisPoints;
    }
}