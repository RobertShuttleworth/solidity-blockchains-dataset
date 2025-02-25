// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import "./contracts_utils_Registry.sol";
import "./openzeppelin_contracts-upgradeable_access_OwnableUpgradeable.sol";
import "./contracts_token_Bean.sol";

contract GlobalMarker is OwnableUpgradeable {
    Registry public registry;

    uint256 markerSize;
    uint256[] public markers;
    uint256[] public interests;
    bool interestsSet;

    function initialize(Registry _registry) public initializer {
        __Ownable_init(msg.sender);
        registry = _registry;
        markers = new uint256[](41);
        interests = new uint256[](41);
    }

    function setInterest(
        uint256[] memory _marker,
        uint256[] memory _interest
    ) external onlyOwner {
        require(
            _marker.length == _interest.length,
            "GlobalMarker: Marker and interest length should be equal"
        );
        interestsSet = true;
        uint256 _markerSize;
        for (uint256 i = 0; i < _marker.length; i++) {
            markers[i] = _marker[i];
            interests[i] = _interest[i];
            _markerSize++;
        }
        markerSize = _markerSize;
    }

    function getMarker() public view returns (uint256) {
        require(interestsSet, "GlobalMarker: Marker & Interest not yet set");
        uint256 totalSupply = IERC20(registry.getContractAddress("Bean"))
            .totalSupply();
        uint256 marker = 0;

        if (totalSupply > markers[markerSize - 1]) {
            return markerSize - 1;
        } else {
            for (uint256 index = 0; index < markers.length - 1; index++) {
                if (
                    totalSupply >= markers[index] &&
                    totalSupply < markers[index + 1]
                ) {
                    marker = index;
                    return marker;
                }
            }
        }
    }

    function getInterestRate() external view returns (uint256) {
        // Interests should be ready to be divided by 10000
        require(interestsSet, "GlobalMarker: Marker & Interest not yet set");
        uint256 marker = getMarker();
        return interests[marker];
    }

    function setRegistry(Registry _registry) external onlyOwner {
        registry = _registry;
    }

    function isInterestSet() external view returns (bool) {
        bool _interestsSet = interestsSet;
        return _interestsSet;
    }
}