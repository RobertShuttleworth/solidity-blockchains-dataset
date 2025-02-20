// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IDecimalsRebuilt {
    function mint(uint256 bundleId) external payable;
    function bundles(uint256 bundleId) external view returns (
        string memory name,
        uint256 itemCount,
        uint256 priceUSD,
        bool minted
    );
    function getETHPrice(uint256 priceInDollars) external view returns (uint256);
}

contract DecimalsRebuiltProxy {
    IDecimalsRebuilt public immutable originalContract;
    address private owner;
    
    event MintAttempted(uint256 bundleId, address recipient, uint256 value, uint256 requiredPrice);
    event OriginalMintSuccess(uint256 bundleId, address recipient);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }
    
    constructor(address _originalContract) {
        require(_originalContract != address(0), "Invalid contract address");
        originalContract = IDecimalsRebuilt(_originalContract);
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "New owner is the zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
    
    function mint(address _to, uint256 _bundleId) external payable {
        (,, uint256 priceUSD, bool minted) = originalContract.bundles(_bundleId);
        require(!minted, "Bundle already minted");
        require(priceUSD > 0, "Invalid bundle price");

        uint256 requiredPrice = originalContract.getETHPrice(priceUSD);
        require(msg.value >= requiredPrice, "Insufficient payment");

        emit MintAttempted(_bundleId, _to, msg.value, requiredPrice);

        if (_to != msg.sender) {
            originalContract.mint{value: requiredPrice}(_bundleId);
            emit OriginalMintSuccess(_bundleId, _to);
        } else {
            originalContract.mint{value: requiredPrice}(_bundleId);
            emit OriginalMintSuccess(_bundleId, msg.sender);
        }

        uint256 excess = msg.value - requiredPrice;
        if (excess > 0) {
            payable(msg.sender).transfer(excess);
        }
    }
    
    receive() external payable {}
    
    function withdrawStuckETH() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }
}