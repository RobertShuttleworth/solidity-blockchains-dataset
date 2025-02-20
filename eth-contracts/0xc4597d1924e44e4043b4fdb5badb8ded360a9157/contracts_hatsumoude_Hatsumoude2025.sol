// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "./openzeppelin_contracts_token_ERC1155_ERC1155.sol";
import "./openzeppelin_contracts_token_common_ERC2981.sol";
import "./openzeppelin_contracts_access_AccessControl.sol";
import "./openzeppelin_contracts_access_Ownable.sol";
import "./openzeppelin_contracts_utils_Strings.sol";

contract Hatsumoude2025 is ERC1155, AccessControl, Ownable, ERC2981 {
    using Strings for uint256;

    event LotteryMinted(address indexed contractAddress, address indexed sender, uint256[] tokenIds, uint256[] counts);

    struct LotteryItem {
        uint256 tokenId;
        uint256 weight;
    }

    struct WithdrawSetting {
        address receiver;
        uint256 ratio;
    }

    // Role
    bytes32 public constant ADMIN = "ADMIN";
    bytes32 public constant MINTER = "MINTER";

    // Metadata
    string public name = "Hatsumoude2025";
    string public symbol = "HATSUMOUDE2025";
    string public baseURI;
    string public baseExtension;

    // Mint
    bool public paused = false;
    mapping(uint256 => uint256) public mintCost;
    mapping(uint256 => uint256) public totalSupply;
    mapping(uint256 => uint256) public mintedAmount;

    // Lottery
    uint256 private nonce = 0;
    LotteryItem[] public lotteryItems;
    uint256 public totalWeight;

    // Withdraw
    WithdrawSetting[] public withdrawSettings;


    constructor() ERC1155("") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN, msg.sender);
    }

    function airdrop(address[] calldata _addresses, uint256[] calldata _tokenIds, uint256[] calldata _amounts) external onlyRole(ADMIN) {
        require(_tokenIds.length == _addresses.length && _tokenIds.length == _amounts.length, 'Invalid Input');
        for (uint256 i = 0; i < _addresses.length; i++) {
            _mint(_addresses[i], _tokenIds[i], _amounts[i], "");
            totalSupply[_tokenIds[i]] += _amounts[i];
        }
    }

    function mint(address _address, uint256 _packAmount, uint256 _count) external payable {
        uint256 _mintCost = mintCost[_packAmount] * _count;

        require(!paused, 'Paused');
        require(_mintCost > 0 && msg.value >= _mintCost, 'Invalid Mint Amount');

        uint256[] memory _tokenIds = new uint256[](_packAmount * _count);
        uint256[] memory _amounts = new uint256[](_packAmount * _count);

        for (uint256 i = 0; i < _packAmount * _count; i++) {
            uint256 _tokenId = _lotteryTokenId();
            _tokenIds[i] = _tokenId;
            _amounts[i] = 1;

            _mint(_address, _tokenId, 1, "");
            totalSupply[_tokenId] += 1;
        }
        mintedAmount[_packAmount] += _count;

        emit LotteryMinted(address(this), _address, _tokenIds, _amounts);
    }

    function externalMint(address _address, uint256 _tokenId, uint256 _amount) external onlyRole(MINTER) {
        _mint(_address, _tokenId, _amount, "");
        totalSupply[_tokenId] += _amount;
    }

    function _lotteryTokenId() private returns (uint256) {
        require(totalWeight > 0, 'Total Weight is 0');
        nonce++;
        uint256 random = uint256(keccak256(abi.encodePacked(
            block.difficulty,
            blockhash(block.number - 1),
            block.timestamp,
            msg.sender,
            nonce,
            address(this)
        )));
        uint256 randomWeight = random % totalWeight;
        uint256 cumulativeWeight = 0;
        for (uint256 i = 0; i < lotteryItems.length; i++) {
            cumulativeWeight += lotteryItems[i].weight;
            if (randomWeight < cumulativeWeight) {
                return lotteryItems[i].tokenId;
            }
        }
        return lotteryItems[lotteryItems.length - 1].tokenId;
    }

    // Getter
    function uri(uint256 tokenId) public view virtual override returns (string memory) {
        return string(abi.encodePacked(baseURI, tokenId.toString(), baseExtension));
    }

    // Setter
    function setMetadataBase(string memory _baseURI, string memory _baseExtension) external onlyRole(ADMIN) {
        baseURI = _baseURI;
        baseExtension = _baseExtension;
    }
    function setPaused(bool _value) external onlyRole(ADMIN) {
        paused = _value;
    }
    function setDefaultRoyalty(address _receiver, uint96 _feeNumerator) external onlyRole(ADMIN) {
        _setDefaultRoyalty(_receiver, _feeNumerator);
    }
    function setLotteryItems(LotteryItem[] memory _value) external onlyRole(ADMIN) {
        lotteryItems = _value;
        uint256 _totalRatio = 0;
        for (uint256 i = 0; i < _value.length; i++) {
            _totalRatio += _value[i].weight;
        }
        totalWeight = _totalRatio;
    }
    function setMintCost(uint256 _amount, uint256 _value) external onlyRole(ADMIN) {
        mintCost[_amount] = _value;
    }
    function setWithdrawSettings(WithdrawSetting[] memory _value) public onlyRole(ADMIN) {
        withdrawSettings = _value;
    }

    // withdraw
    function withdraw() public onlyRole(ADMIN) {
        uint256 _balance = address(this).balance;
        require(_balance > 0, "Not Enough Balance");

        uint256 _remainAmount = _balance;
        bool success;
        uint256 _totalDistribution = _remainAmount;

        uint256 _totalRatio = 0;
        for (uint256 i = 0; i < withdrawSettings.length; i++) {
            _totalRatio += withdrawSettings[i].ratio;
        }
        for (uint256 i = 0; i < withdrawSettings.length; i++) {
            WithdrawSetting memory _withdrawSetting = withdrawSettings[i];
            if (i == withdrawSettings.length - 1) {
                (success, ) = payable(_withdrawSetting.receiver).call{value: _remainAmount}("");
                require(success);
            } else {
                uint256 payAmount = _totalDistribution * _withdrawSetting.ratio / _totalRatio;
                (success, ) = payable(_withdrawSetting.receiver).call{value: payAmount}("");
                require(success);
                _remainAmount -= payAmount;
            }
        }
    }

    // interface
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155, AccessControl, ERC2981) returns (bool) {
        return
            ERC1155.supportsInterface(interfaceId) ||
            AccessControl.supportsInterface(interfaceId) ||
            ERC2981.supportsInterface(interfaceId) ||
            super.supportsInterface(interfaceId);
    }
}