// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "./openzeppelin_contracts_access_AccessControl.sol";

contract WINTokenProductsConfig is AccessControl {
    struct ProductLimits {
        uint256 startDate;
        uint256 endDate;
    }

    bytes32 public constant FACTORY_ADMIN = keccak256("FACTORY_ADMIN");

    ProductLimits public defaultLimits;

    mapping(uint256 => uint256) public maxSupply;
    mapping(uint256 => ProductLimits) public productLimits;

    modifier onlyFactoryAdmin() {
        require(
            hasRole(FACTORY_ADMIN, msg.sender),
            "Restricted to FACTORY_ADMIN role"
        );
        _;
    }

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function getProductLimits(
        uint256 _id
    ) public view returns (ProductLimits memory) {
        if (productLimits[_id].startDate != uint256(0)) {
            return productLimits[_id];
        }

        return defaultLimits;
    }

    function editProductLimits(
        uint256 _id,
        uint256 startDate,
        uint256 endDate
    ) public onlyFactoryAdmin {
        uint256 currentStartDate = productLimits[_id].startDate;

        require(
            currentStartDate == uint256(0) ||
                block.timestamp < currentStartDate,
            "Already started"
        );

        productLimits[_id] = ProductLimits(startDate, endDate);
    }

    function editDefaultProductLimits(
        uint256 startDate,
        uint256 endDate
    ) public onlyFactoryAdmin {
        defaultLimits = ProductLimits(startDate, endDate);
    }

    function getMaxSupply(uint256 _id) public view returns (uint256) {
        return maxSupply[_id];
    }

    function editMaxSupply(uint256 _id, uint256 value) public onlyFactoryAdmin {
        maxSupply[_id] = value;
    }

    function requireNotFull(
        uint256 currentSupply,
        uint256 _id,
        uint256 _amount
    ) public view {
        require(
            maxSupply[_id] == 0 || currentSupply < maxSupply[_id],
            "Product max supply reached"
        );
        require(
            maxSupply[_id] == 0 || currentSupply + _amount <= maxSupply[_id],
            "Cannot generate that amount of tokens"
        );
    }

    function requireActive(uint256 _id) public view {
        uint256 startDate = productLimits[_id].startDate > uint256(0)
            ? productLimits[_id].startDate
            : defaultLimits.startDate;

        uint256 endDate = productLimits[_id].endDate > uint256(0)
            ? productLimits[_id].endDate
            : defaultLimits.endDate;

        require(
            startDate == uint256(0) || block.timestamp > startDate,
            "Not started yet"
        );
        require(
            endDate == uint256(0) || block.timestamp < endDate,
            "Already ended"
        );
    }
}