// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./lib_openzeppelin-contracts_contracts_token_ERC1155_ERC1155.sol";
import "./lib_openzeppelin-contracts_contracts_access_Ownable.sol";
import "./lib_openzeppelin-contracts_contracts_token_ERC721_IERC721.sol";
import "./lib_openzeppelin-contracts_contracts_token_ERC1155_extensions_ERC1155Supply.sol";

contract VotingPowerToken is ERC1155, Ownable, ERC1155Supply {
    uint256 public currentSeason;
    IERC721 public builderNFT;

    // 构造函数设置NFT合约地址
    constructor(address _builderNFTAddress) ERC1155("") Ownable(msg.sender) {
        builderNFT = IERC721(_builderNFTAddress);
        currentSeason = 11; // 从第一季开始
    }

    // 管理员可以设置当前season
    function setCurrentSeason(uint256 _newSeason) external onlyOwner {
        require(
            _newSeason > currentSeason,
            "New season must be greater than current"
        );
        currentSeason = _newSeason;
    }

    // 检查用户是否持有BuilderNFT
    function hasBuilderNFT(address _user) public view returns (bool) {
        return builderNFT.balanceOf(_user) > 0;
    }

    // mint当前season的投票权token
    function mint() external {
        require(hasBuilderNFT(msg.sender), "Must own a Builder NFT to mint");
        require(
            balanceOf(msg.sender, currentSeason) == 0,
            "Already minted for current season"
        );

        // currentSeason作为tokenId
        _mint(msg.sender, currentSeason, 1, "");
    }

    // 可选：批量mint功能
    function mintBatch() external pure {
        revert("Batch minting is not allowed");
    }

    // 管理员可以burn指定用户的投票权token
    function burn(address _user, uint256 _season) external onlyOwner {
        require(_user != address(0), "Cannot burn from zero address");
        require(balanceOf(_user, _season) > 0, "Insufficient balance to burn");
        _burn(_user, _season, 1);
    }

    // 管理员可以更新URI
    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal virtual override(ERC1155, ERC1155Supply) {
        // 只允许铸造（from = 0）和销毁（to = 0）操作
        require(
            from == address(0) || to == address(0),
            "Transfer is not allowed"
        );
        super._update(from, to, ids, values);
    }
}