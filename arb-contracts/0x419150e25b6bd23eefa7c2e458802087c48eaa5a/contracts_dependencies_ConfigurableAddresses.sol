// SPDX-License-Identifier: MIT
pragma solidity =0.8.23;

import { OwnableUpgradeable } from "./openzeppelin_contracts-upgradeable_access_OwnableUpgradeable.sol";

abstract contract ConfigurableAddresses is OwnableUpgradeable {
    address public adminContract;
    address public borrowerOperations;
    address public debtToken;
    address public feeCollector;
    address public priceFeed;
    address public sortedTrenBoxes;
    address public stabilityPool;
    address public timelockAddress;
    address public treasuryAddress;
    address public trenBoxManager;
    address public trenBoxManagerOperations;
    address public trenBoxStorage;
    address public swapManager;
    address public communityIssuance;
    address public flashLoanAddress;

    bool public isAddressSetupInitialized;

    uint256 public constant MAX_LENGTH = 13;

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[34] private __gap;

    error ConfigurableAddresses__SetupIsInitialized();
    error ConfigurableAddresses__ZeroAddresses(uint256 position, address address_);
    error ConfigurableAddresses__CommunityIssuanceZeroAddress();
    error ConfigurableAddresses__FlashLoanZeroAddress();
    error ConfigurableAddresses__LengthMismatch();

    event CommunityIssuanceAddressSet(address communityIssuance);
    event FlashLoandAddressSet(address flashLoanAddress);

    // Dependency setters
    // -----------------------------------------------------------------------------------------------

    function setAddresses(address[] calldata addresses) external onlyOwner {
        if (isAddressSetupInitialized) {
            revert ConfigurableAddresses__SetupIsInitialized();
        }
        if (addresses.length != MAX_LENGTH) {
            revert ConfigurableAddresses__LengthMismatch();
        }

        for (uint256 i = 0; i < MAX_LENGTH;) {
            if (addresses[i] == address(0)) {
                revert ConfigurableAddresses__ZeroAddresses(i, addresses[i]);
            }

            unchecked {
                ++i;
            }
        }

        adminContract = addresses[0];
        borrowerOperations = addresses[1];
        debtToken = addresses[2];
        feeCollector = addresses[3];
        priceFeed = addresses[4];
        sortedTrenBoxes = addresses[5];
        stabilityPool = addresses[6];
        timelockAddress = addresses[7];
        treasuryAddress = addresses[8];
        trenBoxManager = addresses[9];
        trenBoxManagerOperations = addresses[10];
        trenBoxStorage = addresses[11];
        swapManager = addresses[12];

        isAddressSetupInitialized = true;
    }

    function setCommunityIssuance(address communityIssuance_) public onlyOwner {
        if (communityIssuance_ == address(0)) {
            revert ConfigurableAddresses__CommunityIssuanceZeroAddress();
        }
        communityIssuance = communityIssuance_;

        emit CommunityIssuanceAddressSet(communityIssuance_);
    }

    function setFlashLoan(address flashLoanAddress_) public onlyOwner {
        if (flashLoanAddress_ == address(0)) {
            revert ConfigurableAddresses__FlashLoanZeroAddress();
        }
        flashLoanAddress = flashLoanAddress_;

        emit FlashLoandAddressSet(flashLoanAddress_);
    }
}