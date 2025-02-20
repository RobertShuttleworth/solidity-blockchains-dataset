// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {HeyMintERC721AUpgradeable} from "./contracts_implementations_HeyMintERC721AUpgradeable.sol";
import {HeyMintStorage, BaseConfig} from "./contracts_libraries_HeyMintStorage.sol";
import {ECDSAUpgradeable} from "./openzeppelin_contracts-upgradeable_utils_cryptography_ECDSAUpgradeable.sol";

contract HeyMintERC721AExtensionB is HeyMintERC721AUpgradeable {
    using HeyMintStorage for HeyMintStorage.State;
    using ECDSAUpgradeable for bytes32;

    event HeyMintAffiliatePaid(address to, uint256 numTokens, uint256 value);

    // ============ PRESALE ============

    /**
     * @notice Returns the presale price in wei. Presale price is stored with 5 decimals (1 = 0.00001 ETH), so total 5 + 13 == 18 decimals
     */
    function presalePriceInWei() public view returns (uint256) {
        return uint256(HeyMintStorage.state().cfg.presalePrice) * 10 ** 13;
    }

    /**
     * @notice To be updated by contract owner to allow presale minting
     * @param _saleActiveState The new presale activ
     .e state
     */
    function setPresaleState(bool _saleActiveState) external onlyOwner {
        HeyMintStorage.state().cfg.presaleActive = _saleActiveState;
    }

    /**
     * @notice Update the presale mint price
     * @param _presalePrice The new presale mint price to use
     */
    function setPresalePrice(uint32 _presalePrice) external onlyOwner {
        HeyMintStorage.state().cfg.presalePrice = _presalePrice;
    }

    /**
     * @notice Reduce the max supply of tokens available to mint in the presale
     * @param _newPresaleMaxSupply The new maximum supply of presale tokens available to mint
     */
    function reducePresaleMaxSupply(
        uint16 _newPresaleMaxSupply
    ) external onlyOwner {
        BaseConfig storage cfg = HeyMintStorage.state().cfg;
        require(
            _newPresaleMaxSupply < cfg.presaleMaxSupply,
            "NEW_MAX_SUPPLY_TOO_HIGH"
        );
        cfg.presaleMaxSupply = _newPresaleMaxSupply;
    }

    /**
     * @notice Set the maximum mints allowed per a given address in the presale
     * @param _mintsAllowed The new maximum mints allowed per address in the presale
     */
    function setPresaleMintsAllowedPerAddress(
        uint8 _mintsAllowed
    ) external onlyOwner {
        HeyMintStorage
            .state()
            .cfg
            .presaleMintsAllowedPerAddress = _mintsAllowed;
    }

    /**
     * @notice Set the maximum mints allowed per a given transaction in the presale
     * @param _mintsAllowed The new maximum mints allowed per transaction in the presale
     */
    function setPresaleMintsAllowedPerTransaction(
        uint8 _mintsAllowed
    ) external onlyOwner {
        HeyMintStorage
            .state()
            .cfg
            .presaleMintsAllowedPerTransaction = _mintsAllowed;
    }

    /**
     * @notice Set the signer address used to verify presale minting
     * @param _presaleSignerAddress The new signer address to use
     */
    function setPresaleSignerAddress(
        address _presaleSignerAddress
    ) external onlyOwner {
        HeyMintStorage.state().cfg.presaleSignerAddress = _presaleSignerAddress;
    }

    /**
     * @notice Update the start time for presale mint
     */
    function setPresaleStartTime(uint32 _presaleStartTime) external onlyOwner {
        HeyMintStorage.state().cfg.presaleStartTime = _presaleStartTime;
    }

    /**
     * @notice Update the end time for presale mint
     */
    function setPresaleEndTime(uint32 _presaleEndTime) external onlyOwner {
        require(_presaleEndTime > block.timestamp, "TIME_IN_PAST");
        HeyMintStorage.state().cfg.presaleEndTime = _presaleEndTime;
    }

    /**
     * @notice Update whether or not to use the automatic presale times
     */
    function setUsePresaleTimes(bool _usePresaleTimes) external onlyOwner {
        HeyMintStorage.state().cfg.usePresaleTimes = _usePresaleTimes;
    }

    /**
     * @notice Returns if presale times are active. If required config settings are not set, returns true.
     */
    function presaleTimeIsActive() public view returns (bool) {
        BaseConfig storage cfg = HeyMintStorage.state().cfg;
        if (
            cfg.usePresaleTimes == false ||
            cfg.presaleStartTime == 0 ||
            cfg.presaleEndTime == 0
        ) {
            return true;
        }
        return
            block.timestamp >= cfg.presaleStartTime &&
            block.timestamp <= cfg.presaleEndTime;
    }

    /**
     * @notice Allow for allowlist minting of tokens
     * @param _messageHash The hash of the message containing msg.sender & _maximumAllowedMints to verify
     * @param _signature The signature of the messageHash to verify
     * @param _numTokens The number of tokens to mint
     * @param _maximumAllowedMints The maximum number of tokens that can be minted by the caller
     */
    function _presaleMint(
        bytes32 _messageHash,
        bytes calldata _signature,
        uint256 _numTokens,
        uint256 _maximumAllowedMints
    ) internal {
        HeyMintStorage.State storage state = HeyMintStorage.state();
        BaseConfig storage cfg = state.cfg;
        require(cfg.presaleActive, "NOT_ACTIVE");
        require(presaleTimeIsActive(), "NOT_ACTIVE");
        uint256 qtyAlreadyMinted = _numberMinted(msg.sender);
        require(
            cfg.presaleMintsAllowedPerAddress == 0 ||
                qtyAlreadyMinted + _numTokens <=
                cfg.presaleMintsAllowedPerAddress,
            "MAX_MINTS_EXCEEDED"
        );
        require(
            cfg.presaleMintsAllowedPerTransaction == 0 ||
                _numTokens <= cfg.presaleMintsAllowedPerTransaction,
            "MAX_MINTS_EXCEEDED"
        );
        require(
            qtyAlreadyMinted + _numTokens <= _maximumAllowedMints,
            "MAX_MINTS_EXCEEDED"
        );
        require(
            cfg.presaleMaxSupply == 0 ||
                totalSupply() + _numTokens <= cfg.presaleMaxSupply,
            "MAX_SUPPLY_EXCEEDED"
        );
        require(
            totalSupply() + _numTokens <= cfg.maxSupply,
            "MAX_SUPPLY_EXCEEDED"
        );
        uint256 presalePrice = presalePriceInWei();
        if (cfg.heyMintFeeActive) {
            uint256 heymintFee = _numTokens * heymintFeePerToken();
            require(
                msg.value == presalePrice * _numTokens + heymintFee,
                "INVALID_PRICE_PAID"
            );
            (bool success, ) = heymintPayoutAddress.call{value: heymintFee}("");
            require(success, "TRANSFER_FAILED");
        } else {
            require(
                msg.value == presalePrice * _numTokens,
                "INVALID_PRICE_PAID"
            );
        }
        require(
            keccak256(abi.encode(msg.sender, _maximumAllowedMints)) ==
                _messageHash,
            "MESSAGE_INVALID"
        );
        require(
            verifySignerAddress(_messageHash, _signature),
            "INVALID_SIGNATURE"
        );

        if (cfg.fundingEndsAt > 0) {
            uint256 firstTokenIdToMint = _nextTokenId();
            for (uint256 i = 0; i < _numTokens; i++) {
                HeyMintStorage.state().data.pricePaid[
                    firstTokenIdToMint + i
                ] = presalePrice;
            }
        }

        _safeMint(msg.sender, _numTokens);

        if (totalSupply() >= cfg.presaleMaxSupply) {
            cfg.presaleActive = false;
        }
    }

    /**
     * @notice Allow for allowlist minting of tokens
     * @param _messageHash The hash of the message containing msg.sender & _maximumAllowedMints to verify
     * @param _signature The signature of the messageHash to verify
     * @param _numTokens The number of tokens to mint
     * @param _maximumAllowedMints The maximum number of tokens that can be minted by the caller
     */
    function presaleMint(
        bytes32 _messageHash,
        bytes calldata _signature,
        uint256 _numTokens,
        uint256 _maximumAllowedMints
    ) external payable nonReentrant {
        _presaleMint(
            _messageHash,
            _signature,
            _numTokens,
            _maximumAllowedMints
        );
    }

    function _creditCardPresaleMint(
        bytes32 _messageHash,
        bytes calldata _signature,
        uint256 _numTokens,
        address _to,
        bytes32 _emailAddress,
        uint256 _maximumAllowedMints
    ) internal {
        HeyMintStorage.State storage state = HeyMintStorage.state();
        require(
            isSenderAuthorizedForCreditCardMint(),
            "NOT_AUTHORIZED_ADDRESS"
        );
        require(state.cfg.presaleActive, "NOT_ACTIVE");
        require(presaleTimeIsActive(), "NOT_ACTIVE");
        uint256 qtyAlreadyMinted = state.data.tokensMintedByEmailAddress[
            _emailAddress
        ];
        require(
            state.cfg.presaleMintsAllowedPerAddress == 0 ||
                qtyAlreadyMinted + _numTokens <=
                state.cfg.presaleMintsAllowedPerAddress,
            "MAX_MINTS_EXCEEDED"
        );
        require(
            state.cfg.presaleMintsAllowedPerTransaction == 0 ||
                _numTokens <= state.cfg.presaleMintsAllowedPerTransaction,
            "MAX_MINTS_EXCEEDED"
        );
        require(
            qtyAlreadyMinted + _numTokens <= _maximumAllowedMints,
            "MAX_MINTS_EXCEEDED"
        );
        // We are minting by verified email address, but still double check the _to address to prevent abuse.
        require(
            _numberMinted(_to) + _numTokens <=
                state.cfg.presaleMintsAllowedPerAddress &&
                _numberMinted(_to) + _numTokens <= _maximumAllowedMints,
            "MAX_MINTS_EXCEEDED"
        );
        require(
            state.cfg.presaleMaxSupply == 0 ||
                totalSupply() + _numTokens <= state.cfg.presaleMaxSupply,
            "MAX_SUPPLY_EXCEEDED"
        );
        require(
            totalSupply() + _numTokens <= state.cfg.maxSupply,
            "MAX_SUPPLY_EXCEEDED"
        );
        uint256 presalePrice = presalePriceInWei();
        if (state.cfg.heyMintFeeActive) {
            uint256 heymintFee = _numTokens * heymintFeePerToken();
            require(
                msg.value == presalePrice * _numTokens + heymintFee,
                "INVALID_PRICE_PAID"
            );
            (bool success, ) = heymintPayoutAddress.call{value: heymintFee}("");
            require(success, "TRANSFER_FAILED");
        } else {
            require(
                msg.value == presalePrice * _numTokens,
                "INVALID_PRICE_PAID"
            );
        }
        require(
            keccak256(abi.encode(_emailAddress, _maximumAllowedMints)) ==
                _messageHash,
            "MESSAGE_INVALID"
        );
        require(
            verifySignerAddress(_messageHash, _signature),
            "INVALID_SIGNATURE"
        );

        if (state.cfg.fundingEndsAt > 0) {
            uint256 firstTokenIdToMint = _nextTokenId();
            for (uint256 i = 0; i < _numTokens; i++) {
                HeyMintStorage.state().data.pricePaid[
                    firstTokenIdToMint + i
                ] = presalePrice;
            }
        }

        state.data.tokensMintedByEmailAddress[_emailAddress] += _numTokens;

        _safeMint(_to, _numTokens);

        if (totalSupply() >= state.cfg.presaleMaxSupply) {
            state.cfg.presaleActive = false;
        }
    }

    /**
     * @notice Allow for allowlist minting of tokens via credit card
     * @param _messageHash The hash of the message containing the _emailAddress hash & _maximumAllowedMints to verify
     * @param _signature The signature of the messageHash to verify
     * @param _numTokens The number of tokens to mint
     * @param _to The address to mint the tokens to
     * @param _emailAddress keccak256 hash of the email address allowed to mint
     * @param _maximumAllowedMints The maximum number of tokens that can be minted by the caller
     */
    function creditCardPresaleMint(
        bytes32 _messageHash,
        bytes calldata _signature,
        uint256 _numTokens,
        address _to,
        bytes32 _emailAddress,
        uint256 _maximumAllowedMints
    ) external payable nonReentrant {
        _creditCardPresaleMint(
            _messageHash,
            _signature,
            _numTokens,
            _to,
            _emailAddress,
            _maximumAllowedMints
        );
    }

    /**
     * @notice Allow for allowlist minting of tokens via credit card, including affiliate payments
     * @param _affPaymentAddress The address to receive affiliate fees
     * @param _affMessageHash The hash of the affiliate message containing the affiliate payment address & projectId
     * @param _affSignature The signature for the affiliate payment message to verify
     * @param _messageHash The hash of the message containing the _emailAddress hash and _maximumAllowedMints to verify
     * @param _signature The signature of the messageHash to verify
     * @param _numTokens The number of tokens to mint
     * @param _to The address to mint the tokens to
     * @param _emailAddress keccak256 hash of the email address allowed to mint
     * @param _maximumAllowedMints The maximum number of tokens that can be minted by the caller
     */
    function affiliateCreditCardPresaleMint(
        address _affPaymentAddress,
        bytes32 _affMessageHash,
        bytes calldata _affSignature,
        bytes32 _messageHash,
        bytes calldata _signature,
        uint256 _numTokens,
        address _to,
        bytes32 _emailAddress,
        uint256 _maximumAllowedMints
    ) external payable nonReentrant {
        require(isPresaleAffiliateMintActive(), "NOT_ACTIVE");
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
        _creditCardPresaleMint(
            _messageHash,
            _signature,
            _numTokens,
            _to,
            _emailAddress,
            _maximumAllowedMints
        );
        uint256 affFee = (_numTokens *
            presalePriceInWei() *
            state.cfg.affiliateBasisPoints) / 10000;
        (bool ok, ) = _affPaymentAddress.call{value: affFee}("");
        require(ok, "TRANSFER_FAILED");
        emit HeyMintAffiliatePaid(_affPaymentAddress, _numTokens, affFee);
    }

    /**
     * @notice Checks if the presale affiliate minting is currently active.
     * @return A boolean indicating whether presale affiliate minting is active.
     */
    function isPresaleAffiliateMintActive() public view returns (bool) {
        HeyMintStorage.State storage state = HeyMintStorage.state();
        return (state.cfg.presaleSignerAddress != address(0) &&
            state.cfg.presaleAffiliateMintEnabled &&
            state.cfg.presaleActive &&
            state.cfg.presalePrice > 0 &&
            state.cfg.affiliateBasisPoints > 0 &&
            (!state.cfg.usePresaleTimes ||
                block.timestamp >= state.cfg.presaleStartTime) &&
            (!state.cfg.usePresaleTimes ||
                block.timestamp < state.cfg.presaleEndTime));
    }

    /**
     * @notice Allows for allowlist minting of tokens using an affiliate.
     * @param _affPaymentAddress The address to receive affiliate fees
     * @param _affMessageHash The hash of the affiliate message containing the affiliate payment address & projectId
     * @param _affSignature The signature for the affiliate payment message to verify
     * @param _messageHash The hash of the message containing msg.sender & _maximumAllowedMints to verify
     * @param _signature The signature of the messageHash to verify
     * @param _numTokens The number of tokens to mint
     * @param _maximumAllowedMints The maximum number of tokens that can be minted by the caller
     */
    function affiliatePresaleMint(
        address _affPaymentAddress,
        bytes32 _affMessageHash,
        bytes calldata _affSignature,
        bytes32 _messageHash,
        bytes calldata _signature,
        uint256 _numTokens,
        uint256 _maximumAllowedMints
    ) external payable nonReentrant {
        require(isPresaleAffiliateMintActive(), "NOT_ACTIVE");
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
        _presaleMint(
            _messageHash,
            _signature,
            _numTokens,
            _maximumAllowedMints
        );
        uint256 affFee = (_numTokens *
            presalePriceInWei() *
            state.cfg.affiliateBasisPoints) / 10000;
        (bool ok, ) = _affPaymentAddress.call{value: affFee}("");
        require(ok, "TRANSFER_FAILED");
        emit HeyMintAffiliatePaid(_affPaymentAddress, _numTokens, affFee);
    }
}