// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./openzeppelin_contracts_access_Ownable.sol";
import "./openzeppelin_contracts_token_ERC20_ERC20.sol";
import "./contracts_token_Bean.sol";
import "./contracts_cfa_interface_IReferral.sol";
import "./contracts_utils_Registry.sol";

contract Referral is Ownable, IReferral {
    // Local Variables
    Registry public registry;

    uint256[] public amtReferredBracket;
    uint256[][] public interestSet;
    uint256[] public supplyMarkers;
    uint256[] public referredRewardRates;
    address public defaultReferrer;
    bool _interestSet;

    mapping(address => Referrer) public referrer;
    mapping(address => bool) public isRegistered;

    // Events
    event ReferralRecorded(address indexed user, address indexed referrer);
    event ReferralRemoved(address indexed user);

    // Constructor
    constructor() Ownable(msg.sender) {
        supplyMarkers = new uint256[](11);
        referredRewardRates = new uint256[](11);
    }

    // Modifiers
    modifier onlyRegistered() {
        require(isRegistered[msg.sender], "Referral: Not authorized");
        _;
    }

    // Write Functions
    /**
     * @dev Used to set referrer to a new user
     */
    function addReferrer(
        address _referred,
        address _referrer
    ) external onlyRegistered {
        require(
            referrer[_referred].referrer == address(0),
            "Referral: Referrer already set"
        );
        require(
            _referrer != _referred,
            "Referral: Cannot set referrer to yourself"
        );
        require(
            !isReferral(_referrer, _referred),
            "Referral: Circular referral not allowed"
        );
        require(!isContract(_referrer), "Referral: Referrer is not a wallet");

        referrer[_referrer].referrals.push(_referred);
        referrer[_referrer].referralCount++;
        referrer[_referred].wasReferred = true;
        referrer[_referred].referrer = _referrer;
        emit ReferralRecorded(_referred, _referrer);
    }

    /**
     * @dev Used to remove referrer from a user
     */
    function removeReferrer(address _user) external onlyOwner {
        require(referrer[_user].referrer != address(0), "002");

        for (
            uint256 i = 0;
            i < referrer[referrer[_user].referrer].referrals.length;
            i++
        ) {
            if (referrer[referrer[_user].referrer].referrals[i] == _user) {
                referrer[referrer[_user].referrer].referrals[i] = referrer[
                    referrer[_user].referrer
                ].referrals[
                        referrer[referrer[_user].referrer].referrals.length - 1
                    ];
                referrer[referrer[_user].referrer].referrals.pop();
                break;
            }
        }

        referrer[referrer[_user].referrer].referralCount--;
        referrer[_user].wasReferred = false;
        delete referrer[_user].referrer;

        emit ReferralRemoved(_user);
    }

    /**
     * @dev Used to set interest rates
     */
    function setInterestRate(
        uint256[][] memory _newInterestSet
    ) external onlyOwner {
        require(_newInterestSet.length > 0, "Referral: Empty array");

        interestSet = new uint256[][](_newInterestSet.length);
        _interestSet = true;
        for (uint256 i = 0; i < _newInterestSet.length; i++) {
            require(_newInterestSet[i].length > 0, "Referral: Empty sub-array");
            interestSet[i] = _newInterestSet[i];
        }
    }

    function setSupplyMarkers(uint256[] memory _markers) external onlyOwner {
        require(_markers.length > 0, "Referral: Empty markers array");

        // Iterate through the supplied markers to set supplyMarkers and update supplyMarkerSize
        for (uint256 i = 0; i < _markers.length; i++) {
            supplyMarkers[i] = _markers[i];
        }
    }

    function setReferredRewards(uint256[] memory _rewards) external onlyOwner {
        require(_rewards.length > 0, "Referral: Empty markers array");

        for (uint256 i = 0; i < _rewards.length; i++) {
            referredRewardRates[i] = _rewards[i];
        }
    }

    function setRegisteredContracts(address _contract) external onlyOwner {
        isRegistered[_contract] = true;
    }

    function setAmtReferredBracket(
        uint256[] memory _amtReferredBracket
    ) external onlyOwner {
        require(_amtReferredBracket.length > 0, "Referral: Empty array");

        amtReferredBracket = _amtReferredBracket;
    }

    function setRegistry(Registry _registry) external onlyOwner {
        registry = _registry;
    }

    /**
     * @dev Used to return rewards to the referrer
     */
    function rewardForReferrer(
        address _sender,
        uint256 amount
    ) external onlyRegistered {
        require(referredRewardRates.length != 0, "referredRewardRates not set");
        require(supplyMarkers.length != 0, "supplyMarkers not set");
        require(amtReferredBracket.length != 0, "supplyMarkers not set");
        require(_interestSet, "interest not set");

        referrer[_sender].buyCount++;
        address _referrer = referrer[_sender].referrer;
        uint256 returnRate = getUserInterest(_sender);
        uint256 reward = (amount * returnRate) / 10000;
        Bean token = Bean(registry.getContractAddress("Bean"));
        token.mint(_referrer, reward);
        referrer[_referrer].rewarded += reward;
    }

    // View Functions
    /**
     * @dev Used to get the marker for the current supply
     */

    function isContract(
        address addr
    ) internal view returns (bool isContractBool) {
        uint size;
        assembly {
            size := extcodesize(addr)
        }
        isContractBool = size > 0;
    }

    function getMarker() public view returns (uint256) {
        uint256 totalSupply = IERC20(registry.getContractAddress("Bean"))
            .totalSupply();
        uint256 supplyMarker = 0;

        if (totalSupply > supplyMarkers[supplyMarkers.length - 1]) {
            return supplyMarkers.length - 1;
        }

        for (uint256 index = 0; index < supplyMarkers.length - 1; index++) {
            if (
                totalSupply > supplyMarkers[index] &&
                totalSupply <= supplyMarkers[index + 1]
            ) {
                supplyMarker = index;
                break;
            }
        }

        return supplyMarker;
    }

    /**
     * @dev Used to get the interest marker for a user
     */
    function getUsersInterestMarker(
        address _referrer
    ) public view returns (uint256) {
        uint256 referredCount = referrer[_referrer].referralCount;

        uint256 bracketIndex = 0;
        while (
            bracketIndex < amtReferredBracket.length &&
            referredCount >= amtReferredBracket[bracketIndex]
        ) {
            bracketIndex++;
        }
        require(
            bracketIndex < interestSet.length,
            "Referral: Invalid bracket index"
        );
        return bracketIndex;
    }

    function eligibleForReward(address _referrer) external view returns (bool) {
        if (
            referrer[_referrer].buyCount < 10 &&
            referrer[_referrer].referrer != address(0)
        ) {
            return true;
        } else {
            return false;
        }
    }

    function isReferral(
        address _referral,
        address _referrer
    ) internal view returns (bool) {
        uint256 referralCount = referrer[_referrer].referralCount;
        for (uint256 i = 0; i < referralCount; i++) {
            address referredAddress = referrer[_referrer].referrals[i];
            if (referredAddress == _referral) {
                return true;
            }
        }
        return false;
    }

    function getAttributes(
        address _address
    ) external view returns (Referrer memory) {
        Referrer memory _attributes = referrer[_address];
        return _attributes;
    }

    /**
     * @dev Used to get the interest rate for a user
     */
    function getUserInterest(
        address _referrer
    ) internal view returns (uint256) {
        uint256 globalMarker = getMarker();
        uint256[] memory interestBracket = interestSet[globalMarker];

        uint256 userMarker = getUsersInterestMarker(_referrer);
        uint256 userInterest = interestBracket[userMarker];

        return userInterest;
    }

    function checkReferrals(
        address _address
    ) external view returns (address[] memory) {
        address[] memory _referrals = referrer[_address].referrals;
        return _referrals;
    }

    function getReferredDiscount() external view returns (uint256) {
        uint256 _getMarker = getMarker();
        uint256 reward = referredRewardRates[_getMarker];
        return reward;
    }

    function yourReferrer(address _user) external view returns (address) {
        return referrer[_user].referrer;
    }

    function discountLeft(address _user) external view returns (uint256) {
        return 10 - referrer[_user].buyCount;
    }

    function totalRewardsReceived(
        address _user
    ) external view returns (uint256) {
        return referrer[_user].rewarded;
    }

    function getDiscountedPrice(
        uint256 _principal
    ) external view returns (uint256) {
        uint256 _getMarker = getMarker();
        uint256 reward = referredRewardRates[_getMarker];
        uint256 _discountedPrice = (_principal * reward) / 10000;
        return _discountedPrice;
    }
    // function hasBeenReferred() external view returns (bool) {
    //   if (referrer[msg.sender].referrer != address(0)) {
    //     return false;
    //   } else {
    //     return true;
    //   }
    // }

    // Debug functions
    // function getInterestSet() external view returns (uint256[] memory) {
    //   uint256 globalMarker = getMarker();
    //   uint256[] memory interestBracket = interestSet[globalMarker];
    //   return interestBracket;
    // }

    // function increaseeferralCount(uint256 impostor) public {
    //   referrer[msg.sender].referralCount += impostor;
    // }

    // function checkCurrentBracket() public view returns (uint256[] memory) {
    //   uint256 globalMarker = getMarker();
    //   uint256[] memory interestBracket = interestSet[globalMarker];

    //   return interestBracket;
    // }

    // function checkSupply() public view returns (uint256) {
    //   uint256 supply = IERC20(registry.getContractAddress('Bean')).totalSupply();
    //   return supply;
    // }
}