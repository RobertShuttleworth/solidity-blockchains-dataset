// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {HeyMintERC721AUpgradeable} from "./contracts_implementations_HeyMintERC721AUpgradeable.sol";
import {AdvancedConfig, Data, BaseConfig, HeyMintStorage} from "./contracts_libraries_HeyMintStorage.sol";
import {IERC721} from "./openzeppelin_contracts_token_ERC721_IERC721.sol";

contract HeyMintERC721AExtensionC is HeyMintERC721AUpgradeable {
    using HeyMintStorage for HeyMintStorage.State;

    event Stake(uint256 indexed tokenId);
    event Unstake(uint256 indexed tokenId);
    event HeyMintAffiliatePaid(address to, uint256 numTokens, uint256 value);

    // ============ BASE FUNCTIONALITY ============

    /**
     * @notice Update the specific token URI for a set of tokens
     * @param _tokenIds The token IDs to update
     * @param _newURIs The new URIs to use
     */
    function setTokenURIs(
        uint256[] calldata _tokenIds,
        string[] calldata _newURIs
    ) external onlyOwner {
        require(!HeyMintStorage.state().advCfg.metadataFrozen, "NOT_ACTIVE");
        uint256 tokenIdsLength = _tokenIds.length;
        require(tokenIdsLength == _newURIs.length);
        for (uint256 i = 0; i < tokenIdsLength; i++) {
            HeyMintStorage.state().data.tokenURIs[_tokenIds[i]] = _newURIs[i];
        }
    }

    function baseTokenURI() external view returns (string memory) {
        return HeyMintStorage.state().cfg.uriBase;
    }

    // ============ CREDIT CARD PAYMENT ============

    /**
     * @notice Returns if public sale times are active. If required config settings are not set, returns true.
     */
    function _publicSaleTimeIsActive() internal view returns (bool) {
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
     * @notice Set an address authorized to call creditCardMint
     * @param _creditCardMintAddresses The new address to authorize
     */
    function setCreditCardMintAddresses(
        address[] memory _creditCardMintAddresses
    ) external onlyOwner {
        HeyMintStorage
            .state()
            .advCfg
            .creditCardMintAddresses = _creditCardMintAddresses;
    }

    function _creditCardMint(uint256 _numTokens, address _to) internal {
        HeyMintStorage.State storage state = HeyMintStorage.state();
        require(
            isSenderAuthorizedForCreditCardMint(),
            "NOT_AUTHORIZED_ADDRESS"
        );
        require(state.cfg.publicSaleActive, "NOT_ACTIVE");
        require(_publicSaleTimeIsActive(), "NOT_ACTIVE");
        require(
            state.cfg.publicMintsAllowedPerAddress == 0 ||
                _numberMinted(_to) + _numTokens <=
                state.cfg.publicMintsAllowedPerAddress,
            "MAX_MINTS_EXCEEDED"
        );
        require(
            state.cfg.publicMintsAllowedPerTransaction == 0 ||
                _numTokens <= state.cfg.publicMintsAllowedPerTransaction,
            "MAX_MINTS_EXCEEDED"
        );
        require(
            totalSupply() + _numTokens <= state.cfg.maxSupply,
            "MAX_SUPPLY_EXCEEDED"
        );
        uint256 publicPrice = publicPriceInWei();
        if (state.cfg.heyMintFeeActive) {
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

        if (state.cfg.fundingEndsAt > 0) {
            uint256 firstTokenIdToMint = _nextTokenId();
            for (uint256 i = 0; i < _numTokens; i++) {
                HeyMintStorage.state().data.pricePaid[
                    firstTokenIdToMint + i
                ] = publicPrice;
            }
        }

        _safeMint(_to, _numTokens);

        if (totalSupply() >= state.cfg.maxSupply) {
            state.cfg.publicSaleActive = false;
        }
    }

    function creditCardMint(
        uint256 _numTokens,
        address _to
    ) external payable nonReentrant {
        _creditCardMint(_numTokens, _to);
    }

    /**
     * @notice Allow for public minting of tokens via credit card with affiliate payment
     * @param _affPaymentAddress The address to receive affiliate fees
     * @param _affMessageHash The hash of the affiliate message containing the affiliate payment address & projectId
     * @param _affSignature The signature for the affiliate payment message to verify
     * @param _numTokens The number of tokens to mint
     * @param _to The address to mint tokens to
     */
    function affiliateCreditCardMint(
        address _affPaymentAddress,
        bytes32 _affMessageHash,
        bytes calldata _affSignature,
        uint256 _numTokens,
        address _to
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
        _creditCardMint(_numTokens, _to);
        uint256 affFee = (_numTokens *
            publicPriceInWei() *
            state.cfg.affiliateBasisPoints) / 10000;
        (bool ok, ) = _affPaymentAddress.call{value: affFee}("");
        require(ok, "TRANSFER_FAILED");
        emit HeyMintAffiliatePaid(_affPaymentAddress, _numTokens, affFee);
    }

    // ============ SOULBINDING ============

    /**
     * @notice Change the admin address used to transfer tokens if needed.
     * @param _adminAddress The new soulbound admin address
     */
    function setSoulboundAdminAddress(
        address _adminAddress
    ) external onlyOwner {
        AdvancedConfig storage advCfg = HeyMintStorage.state().advCfg;
        require(!advCfg.soulbindAdminTransfersPermanentlyDisabled);
        advCfg.soulboundAdminAddress = _adminAddress;
    }

    /**
     * @notice Disallow admin transfers of soulbound tokens permanently.
     */
    function disableSoulbindAdminTransfersPermanently() external onlyOwner {
        AdvancedConfig storage advCfg = HeyMintStorage.state().advCfg;
        advCfg.soulboundAdminAddress = address(0);
        advCfg.soulbindAdminTransfersPermanentlyDisabled = true;
    }

    /**
     * @notice Turn soulbinding on or off
     * @param _soulbindingActive If true soulbinding is active
     */
    function setSoulbindingState(bool _soulbindingActive) external onlyOwner {
        HeyMintStorage.state().cfg.soulbindingActive = _soulbindingActive;
    }

    /**
     * @notice Allows an admin address to initiate token transfers if user wallets get hacked or lost
     * This function can only be used on soulbound tokens to prevent arbitrary transfers of normal tokens
     * @param _from The address to transfer from
     * @param _to The address to transfer to
     * @param _tokenId The token id to transfer
     */
    function soulboundAdminTransfer(
        address _from,
        address _to,
        uint256 _tokenId
    ) external {
        HeyMintStorage.State storage state = HeyMintStorage.state();
        address adminAddress = state.advCfg.soulboundAdminAddress == address(0)
            ? owner()
            : state.advCfg.soulboundAdminAddress;
        require(msg.sender == adminAddress, "NOT_ADMIN");
        require(state.cfg.soulbindingActive, "NOT_ACTIVE");
        require(
            !state.advCfg.soulbindAdminTransfersPermanentlyDisabled,
            "NOT_ACTIVE"
        );
        state.data.soulboundAdminTransferInProgress = true;
        _directApproveMsgSenderFor(_tokenId);
        safeTransferFrom(_from, _to, _tokenId);
        state.data.soulboundAdminTransferInProgress = false;
    }

    // ============ STAKING ============

    /**
     * @notice Turn staking on or off
     * @param _stakingState The new state of staking (true = on, false = off)
     */
    function setStakingState(bool _stakingState) external onlyOwner {
        HeyMintStorage.state().advCfg.stakingActive = _stakingState;
    }

    /**
     * @notice Stake an arbitrary number of tokens
     * @param _tokenIds The ids of the tokens to stake
     */
    function stakeTokens(uint256[] calldata _tokenIds) external {
        HeyMintStorage.State storage state = HeyMintStorage.state();
        require(state.advCfg.stakingActive, "NOT_ACTIVE");
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            uint256 tokenId = _tokenIds[i];
            require(ownerOf(tokenId) == msg.sender, "MUST_OWN_TOKEN");
            if (state.data.currentTimeStaked[tokenId] == 0) {
                state.data.currentTimeStaked[tokenId] = block.timestamp;
                emit Stake(tokenId);
            }
        }
    }

    /**
     * @notice Unstake an arbitrary number of tokens
     * @param _tokenIds The ids of the tokens to unstake
     */
    function unstakeTokens(uint256[] calldata _tokenIds) external {
        Data storage data = HeyMintStorage.state().data;
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            uint256 tokenId = _tokenIds[i];
            require(ownerOf(tokenId) == msg.sender, "MUST_OWN_TOKEN");
            if (data.currentTimeStaked[tokenId] != 0) {
                data.totalTimeStaked[tokenId] +=
                    block.timestamp -
                    data.currentTimeStaked[tokenId];
                data.currentTimeStaked[tokenId] = 0;
                emit Unstake(tokenId);
            }
        }
    }

    /**
     * @notice Allows for transfers (not sales) while staking
     * @param _from The address of the current owner of the token
     * @param _to The address of the new owner of the token
     * @param _tokenId The id of the token to transfer
     */
    function stakingTransfer(
        address _from,
        address _to,
        uint256 _tokenId
    ) external {
        Data storage data = HeyMintStorage.state().data;
        require(ownerOf(_tokenId) == msg.sender, "MUST_OWN_TOKEN");
        data.stakingTransferActive = true;
        safeTransferFrom(_from, _to, _tokenId);
        data.stakingTransferActive = false;
    }

    /**
     * @notice Allow contract owner to forcibly unstake a token if needed
     * @param _tokenId The id of the token to unstake
     */
    function adminUnstake(uint256 _tokenId) external onlyOwner {
        Data storage data = HeyMintStorage.state().data;
        require(HeyMintStorage.state().data.currentTimeStaked[_tokenId] != 0);
        data.totalTimeStaked[_tokenId] +=
            block.timestamp -
            data.currentTimeStaked[_tokenId];
        data.currentTimeStaked[_tokenId] = 0;
        emit Unstake(_tokenId);
    }

    /**
     * @notice Return the total amount of time a token has been staked
     * @param _tokenId The id of the token to check
     */
    function totalTokenStakeTime(
        uint256 _tokenId
    ) external view returns (uint256) {
        Data storage data = HeyMintStorage.state().data;
        uint256 currentStakeStartTime = data.currentTimeStaked[_tokenId];
        if (currentStakeStartTime != 0) {
            return
                (block.timestamp - currentStakeStartTime) +
                data.totalTimeStaked[_tokenId];
        }
        return data.totalTimeStaked[_tokenId];
    }

    /**
     * @notice Return the amount of time a token has been currently staked
     * @param _tokenId The id of the token to check
     */
    function currentTokenStakeTime(
        uint256 _tokenId
    ) external view returns (uint256) {
        uint256 currentStakeStartTime = HeyMintStorage
            .state()
            .data
            .currentTimeStaked[_tokenId];
        if (currentStakeStartTime != 0) {
            return block.timestamp - currentStakeStartTime;
        }
        return 0;
    }

    // ============ FREE CLAIM ============

    /**
     * @notice To be updated by contract owner to allow free claiming tokens
     * @param _freeClaimActive If true tokens can be claimed for free
     */
    function setFreeClaimState(bool _freeClaimActive) external onlyOwner {
        AdvancedConfig storage advCfg = HeyMintStorage.state().advCfg;
        if (_freeClaimActive) {
            require(
                advCfg.freeClaimContractAddress != address(0),
                "NOT_CONFIGURED"
            );
            require(advCfg.mintsPerFreeClaim != 0, "NOT_CONFIGURED");
        }
        advCfg.freeClaimActive = _freeClaimActive;
    }

    /**
     * @notice Set the contract address of the NFT eligible for free claim
     * @param _freeClaimContractAddress The new contract address
     */
    function setFreeClaimContractAddress(
        address _freeClaimContractAddress
    ) external onlyOwner {
        HeyMintStorage
            .state()
            .advCfg
            .freeClaimContractAddress = _freeClaimContractAddress;
    }

    /**
     * @notice Update the number of free mints claimable per token redeemed from the external ERC721 contract
     * @param _mintsPerFreeClaim The new number of free mints per token redeemed
     */
    function updateMintsPerFreeClaim(
        uint8 _mintsPerFreeClaim
    ) external onlyOwner {
        HeyMintStorage.state().advCfg.mintsPerFreeClaim = _mintsPerFreeClaim;
    }

    /**
     * @notice Check if an array of tokens is eligible for free claim
     * @param _tokenIDs The ids of the tokens to check
     */
    function checkFreeClaimEligibility(
        uint256[] calldata _tokenIDs
    ) external view returns (bool[] memory) {
        Data storage data = HeyMintStorage.state().data;
        bool[] memory eligible = new bool[](_tokenIDs.length);
        for (uint256 i = 0; i < _tokenIDs.length; i++) {
            eligible[i] = !data.freeClaimUsed[_tokenIDs[i]];
        }
        return eligible;
    }

    /**
     * @notice Free claim token when msg.sender owns the token in the external contract
     * @param _tokenIDs The ids of the tokens to redeem
     */
    function freeClaim(
        uint256[] calldata _tokenIDs
    ) external payable nonReentrant {
        HeyMintStorage.State storage state = HeyMintStorage.state();
        uint256 tokenIdsLength = _tokenIDs.length;
        uint256 totalMints = tokenIdsLength * state.advCfg.mintsPerFreeClaim;
        require(
            state.advCfg.freeClaimContractAddress != address(0),
            "NOT_CONFIGURED"
        );
        require(state.advCfg.mintsPerFreeClaim != 0, "NOT_CONFIGURED");
        require(state.advCfg.freeClaimActive, "NOT_ACTIVE");
        require(
            totalSupply() + totalMints <= state.cfg.maxSupply,
            "MAX_SUPPLY_EXCEEDED"
        );
        if (state.cfg.heyMintFeeActive) {
            uint256 heymintFee = totalMints * heymintFeePerToken();
            require(msg.value == heymintFee, "PAYMENT_INCORRECT");
            (bool success, ) = heymintPayoutAddress.call{value: heymintFee}("");
            require(success, "TRANSFER_FAILED");
        }
        IERC721 ExternalERC721FreeClaimContract = IERC721(
            state.advCfg.freeClaimContractAddress
        );
        for (uint256 i = 0; i < tokenIdsLength; i++) {
            require(
                ExternalERC721FreeClaimContract.ownerOf(_tokenIDs[i]) ==
                    msg.sender,
                "MUST_OWN_TOKEN"
            );
            require(
                !state.data.freeClaimUsed[_tokenIDs[i]],
                "TOKEN_ALREADY_CLAIMED"
            );
            state.data.freeClaimUsed[_tokenIDs[i]] = true;
        }
        _safeMint(msg.sender, totalMints);
    }

    // ============ RANDOM HASH ============

    /**
     * @notice To be updated by contract owner to allow random hash generation
     * @param _randomHashActive true to enable random hash generation, false to disable
     */
    function setGenerateRandomHashState(
        bool _randomHashActive
    ) external onlyOwner {
        BaseConfig storage cfg = HeyMintStorage.state().cfg;
        cfg.randomHashActive = _randomHashActive;
    }

    /**
     * @notice Retrieve random hashes for an array of token ids
     * @param _tokenIDs The ids of the tokens to retrieve random hashes for
     */
    function getRandomHashes(
        uint256[] calldata _tokenIDs
    ) external view returns (bytes32[] memory) {
        Data storage data = HeyMintStorage.state().data;
        bytes32[] memory randomHashes = new bytes32[](_tokenIDs.length);
        for (uint256 i = 0; i < _tokenIDs.length; i++) {
            randomHashes[i] = data.randomHashStore[_tokenIDs[i]];
        }
        return randomHashes;
    }
}