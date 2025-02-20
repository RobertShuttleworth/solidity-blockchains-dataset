// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "./openzeppelin_contracts_utils_cryptography_ECDSA.sol";
import "./openzeppelin_contracts_token_ERC20_IERC20.sol";

contract CoinCrusade {
    /* Error Codes
    SNP = "Sender not player"
    DAP = "Data already processed"
    IS = "Invalid signature"
    AGZ = "Percentage amount greater than zero"
    SNA = "Sender not allowed"
    TTF = "Token transfer failed"
    EXP = "Signature Expired"
    */

    using ECDSA for bytes32;

    mapping(bytes32 => bool) public usedHashes;
    address public adminAddress;
    address public chainWarsAddress;
    uint256 public contractBalance;
    address public erc20Address;

    event Buy(uint256 noOfCoins, uint256 amount, address buyer);
    event Sell(uint256 noOfCoins, uint256 amount, address buyer);

    constructor(
        address _adminAddress,
        address _chainWarsAddress,
        address _erc20Address
    ) {
        adminAddress = _adminAddress;
        chainWarsAddress = _chainWarsAddress;
        erc20Address = _erc20Address;
    }

    struct BuyCoin {
        uint256 noOfCoins;
        uint256 amount;
        uint256 timeStamp;
        address buyer;
    }

    struct SellCoin {
        uint256 noOfCoins;
        uint256 amount;
        uint256 timeStamp;
        address seller;
    }

    function buyCoin(BuyCoin calldata _buyCoinStruct, bytes calldata signature)
        public
    {
        require(block.timestamp < _buyCoinStruct.timeStamp, "EXP");
        require(msg.sender == _buyCoinStruct.buyer, "SNP");
        bytes32 _hash = keccak256(
            abi.encode(
                _buyCoinStruct.noOfCoins,
                _buyCoinStruct.amount,
                _buyCoinStruct.timeStamp,
                _buyCoinStruct.buyer,
                "BUY"
            )
        );
        require(!usedHashes[_hash], "DAP");
        require(recover((_hash), signature) == adminAddress, "IS");
        require(
            IERC20(erc20Address).transferFrom(
                msg.sender,
                address(this),
                _buyCoinStruct.amount
            ),
            "TTF"
        );
        usedHashes[_hash] = true;
        emit Buy(
            _buyCoinStruct.noOfCoins,
            _buyCoinStruct.amount,
            _buyCoinStruct.buyer
        );
    }

    function sellCoin(
        SellCoin calldata _sellCoinStruct,
        bytes calldata signature
    ) public {
        require(block.timestamp < _sellCoinStruct.timeStamp, "EXP");
        require(msg.sender == _sellCoinStruct.seller, "SNP");
        bytes32 _hash = keccak256(
            abi.encode(
                _sellCoinStruct.noOfCoins,
                _sellCoinStruct.amount,
                _sellCoinStruct.timeStamp,
                _sellCoinStruct.seller,
                "SELL"
            )
        );
        require(!usedHashes[_hash], "DAP");
        require(recover((_hash), signature) == adminAddress, "IS");
        require(
            IERC20(erc20Address).transfer(
                _sellCoinStruct.seller,
                _sellCoinStruct.amount
            ),
            "TTF"
        );

        usedHashes[_hash] = true;
        emit Sell(
            _sellCoinStruct.noOfCoins,
            _sellCoinStruct.amount,
            _sellCoinStruct.seller
        );
    }

    function withdrawAmount(uint256 amount) public {
        require(msg.sender == chainWarsAddress, "SNA");
        require(amount <= IERC20(erc20Address).balanceOf(address(this)), "NEB");
        require(IERC20(erc20Address).transfer(chainWarsAddress, amount), "TTF");
    }

    receive() external payable {}

    function recover(bytes32 hash, bytes memory sig)
        private
        pure
        returns (address)
    {
        hash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", hash)
        );
        return ECDSA.recover(hash, sig);
    }
}