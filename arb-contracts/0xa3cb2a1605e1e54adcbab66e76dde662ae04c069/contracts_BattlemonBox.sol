// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "./openzeppelin_contracts-upgradeable_access_OwnableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";
import {VRFV2PlusWrapperConsumerBase} from "./contracts_chainlink_VRFV2PlusWrapperConsumerBase.sol";
import {VRFV2PlusClient} from "./contracts_chainlink_VRFV2PlusClient.sol";


import "./openzeppelin_contracts_interfaces_IERC20.sol";
import "./contracts_interfaces_IERC721Mintable.sol";
import "./contracts_interfaces_IBattlemonStickers.sol";
import "./contracts_interfaces_IBattlemonItems.sol";
import "./contracts_interfaces_IBattlemonPickaxe.sol";
import "./contracts_interfaces_IBattlemonPoints.sol";
import "./contracts_interfaces_IBattlemon.sol";
import "./contracts_interfaces_IBattlemonReferral.sol";
import "./contracts_BattlemonLineaPark.sol";
import "./contracts_interfaces_IBattlemonGoldenKey.sol";

// sticker = 0
// COIN small = 100
// COIN medium = 101
// COIN large = 102
// Point small = 200
// Point medium = 201
// Point large = 202
// Points for lemon = 210
// Points for item = 211
// Pickaxe cheap = 400
// Pickaxe good = 401
// Pickaxe great = 402
// Item = 500
// Lemon = 600

contract BattlemonBox is Initializable, OwnableUpgradeable, VRFV2PlusWrapperConsumerBase {
    event Prize(uint boxType, uint requestId, address winner, uint prizeId);
    event NewPurchase(address buyer, uint boxType, uint requestId);
    event CallFailed(address to, uint256 value);

    uint256 private _randNonce;

    address public lemons;
    address public stickers;
    address public items;
    address public pickaxe;
    address public points;
    address public tresuary;

    uint256 public CHEAP_BOX_PRICE;
    uint256 public GOOD_BOX_PRICE;
    uint256 public GREAT_BOX_PRICE;

    uint256 public MAX_ITEMS_AMOUNT;
    uint256 public MAX_LEMONS_AMOUNT;

    uint256 public lemonsMinted;
    uint256 public itemsMinted;

    uint256 public smallAmount;
    uint256 public mediumAmount;
    uint256 public largeAmount; // coming soon

    address public referrals;

    address public airnodeAddress; /// The address of the QRNG Airnode
    bytes32 public endpointIdUint256; /// The endpoint ID for requesting a single random number

    mapping(uint => Request) public requests;

    struct Request {
        address sender;
        bool pending;
        int boxType;
    }

    // v2 fields
    uint256 public BATTLE_BOX_PRICE;
    address public keys;
    address public lineaPark;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _tresuary,
        address _wrapperAddress, //TODO !!! 0x14632CD5c12eC5875D41350B55e825c54406BaaB FOR ARB MAIN, 0x29576aB8152A09b9DC634804e4aDE73dA1f3a3CC FOR TESTNET
        uint[] calldata amounts,
        uint[] calldata prices
    ) public initializer {
        __Ownable_init();
        __init_VRFV2PlusWrapperConsumerBase(_wrapperAddress);
        require(amounts.length == 2, "Box: wrong length");
        smallAmount = amounts[0];
        mediumAmount = amounts[1];
        tresuary = _tresuary;

        CHEAP_BOX_PRICE = prices[0];
        GOOD_BOX_PRICE = prices[1];
        GREAT_BOX_PRICE = prices[2];

        MAX_ITEMS_AMOUNT = 11111;
        MAX_LEMONS_AMOUNT = 1111;
    }

    function buyBattleBox(uint tokenId, bool buyWithKey) public payable {
        require(msg.value == BATTLE_BOX_PRICE, "Box: Wrong msg.value"); // 0.15$
        // Buy for linea park nft
        if (!buyWithKey) {
            require(
                BattlemonLineaPark(lineaPark).ownerOf(tokenId) == msg.sender,
                "Box: Not token owner"
            );
            BattlemonLineaPark(lineaPark).transferFrom(
                msg.sender,
                address(this),
                tokenId
            );
        }

        // Buy for key
        if (buyWithKey) {
            require(
                IBattlemonGoldenKey(keys).openBattleBox(tokenId, msg.sender),
                "Box: Can't open battle box with key"
            );
        }

        (uint requestId, ) = _requestRandomWord();
        
        requests[requestId].pending = true;
        requests[requestId].sender = msg.sender;
        requests[requestId].boxType = 1;
        uint value = _rewardReferree(msg.sender, msg.value); //90%

        emit NewPurchase(msg.sender, 3, requestId);
    }

    function buyCheapBox() public payable {
        require(msg.value == CHEAP_BOX_PRICE, "Box: Wrong msg.value");
        (uint requestId, ) = _requestRandomWord();

        requests[requestId].pending = true;
        requests[requestId].sender = msg.sender;
        requests[requestId].boxType = 2;
        uint value = _rewardReferree(msg.sender, msg.value); //90%

        emit NewPurchase(msg.sender, 0, requestId);
    }

    function buyGoodBox() public payable {
        require(msg.value == GOOD_BOX_PRICE, "Box: Wrong msg.value");
        (uint requestId, ) = _requestRandomWord();

        requests[requestId].pending = true;
        requests[requestId].sender = msg.sender;
        requests[requestId].boxType = 3;
        uint value = _rewardReferree(msg.sender, msg.value);

        emit NewPurchase(msg.sender, 1, requestId);
    }

    function buyGreatBox() public payable {
        require(msg.value == GREAT_BOX_PRICE, "Box: Wrong msg.value");
        (uint requestId, ) = _requestRandomWord();

        requests[requestId].pending = true;
        requests[requestId].sender = msg.sender;
        requests[requestId].boxType = 4;
        uint value = _rewardReferree(msg.sender, msg.value);

        emit NewPurchase(msg.sender, 2, requestId);
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        Request memory req = requests[requestId];
        if(req.boxType == 1) {
            _buyBattleBoxCallback(requestId, randomWords[0]);
        }
        if(req.boxType == 2) {
            _buyCheapBoxCallback(requestId, randomWords[0]);
        }
        if(req.boxType == 3) {
            _buyGoodBoxCallback(requestId, randomWords[0]);
        }
        if(req.boxType == 4) {
            _buyGreatBoxCallback(requestId, randomWords[0]);
        }
    }

    function _buyBattleBoxCallback(
        uint requestId,
        uint data
    ) private {
        require(
            requests[requestId].pending == true,
            "Box: Request finished or doesn't exist"
        );
        requests[requestId].pending = false;
        uint256 r = (data % 100_0000) + 1;
        address sender = requests[requestId].sender;
        address referree = IBattlemonReferral(referrals).getUserRef(sender);

        // Always
        sendPoints(sender, referree, 3 ether);

        // 60%
        if (r <= 60_0000) {
            sendPoints(sender, referree, 25 ether);
            emit Prize(0, requestId, sender, 200);
            return;
        }
        // 35%
        if (r > 60_0000 && r <= 95_0000) {
            sendPoints(sender, referree, 50 ether);
            emit Prize(0, requestId, sender, 201);
            return;
        }
        // 1$
        if (r > 95_0000 && r <= 96_0000) {
            IBattlemonStickers(stickers).mint(sender, 1);
            emit Prize(0, requestId, sender, 0);
            return;
        }
        // 1%
        if (r > 96_0000 && r <= 97_0000) {
            if (lemonsMinted + 1 > MAX_LEMONS_AMOUNT) {
                sendPoints(sender, referree, 200 ether);
                emit Prize(2, requestId, sender, 210);
                return;
            }
            IBattlemon(lemons).boxMint(sender);
            lemonsMinted++;
            emit Prize(2, requestId, sender, 600);
            return;
        }
        // 2.99%
        if (r > 97_0000 && r <= 99_9900) {
            IBattlemonPickaxe(pickaxe).boxMint(sender, 0);
            emit Prize(0, requestId, sender, 400);
            return;
        }
        // 0.01%
        if (r > 99_9900) {
            sender.call{value: smallAmount}("");
            emit Prize(0, requestId, sender, 100);
            return;
        }
    }

    function _buyCheapBoxCallback(
        uint requestId,
        uint data
    ) private {
        require(
            requests[requestId].pending == true,
            "Box: Request finished or doesn't exist"
        );
        requests[requestId].pending = false;
        uint256 r = (data % 100) + 1;
        address sender = requests[requestId].sender;
        address referree = IBattlemonReferral(referrals).getUserRef(sender);

        // 50%
        if (r <= 50) {
            sendPoints(sender, referree, 25 ether);
            emit Prize(0, requestId, sender, 200);
            return;
        }
        // 25%
        if (r > 50 && r <= 75) {
            IBattlemonStickers(stickers).mint(sender, 1);
            emit Prize(0, requestId, sender, 0);
            return;
        }
        // 24%
        if (r > 75 && r < 100) {
            IBattlemonPickaxe(pickaxe).boxMint(sender, 0);
            emit Prize(0, requestId, sender, 400);
            return;
        }
        // 1%
        if (r == 100) {
            sender.call{value: smallAmount}("");
            emit Prize(0, requestId, sender, 100);
            return;
        }
    }

    function _buyGoodBoxCallback(
        uint requestId,
        uint data
    ) private {
        require(
            requests[requestId].pending == true,
            "Box: Request finished or doesn't exist"
        );
        requests[requestId].pending = false;
        address sender = requests[requestId].sender;
        uint256 r = (data % 100) + 1;
        address referree = IBattlemonReferral(referrals).getUserRef(sender);

        // 10%
        if (r <= 10) {
            IBattlemonStickers(stickers).mint(sender, 1);
            emit Prize(1, requestId, sender, 0);
            return;
        }
        // 15%
        if (r >= 11 && r <= 25) {
            if (itemsMinted + 1 > MAX_ITEMS_AMOUNT) {
                sendPoints(sender, referree, 50 ether);
                emit Prize(1, requestId, sender, 211);
                return;
            }
            IBattlemonItems(items).rewardMint(sender, 1);
            itemsMinted++;
            emit Prize(1, requestId, sender, 500);
            return;
        }
        // 8%
        if (r >= 26 && r <= 33) {
            sender.call{value: smallAmount}("");
            emit Prize(1, requestId, sender, 100);
            return;
        }
        // 5%
        if (r >= 34 && r <= 38) {
            sender.call{value: mediumAmount}("");
            emit Prize(1, requestId, sender, 101);
            return;
        }
        // 26%
        if (r >= 39 && r <= 64) {
            sendPoints(sender, referree, 25 ether);
            emit Prize(1, requestId, sender, 200);
            return;
        }
        // 18%
        if (r >= 65 && r <= 82) {
            sendPoints(sender, referree, 50 ether);
            emit Prize(1, requestId, sender, 201);
            return;
        }
        // 18%
        if (r >= 83) {
            IBattlemonPickaxe(pickaxe).boxMint(sender, 1);
            emit Prize(1, requestId, sender, 401);
            return;
        }
    }

    function _buyGreatBoxCallback(
        uint requestId,
        uint data
    ) private {
        require(
            requests[requestId].pending == true,
            "Box: Request finished or doesn't exist"
        );
        requests[requestId].pending = false;
        address sender = requests[requestId].sender;
        uint256 r = (data % 100) + 1;
        address referree = IBattlemonReferral(referrals).getUserRef(sender);

        // 25%
        if (r <= 25) {
            if (lemonsMinted + 1 > MAX_LEMONS_AMOUNT) {
                sendPoints(sender, referree, 200 ether);
                emit Prize(2, requestId, sender, 210);
                return;
            }
            IBattlemon(lemons).boxMint(sender);
            lemonsMinted++;
            emit Prize(2, requestId, sender, 600);
            return;
        }
        // 20%
        if (r >= 26 && r <= 45) {
            if (itemsMinted + 1 > MAX_ITEMS_AMOUNT) {
                sendPoints(sender, referree, 50 ether);
                emit Prize(2, requestId, sender, 211);
                return;
            }
            IBattlemonItems(items).rewardMint(sender, 1);
            itemsMinted++;
            emit Prize(2, requestId, sender, 500);
            return;
        }
        // 15%
        if (r >= 46 && r <= 60) {
            sender.call{value: mediumAmount}("");
            emit Prize(2, requestId, sender, 101);
            return;
        }
        // 5%
        if (r >= 61 && r <= 65) {
            sendPoints(sender, referree, 50 ether);
            emit Prize(2, requestId, sender, 201);
            return;
        }
        // 20%
        if (r >= 66 && r <= 85) {
            sendPoints(sender, referree, 100 ether);
            emit Prize(2, requestId, sender, 202);
            return;
        }
        // 10%
        if (r >= 86 && r <= 95) {
            IBattlemonPickaxe(pickaxe).boxMint(sender, 2); // lvl3
            emit Prize(2, requestId, sender, 402);
            return;
        }
        // 5%
        if (r >= 96) {
            IBattlemonStickers(stickers).mint(sender, 1);
            emit Prize(2, requestId, sender, 0);
            return;
        }
    }

    function setAddresses(
        address lemons_,
        address items_,
        address stickers_,
        address pickaxe_,
        address points_,
        address referrals_
    ) public onlyOwner {
        require(
            lemons_ != address(0) &&
                items_ != address(0) &&
                points_ != address(0) &&
                referrals_ != address(0) &&
                stickers_ != address(0) &&
                pickaxe_ != address(0),
            "Box: Zero address"
        );
        lemons = lemons_;
        items = items_;
        stickers = stickers_;
        pickaxe = pickaxe_;
        points = points_;
        referrals = referrals_;
    }

    function sendPoints(address sender, address referree, uint amount) private {
        uint bonus = 0;
        if (referree != address(0)) {
            bonus = (amount * 5) / 100;
            IBattlemonPoints(points).mint(referree, bonus);
        }
        IBattlemonPoints(points).mint(sender, amount + bonus);
    }

    function _rewardReferree(
        address sender,
        uint value
    ) private returns (uint) {
        address referree = IBattlemonReferral(referrals).getUserRef(sender);
        if (referree != address(0)) {
            (bool s, ) = payable(referree).call{value: (value * 5) / 100}("");
            require(s, "Box: Cant transfer funds to referree");

            (bool s2, ) = payable(sender).call{value: (value * 5) / 100}("");
            if (!s2) {
                emit CallFailed(sender, value);
            }
        }
        return (value * 9) / 10;
    }

    receive() external payable {}

    function withdraw(uint value) public {
        require(msg.sender == tresuary, "Not tresuary");
        (bool s, ) = payable(tresuary).call{value: value}("");
        require(s, "Box: Withdraw went wrong");
    }

    function setConfig(uint[] memory prices) public onlyOwner {
        require(prices.length == 4);
        CHEAP_BOX_PRICE = prices[0];
        GOOD_BOX_PRICE = prices[1];
        GREAT_BOX_PRICE = prices[2];
        BATTLE_BOX_PRICE = prices[3];
    }

    function setKeysLineaParkAddresses(
        address[] memory addresses
    ) public onlyOwner {
        require(addresses.length == 2, "Box: Wrong length");
        lineaPark = addresses[0];
        keys = addresses[1];
    }

    function changeMaxLemonsAmount(uint amount) public onlyOwner {
        require(amount > MAX_LEMONS_AMOUNT, "Box: Less then previous");
        MAX_LEMONS_AMOUNT = amount;
    }

    function changeCallbackGasLimit(uint32 amount) public onlyOwner {
        _callbackGasLimit = amount;
    }

    function _requestRandomWord() private returns (uint256 s_requestId, uint256 requestPrice) {
        bytes memory extraArgs = VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: true}));
        return requestRandomnessPayInNative(_callbackGasLimit, 0, 1, extraArgs);
    }

    uint32 _callbackGasLimit;

    
}