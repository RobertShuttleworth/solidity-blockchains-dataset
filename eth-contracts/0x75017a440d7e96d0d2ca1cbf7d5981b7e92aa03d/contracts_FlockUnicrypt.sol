//SPDX-License-Identifier: MIT

/*

FlipLock Marketplace is a unique platform designed for trading locked liquidity
pairs that are secured on Unicrypt. This smart contract-based marketplace enables
users to engage in various activities such as trading, selling, and bidding on 
these locked LP tokens. By providing a secure environment where locked tokens 
can be transacted, FlipLock Marketplace enhances liquidity and access, allowing 
participants to capitalize on locked assets without compromising their security.
This approach not only supports a more fluid and dynamic market for locked tokens
but also maintains the integrity and purpose of the liquidity locking by ensuring
that these assets remain secured until their predetermined unlock dates.

https://flock.market

Token
*/

pragma solidity 0.8.26;
import "./contracts_Ownable.sol";
import "./contracts_IERC20.sol";
import "./contracts_ReentrancyGuard.sol";

interface IUniswapV2Locker {
    // Getter function to fetch details about a specific lock for a user
    function getUserLockForTokenAtIndex(
        address user,
        address lpAddress,
        uint256 index
    )
        external
        view
        returns (uint256, uint256, uint256, uint256, uint256, address);

    function tokenLocks(
        address lpAddress,
        uint256 lockID
    )
        external
        view
        returns (uint256, uint256, uint256, uint256, uint256, address);

    // Function to transfer the ownership of a lock
    function transferLockOwnership(
        address lpAddress,
        uint256 index,
        uint256 lockID,
        address payable newOwner
    ) external;

    function getUserNumLocksForToken(
        address _user,
        address _lpAddress
    ) external view returns (uint256);
}

/// @title Marketplace for LP Token Lock Ownership
/// @notice This contract allows users to list and sell their Uniswap V2 LP token lock ownerships locked through Unicrypt.
contract FlockUnicrypt is Ownable, ReentrancyGuard {
    // Unicrypt V2 Locker address
    IUniswapV2Locker public uniswapV2Locker;

    // Native Flocks token address
    IERC20 public flockToken;
    address payable public feeWallet;
    uint256 public listingCount;
    address public marketplaceOwner;
    uint256 public activeListings;
    uint256 public listedLPsCount;
    uint256 public totalValueListedInFlock;
    uint256 public totalValueList;
    uint256 public ethFee;
    uint256 public referralBonus;

    // Zero address constant
    address zeroAddress = 0x0000000000000000000000000000000000000000;

    // Relevant listing info
    struct Listing {
        uint256 lockID;
        uint256 listingID;
        uint256 listingIndex;
        address payable seller;
        address lpAddress;
        uint256 priceInETH;
        uint256 priceInFlocks;
        uint256 listDate;
        bool isActive;
        bool isSold;
        address payable referral;
        bool isVerified;
        bool forAuction;
        uint256 auctionIndex;
    }

    struct Bid {
        address bidder;
        uint256 flocksBid;
        uint256 ethBid;
        uint256 listingID;
    }

    struct ListingDetail {
        uint256 lockID;
        address lpAddress;
    }

    struct AuctionDetails {
        Bid topEthBid;
        Bid topFlocksBid;
    }

    // lpAddress + lockID -> returns Listing
    mapping(address => mapping(uint256 => Listing)) public lpToLockID;
    mapping(uint256 => ListingDetail) public listingDetail;
    mapping(address => bool) public isLPListed;
    mapping(address => Bid[]) public userBids;
    mapping(address => mapping(uint256 => Bid[])) public lpBids;

    // Auctions:
    AuctionDetails[] auctions;
    uint256 auctionCount;

    // Relevant events
    event NewBid(
        address bidder,
        address lpAddress,
        uint256 lockID,
        uint256 bidInFlocks,
        uint256 bidInEth
    );
    event BidRedacted(
        address bidder,
        address lpAddress,
        uint256 lockId,
        uint256 bidInFlocks,
        uint bidInEth
    );
    event BidAccepted(
        address lpToken,
        uint256 lockId,
        uint256 profitInEth,
        uint256 feeEth,
        uint256 profitInFlocks
    );
    event LockPurchasedWithETH(
        address lpToken,
        uint256 lockID,
        uint256 profitInETH,
        uint256 feeETH
    );
    event LockPurchasedWithFlocks(
        address lpToken,
        uint256 lockID,
        uint256 profitInFlocks
    );
    event ListingInitiated(address lpToken, uint256 lockID, address seller);
    event NewActiveListing(
        address lpToken,
        uint256 lockID,
        uint256 priceInETH,
        uint256 priceInFlocks
    );
    event LockVerified(address lpToken, uint256 lockID, bool status);
    event ListingRedacted(address lpToken, uint256 lockID, address seller);
    event ListingWithdrawn(address lpToken, uint256 lockID);
    event FlocksAddressUpdated(address _flocksAddress);
    event FeeAddressUpdated(address _feeWallet);
    event LockerAddressUpdated(address _lockerAddress);
    event ChangedETHFee(uint256 _ethFee);
    event ChangedReferralBonus(uint256 _referralBonus);

    /// @notice Initialize the contract with Uniswap V2 Locker, Fee Wallet, and Flocks Token addresses
    /// @dev Sets the contract's dependencies and the owner upon deployment
    /// @param _uniswapV2Locker Address of the Uniswap V2 Locker contract
    /// @param _feeWallet Address of the wallet where fees will be collected
    /// @param _flocksTokenAddress Address of the Flocks token contract
    constructor(
        address _uniswapV2Locker,
        address payable _feeWallet,
        address _flocksTokenAddress
    ) Ownable(msg.sender) {
        uniswapV2Locker = IUniswapV2Locker(_uniswapV2Locker);
        feeWallet = _feeWallet;
        marketplaceOwner = msg.sender;
        flockToken = IERC20(_flocksTokenAddress);
        ethFee = 10;
        referralBonus = 0;
    }

    /// @notice Set the referral fee (in percentage)
    /// @dev This function can only be called by the contract owner
    /// @param _referralBonus Referral fee percentage for buyLockWithETH
    function setReferralFee(uint256 _referralBonus) external onlyOwner {
        require(
            referralBonus <= 50,
            "Maximum referral bonus is 50% of the fee"
        );
        require(referralBonus != _referralBonus, "You must change the bonus");
        referralBonus = _referralBonus;
        emit ChangedReferralBonus(_referralBonus);
    }

    /// @notice Set the eth fee (in percentage)
    /// @dev This function can only be called by the contract owner
    /// @param _ethFee Fee percentage for buyLockWithETH
    function setETHFee(uint256 _ethFee) external onlyOwner {
        require(_ethFee <= 10, "Maximum fee is 10%");
        require(ethFee != _ethFee, "You must change the fee");
        ethFee = _ethFee;
        emit ChangedETHFee(_ethFee);
    }

    /// @notice Set the address of the Flocks token
    /// @dev This function can only be called by the contract owner
    /// @param _flocksTokenAddress The address of the Flocks token contract
    function setFlocksToken(address _flocksTokenAddress) external onlyOwner {
        require(
            address(flockToken) != _flocksTokenAddress,
            "Must input different contract address"
        );
        require(
            _flocksTokenAddress != zeroAddress,
            "Cant set flocks address as zero address"
        );
        flockToken = IERC20(_flocksTokenAddress);
        emit FlocksAddressUpdated(_flocksTokenAddress);
    }

    /// @notice Set the address of the fee wallet
    /// @dev This function can only be called by the contract owner
    /// @param _feeWallet The address of the new fee wallet
    function setFeeWallet(address payable _feeWallet) external onlyOwner {
        require(feeWallet != _feeWallet, "Same wallet");
        require(
            _feeWallet != zeroAddress,
            "Cant set fee wallet as zero address"
        );
        feeWallet = _feeWallet;
        emit FeeAddressUpdated(_feeWallet);
    }

    /// @notice Set the address of the liquidity locker
    /// @dev This function can only be called by the contract owner
    /// @param _uniswapV2Locker The address of the new liquidity locker
    function setLockerAddress(address _uniswapV2Locker) external onlyOwner {
        require(
            address(uniswapV2Locker) != _uniswapV2Locker,
            "Must input different contract address"
        );
        require(
            _uniswapV2Locker != zeroAddress,
            "Cant set locker address as zero address"
        );
        uniswapV2Locker = IUniswapV2Locker(_uniswapV2Locker);
        emit LockerAddressUpdated(_uniswapV2Locker);
    }

    function _initializeAuctionDetails(
        uint256 _listingId
    ) internal pure returns (AuctionDetails memory) {
        AuctionDetails memory blankAuctionDetails;
        blankAuctionDetails.topEthBid = Bid(address(0), 0, 0, _listingId);
        blankAuctionDetails.topFlocksBid = Bid(address(0), 0, 0, _listingId);

        return blankAuctionDetails;
    }

    /// @notice List an LP token lock for sale
    /// @dev The seller must be the owner of the lock and approve this contract to manage the lock
    /// @param _lpAddress Address of the LP token
    /// @param _lockId The ID of the lock
    /// @param _priceInETH The selling price in ETH
    /// @param _priceInFlocks The selling price in Flocks tokens
    function initiateListing(
        address _lpAddress,
        uint256 _lockId,
        uint256 _priceInETH,
        uint256 _priceInFlocks,
        address payable _referral
    ) external {
        (, , , , , address owner) = uniswapV2Locker.tokenLocks(
            _lpAddress,
            _lockId
        );
        require(msg.sender == owner, "You dont own that lock.");
        require(
            (_priceInETH > 0) || (_priceInFlocks > 0),
            "You must set a price in Flocks or ETH"
        );
        Listing memory tempListing = lpToLockID[_lpAddress][_lockId];
        (bool lockFound, uint256 index) = _getIndexForUserLock(
            _lpAddress,
            _lockId,
            _msgSender()
        );
        require(lockFound, "Lock not found!");
        AuctionDetails memory tempDetails;
        if (tempListing.listingID == 0) {
            listingCount++;
            listingDetail[listingCount] = ListingDetail(_lockId, _lpAddress);
            tempDetails = _initializeAuctionDetails(listingCount);
        } else {
            tempDetails = _initializeAuctionDetails(tempListing.listingID);
        }
        auctions.push(tempDetails);

        lpToLockID[_lpAddress][_lockId] = Listing(
            _lockId,
            listingCount,
            index,
            payable(msg.sender),
            _lpAddress,
            _priceInETH,
            _priceInFlocks,
            block.timestamp,
            false,
            false,
            _referral,
            false,
            true,
            auctionCount
        );

        auctionCount++;

        if (!isLPListed[_lpAddress]) {
            isLPListed[_lpAddress] = true;
            listedLPsCount++;
        }

        emit ListingInitiated(_lpAddress, _lockId, msg.sender);
    }

    /// @notice Bid on a listing with Ethereum - transfer ETH to CA until bid is either beat, accepted, or withdrawn
    /// @dev Bidder must not be listing owner.
    /// @param _lpAddress Address of the LP token
    /// @param _lockId The ID of the lock
    function bidEth(address _lpAddress, uint256 _lockId) external payable {
        Listing storage tempListing = lpToLockID[_lpAddress][_lockId];
        require(tempListing.forAuction, "Listing not for auction");
        require(
            tempListing.seller != msg.sender,
            "Unable to bid on own listing"
        );
        require(tempListing.isActive, "Listing inactive.");
        require(!tempListing.isSold, "Listing already sold.");

        AuctionDetails storage currentAuction = auctions[
            tempListing.auctionIndex
        ];

        require(
            msg.value > currentAuction.topEthBid.ethBid,
            "Must outbid current highest bid"
        );

        if (currentAuction.topEthBid.ethBid > 0) {
            payable(currentAuction.topEthBid.bidder).transfer(
                currentAuction.topEthBid.ethBid
            );
        }

        currentAuction.topEthBid = Bid(
            msg.sender,
            0,
            msg.value,
            tempListing.listingID
        );

        userBids[msg.sender].push(currentAuction.topEthBid);
        lpBids[_lpAddress][_lockId].push(currentAuction.topEthBid);
        emit NewBid(msg.sender, _lpAddress, _lockId, 0, msg.value);
    }

    /// @notice Bid on a listing with Flocks - transfer Flocks to CA until bid is either beat, accepted, or withdrawn
    /// @dev Bidder must not be listing owner
    /// @param _lpAddress Address of the LP token
    /// @param _lockId The ID of the lock
    /// @param _amount Amount of Flocks to bid with
    function bidFlocks(
        address _lpAddress,
        uint256 _lockId,
        uint256 _amount
    ) external nonReentrant {
        Listing storage tempListing = lpToLockID[_lpAddress][_lockId];
        require(tempListing.forAuction, "Listing not for auction");
        require(
            tempListing.seller != msg.sender,
            "Unable to bid on own listing"
        );
        require(tempListing.isActive, "Listing inactive.");
        require(!tempListing.isSold, "Listing already sold.");

        AuctionDetails storage currentAuction = auctions[
            tempListing.auctionIndex
        ];

        require(
            _amount > currentAuction.topFlocksBid.flocksBid,
            "Must outbid current highest bid"
        );

        if (currentAuction.topFlocksBid.flocksBid > 0) {
            flockToken.transfer(
                currentAuction.topFlocksBid.bidder,
                currentAuction.topFlocksBid.flocksBid
            );
        }

        flockToken.transferFrom(msg.sender, address(this), _amount);

        currentAuction.topFlocksBid = Bid(
            msg.sender,
            _amount,
            0,
            tempListing.listingID
        );

        userBids[msg.sender].push(currentAuction.topFlocksBid);
        lpBids[_lpAddress][_lockId].push(currentAuction.topFlocksBid);

        emit NewBid(msg.sender, _lpAddress, _lockId, _amount, 0);
    }

    function acceptBid(
        address _lpAddress,
        uint256 _lockId,
        bool _eth
    ) external nonReentrant {
        Listing storage tempListing = lpToLockID[_lpAddress][_lockId];
        AuctionDetails storage tempAuction = auctions[tempListing.auctionIndex];
        require(tempListing.seller == msg.sender, "Owner can accept bid");

        Bid storage topBid;
        if (_eth) {
            topBid = tempAuction.topEthBid;
            if (tempAuction.topFlocksBid.flocksBid > 0) {
                _returnBid(
                    _lpAddress,
                    _lockId,
                    !_eth,
                    tempListing,
                    tempAuction.topFlocksBid.bidder
                );
            }
        } else {
            topBid = tempAuction.topFlocksBid;
            if (tempAuction.topEthBid.ethBid > 0) {
                _returnBid(
                    _lpAddress,
                    _lockId,
                    _eth,
                    tempListing,
                    tempAuction.topEthBid.bidder
                );
            }
        }

        require(
            (topBid.ethBid > 0 && _eth) || (topBid.flocksBid > 0 && !_eth),
            "Bid must exceed 0"
        );

        _winAuction(tempListing, topBid, _eth);
    }

    function _winAuction(
        Listing storage _tempListing,
        Bid storage _winningBid,
        bool _eth
    ) private {
        require(_tempListing.isActive, "Listing must be active.");
        (bool lockFound, uint256 index) = _getIndex(
            _tempListing.lpAddress,
            _tempListing
        );
        require(lockFound, "Mismatch in inputs");

        if (_eth) {
            require(
                address(this).balance >= _winningBid.ethBid,
                "Insufficient"
            );
            uint256 feeAmount = (_winningBid.ethBid * ethFee) / 100;
            uint256 toPay = _winningBid.ethBid - feeAmount;
            _winningBid.ethBid = 0;

            if (_tempListing.referral != zeroAddress) {
                uint256 feeForReferral = (feeAmount * referralBonus) / 100;
                feeAmount = feeAmount - feeForReferral;
                _tempListing.referral.transfer(feeForReferral);
                feeWallet.transfer(feeAmount);
            } else {
                feeWallet.transfer(feeAmount);
            }

            payable(_tempListing.seller).transfer(toPay);
            _tempListing.isActive = false;
            _tempListing.isSold = true;
            activeListings--;

            uniswapV2Locker.transferLockOwnership(
                _tempListing.lpAddress,
                index,
                _tempListing.lockID,
                payable(_winningBid.bidder)
            );

            emit BidAccepted(
                _tempListing.lpAddress,
                _tempListing.lockID,
                toPay,
                feeAmount,
                0
            );
        } else {
            require(
                flockToken.balanceOf(address(this)) > _winningBid.flocksBid,
                "Insufficient flocks."
            );

            uint256 toSend = _winningBid.flocksBid;
            require(flockToken.transfer(_tempListing.seller, toSend));
            _winningBid.flocksBid = 0;

            _tempListing.isActive = false;
            _tempListing.isSold = true;
            activeListings--;

            uniswapV2Locker.transferLockOwnership(
                _tempListing.lpAddress,
                index,
                _tempListing.lockID,
                payable(_winningBid.bidder)
            );

            emit BidAccepted(
                _tempListing.lpAddress,
                _tempListing.lockID,
                0,
                0,
                toSend
            );
        }
    }

    /// @notice Redact your bid on select lock - must be done prior to the expiry date of auction.
    /// @param _lpAddress Address of the LP token
    /// @param _lockId The ID of the lock
    /// @param _eth True if bidder is redacting a bid in ETH, false if bid is in Flocks
    function redactBid(
        address _lpAddress,
        uint256 _lockId,
        bool _eth
    ) external nonReentrant {
        Listing memory tempListing = lpToLockID[_lpAddress][_lockId];
        require(tempListing.forAuction, "No auction for this listing");

        AuctionDetails memory currentAuction = auctions[
            tempListing.auctionIndex
        ];

        if (_eth) {
            require(currentAuction.topEthBid.ethBid > 0, "No ETH bid present");
        } else {
            require(
                currentAuction.topFlocksBid.flocksBid > 0,
                "No Flocks bid present"
            );
        }

        _returnBid(_lpAddress, _lockId, _eth, tempListing, msg.sender);
    }

    function _returnBid(
        address _lpAddress,
        uint256 _lockId,
        bool _eth,
        Listing memory _tempListing,
        address _sender
    ) internal {
        AuctionDetails storage currentAuction = auctions[
            _tempListing.auctionIndex
        ];
        if (_eth) {
            require(
                currentAuction.topEthBid.bidder == _sender,
                "You are not the current ETH bidder"
            );
            address payable toSend = payable(currentAuction.topEthBid.bidder);
            uint256 amount = currentAuction.topEthBid.ethBid;
            currentAuction.topEthBid = Bid(
                address(0),
                0,
                0,
                _tempListing.listingID
            );

            if (amount > 0) {
                toSend.transfer(amount);

                emit BidRedacted(_sender, _lpAddress, _lockId, 0, amount);
            }
        } else {
            require(
                currentAuction.topFlocksBid.bidder == _sender,
                "You are not the top Flocks bidder"
            );
            address toSend = currentAuction.topFlocksBid.bidder;
            uint256 amount = currentAuction.topFlocksBid.flocksBid;
            currentAuction.topFlocksBid = Bid(
                address(0),
                0,
                0,
                _tempListing.listingID
            );

            if (amount > 0) {
                flockToken.transfer(toSend, amount);

                emit BidRedacted(_sender, _lpAddress, _lockId, amount, 0);
            }
        }
    }

    /// @notice Activate an initiated listing
    /// @dev The seller must have transfered lock ownership to address(this)
    /// @param _lpAddress Address of the LP token
    /// @param _lockId Unique lockID (per lpAddress) of the lock
    function activateListing(address _lpAddress, uint256 _lockId) external {
        Listing memory tempListing = lpToLockID[_lpAddress][_lockId];
        require(tempListing.seller == msg.sender, "Lock doesnt belong to you.");
        require(!tempListing.isActive, "Listing already active.");
        require(!tempListing.isSold, "Listing already sold.");
        (, , , , , address owner) = uniswapV2Locker.tokenLocks(
            _lpAddress,
            _lockId
        );
        require(owner == address(this), "Lock ownership not yet transferred.");
        lpToLockID[_lpAddress][_lockId].isActive = true;
        activeListings++;
        delete lpBids[_lpAddress][_lockId];
        emit NewActiveListing(
            tempListing.lpAddress,
            tempListing.lockID,
            tempListing.priceInETH,
            tempListing.priceInFlocks
        );
    }

    function fetchListing(
        address _lpAddress,
        uint256 _lockID
    ) external view returns (Listing memory) {
        return (lpToLockID[_lpAddress][_lockID]);
    }

    function totalUserBidsCount(address _user) external view returns (uint256) {
        return userBids[_user].length;
    }

    function totalLPBidsCount(
        address _lpAddress,
        uint256 _lockID
    ) public view returns (uint256) {
        return lpBids[_lpAddress][_lockID].length;
    }

    function fetchLPBids(
        address _lpAddress,
        uint256 _lockID
    ) external view returns (Bid[] memory) {
        return (lpBids[_lpAddress][_lockID]);
    }

    function fetchAuctionDetails(
        uint256 _auctionIndex
    ) external view returns (AuctionDetails memory) {
        return (auctions[_auctionIndex]);
    }

    /// @notice Purchase a listed LP token lock with ETH
    /// @param _lpAddress Address of the LP token
    /// @param _lockId The ID of the lock
    function buyLockWithETH(
        address _lpAddress,
        uint256 _lockId
    ) external payable nonReentrant {
        Listing memory tempListing = lpToLockID[_lpAddress][_lockId];
        require(tempListing.isActive, "Listing must be active.");
        require(tempListing.priceInETH > 0, "Listing not for sale in ETH.");
        require(
            msg.value == tempListing.priceInETH,
            "Incorrect amount of ETH."
        );

        (bool lockFound, uint256 index) = _getIndex(_lpAddress, tempListing);

        require(lockFound, "Mismatch in inputs");

        uint256 feeAmount = (msg.value * ethFee) / 100;
        uint256 toPay = msg.value - feeAmount;

        if (tempListing.referral != zeroAddress) {
            uint256 feeForReferral = (feeAmount * referralBonus) / 100;
            feeAmount = feeAmount - feeForReferral;
            tempListing.referral.transfer(feeForReferral);
            feeWallet.transfer(feeAmount);
        } else {
            feeWallet.transfer(feeAmount);
        }

        payable(tempListing.seller).transfer(toPay);

        if (tempListing.forAuction) {
            AuctionDetails memory currentAuction = auctions[
                tempListing.auctionIndex
            ];

            if (
                currentAuction.topFlocksBid.flocksBid > 0 &&
                currentAuction.topEthBid.ethBid > 0
            ) {
                _returnBid(
                    _lpAddress,
                    _lockId,
                    true,
                    tempListing,
                    currentAuction.topEthBid.bidder
                );

                _returnBid(
                    _lpAddress,
                    _lockId,
                    false,
                    tempListing,
                    currentAuction.topFlocksBid.bidder
                );
            } else if (currentAuction.topEthBid.ethBid > 0) {
                _returnBid(
                    _lpAddress,
                    _lockId,
                    true,
                    tempListing,
                    currentAuction.topEthBid.bidder
                );
            } else if (currentAuction.topFlocksBid.flocksBid > 0) {
                _returnBid(
                    _lpAddress,
                    _lockId,
                    false,
                    tempListing,
                    currentAuction.topFlocksBid.bidder
                );
            }
        }

        lpToLockID[_lpAddress][_lockId].isActive = false;
        lpToLockID[_lpAddress][_lockId].isSold = true;
        activeListings--;

        uniswapV2Locker.transferLockOwnership(
            _lpAddress,
            index,
            _lockId,
            payable(msg.sender)
        );

        emit LockPurchasedWithETH(
            tempListing.lpAddress,
            tempListing.lockID,
            toPay,
            feeAmount
        );
    }

    /// @notice Purchase a listed LP token lock with Flocks tokens
    /// @dev Requires approval to transfer Flocks tokens to cover the purchase price
    /// @param _lpAddress Address of the LP token
    /// @param _lockId The ID of the lock
    function buyLockWithFlocks(
        address _lpAddress,
        uint256 _lockId
    ) external payable nonReentrant {
        Listing memory tempListing = lpToLockID[_lpAddress][_lockId];

        require(tempListing.isActive, "Listing must be active.");
        require(
            tempListing.priceInFlocks > 0,
            "Listing not for sale in Flocks."
        );
        require(
            flockToken.balanceOf(msg.sender) > tempListing.priceInFlocks,
            "Insufficient flocks."
        );

        (bool lockFound, uint256 index) = _getIndex(_lpAddress, tempListing);

        require(lockFound, "Mismatch in inputs.");
        require(
            flockToken.transferFrom(
                msg.sender,
                tempListing.seller,
                tempListing.priceInFlocks
            )
        );

        if (tempListing.forAuction) {
            AuctionDetails memory currentAuction = auctions[
                tempListing.auctionIndex
            ];

            if (
                currentAuction.topFlocksBid.flocksBid > 0 &&
                currentAuction.topEthBid.ethBid > 0
            ) {
                _returnBid(
                    _lpAddress,
                    _lockId,
                    true,
                    tempListing,
                    currentAuction.topEthBid.bidder
                );

                _returnBid(
                    _lpAddress,
                    _lockId,
                    false,
                    tempListing,
                    currentAuction.topFlocksBid.bidder
                );
            } else if (currentAuction.topEthBid.ethBid > 0) {
                _returnBid(
                    _lpAddress,
                    _lockId,
                    true,
                    tempListing,
                    currentAuction.topEthBid.bidder
                );
            } else if (currentAuction.topFlocksBid.flocksBid > 0) {
                _returnBid(
                    _lpAddress,
                    _lockId,
                    false,
                    tempListing,
                    currentAuction.topFlocksBid.bidder
                );
            }
        }

        lpToLockID[_lpAddress][_lockId].isActive = false;
        lpToLockID[_lpAddress][_lockId].isSold = true;
        activeListings--;

        uniswapV2Locker.transferLockOwnership(
            _lpAddress,
            index,
            _lockId,
            payable(msg.sender)
        );

        emit LockPurchasedWithFlocks(
            tempListing.lpAddress,
            tempListing.lockID,
            tempListing.priceInFlocks
        );
    }

    function getIndex(
        address _user,
        address _lpAddress,
        uint256 _lockId
    ) external view returns (bool, uint256) {
        return _getIndexForUserLock(_lpAddress, _lockId, _user);
    }

    /// @notice Find unique (per lpAddress) lock index in order to transfer lock ownership
    /// @param _lpAddress Address of the LP token
    /// @param _listing Listing in question
    function _getIndex(
        address _lpAddress,
        Listing memory _listing
    ) internal view returns (bool, uint256) {
        uint256 index;
        uint256 numLocksAtAddress = uniswapV2Locker.getUserNumLocksForToken(
            address(this),
            _lpAddress
        );
        bool lockFound = false;

        if (numLocksAtAddress == 1) {
            index = 0;
            lockFound = true;
        } else {
            for (index = 0; index < numLocksAtAddress; index++) {
                (, , , , uint256 _lockId, ) = uniswapV2Locker
                    .getUserLockForTokenAtIndex(
                        address(this),
                        _lpAddress,
                        index
                    );
                if (_lockId == _listing.lockID) {
                    lockFound = true;
                    break;
                }
            }
        }
        return (lockFound, index);
    }

    function _getIndexForUserLock(
        address _lpAddress,
        uint256 _lockId,
        address user
    ) internal view returns (bool, uint256) {
        uint256 index;
        uint256 numLocksAtAddress = uniswapV2Locker.getUserNumLocksForToken(
            user,
            _lpAddress
        );
        bool lockFound = false;
        if (numLocksAtAddress == 1) {
            index = 0;
            lockFound = true;
        } else {
            for (index = 0; index < numLocksAtAddress; index++) {
                (, , , , uint256 _tempLockID, ) = uniswapV2Locker
                    .getUserLockForTokenAtIndex(user, _lpAddress, index);
                if (_tempLockID == _lockId) {
                    lockFound = true;
                    break;
                }
            }
        }
        return (lockFound, index);
    }

    /// @notice Withdraw a listed LP token lock
    /// @dev Only the seller can withdraw the listing
    /// @param _lpAddress Address of the LP token
    /// @param _lockId The ID of the lock
    function withdrawListing(
        address _lpAddress,
        uint256 _lockId
    ) external nonReentrant {
        Listing memory tempListing = lpToLockID[_lpAddress][_lockId];
        require(
            tempListing.seller == msg.sender,
            "This listing does not belong to you."
        );

        (, , , , , address owner) = uniswapV2Locker.tokenLocks(
            _lpAddress,
            _lockId
        );
        require(owner == address(this), "Marketplace does not own your lock");

        (bool lockFound, uint256 index) = _getIndex(_lpAddress, tempListing);

        require(lockFound, "Mismatch in inputs.");

        if (tempListing.forAuction) {
            AuctionDetails memory currentAuction = auctions[
                tempListing.auctionIndex
            ];

            if (
                currentAuction.topFlocksBid.flocksBid > 0 &&
                currentAuction.topEthBid.ethBid > 0
            ) {
                _returnBid(
                    _lpAddress,
                    _lockId,
                    true,
                    tempListing,
                    currentAuction.topEthBid.bidder
                );

                _returnBid(
                    _lpAddress,
                    _lockId,
                    false,
                    tempListing,
                    currentAuction.topFlocksBid.bidder
                );
            } else if (currentAuction.topEthBid.ethBid > 0) {
                _returnBid(
                    _lpAddress,
                    _lockId,
                    true,
                    tempListing,
                    currentAuction.topEthBid.bidder
                );
            } else if (currentAuction.topFlocksBid.flocksBid > 0) {
                _returnBid(
                    _lpAddress,
                    _lockId,
                    false,
                    tempListing,
                    currentAuction.topFlocksBid.bidder
                );
            }
        }

        if (tempListing.isActive) {
            lpToLockID[_lpAddress][_lockId].isActive = false;
            activeListings--;
        }

        uniswapV2Locker.transferLockOwnership(
            _lpAddress,
            index,
            _lockId,
            payable(msg.sender)
        );

        emit ListingWithdrawn(_lpAddress, _lockId);
    }

    /// @notice Verify a listing as safe
    /// @dev Only dev can verify listings
    /// @param _lpAddress Address of the LP token
    /// @param _lockID Unique lock ID (per lpAdress) of the lock
    /// @param status Status of verification
    function verifyListing(
        address _lpAddress,
        uint256 _lockID,
        bool status
    ) external onlyOwner {
        Listing storage tempListing = lpToLockID[_lpAddress][_lockID];
        require(status != tempListing.isVerified, "Must change listing status");
        tempListing.isVerified = true;
        emit LockVerified(_lpAddress, _lockID, status);
    }

    /// @notice Change the ETH price of a listing
    /// @dev Only seller can change price
    /// @param _lpAddress Address of the LP token
    /// @param _lockID Unique lock ID (per lpAddress) of the lock
    /// @param newPriceInETH Updated ETH price of listing
    function changePriceInETH(
        address _lpAddress,
        uint256 _lockID,
        uint256 newPriceInETH
    ) external nonReentrant {
        Listing storage tempListing = lpToLockID[_lpAddress][_lockID];
        require(
            tempListing.seller == msg.sender,
            "This listing does not belong to you."
        );
        tempListing.priceInETH = newPriceInETH;
    }

    /// @notice Change the price of a listing in Flocks
    /// @dev Only seller can change price
    /// @param _lpAddress Address of the LP token
    /// @param _lockID Unique lock ID (per lpAddress) of the lock
    /// @param newPriceInFlocks Updated Flocks price of listing
    function changePriceInFlocks(
        address _lpAddress,
        uint256 _lockID,
        uint256 newPriceInFlocks
    ) external nonReentrant {
        Listing storage tempListing = lpToLockID[_lpAddress][_lockID];
        require(
            tempListing.seller == msg.sender,
            "This listing does not belong to you."
        );
        tempListing.priceInFlocks = newPriceInFlocks;
    }

    /// @notice Return ownership of a lock to the original seller and remove the listing
    /// @dev Only the contract owner can call this function
    /// @param _lpAddress Address of the LP token associated with the lock
    /// @param _lockId The ID of the lock to be redacted
    function redactListing(
        address _lpAddress,
        uint256 _lockId
    ) external onlyOwner {
        Listing storage _tempListing = lpToLockID[_lpAddress][_lockId];

        require(_tempListing.seller != address(0), "Listing does not exist.");

        (bool lockFound, uint256 index) = _getIndex(_lpAddress, _tempListing);
        require(lockFound, "Lock not found.");

        if (_tempListing.forAuction) {
            AuctionDetails memory currentAuction = auctions[
                _tempListing.auctionIndex
            ];

            if (
                currentAuction.topFlocksBid.flocksBid > 0 &&
                currentAuction.topEthBid.ethBid > 0
            ) {
                _returnBid(
                    _lpAddress,
                    _lockId,
                    true,
                    _tempListing,
                    currentAuction.topEthBid.bidder
                );

                _returnBid(
                    _lpAddress,
                    _lockId,
                    false,
                    _tempListing,
                    currentAuction.topFlocksBid.bidder
                );
            } else if (currentAuction.topEthBid.ethBid > 0) {
                _returnBid(
                    _lpAddress,
                    _lockId,
                    true,
                    _tempListing,
                    currentAuction.topEthBid.bidder
                );
            } else if (currentAuction.topFlocksBid.flocksBid > 0) {
                _returnBid(
                    _lpAddress,
                    _lockId,
                    false,
                    _tempListing,
                    currentAuction.topFlocksBid.bidder
                );
            }
        }

        uniswapV2Locker.transferLockOwnership(
            _lpAddress,
            index,
            _lockId,
            _tempListing.seller
        );

        if (_tempListing.isActive) {
            _tempListing.isActive = false;
            activeListings--;
        }

        delete lpToLockID[_lpAddress][_lockId];
        emit ListingRedacted(_lpAddress, _lockId, _tempListing.seller);
    }
}