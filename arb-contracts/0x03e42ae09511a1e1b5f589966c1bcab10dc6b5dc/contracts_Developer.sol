// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "./contracts_Stake.sol";
import "./contracts_Token.sol";
import "./openzeppelin_contracts_access_Ownable.sol";
import "./openzeppelin_contracts_token_ERC20_IERC20.sol";

contract Developer is Ownable {

    uint256 public devCount;
    mapping(uint256 => address) public developers;
    mapping(address => uint256) public developerIds;

    Stake public immutable stake;
    Token public immutable token;
    address public immutable router;

    constructor(uint256 period, address pairTokenAddress, address routerAddress) Ownable(msg.sender) {
        token = new Token();
        stake = new Stake();
        router = routerAddress;
        token.setup(address(stake));
        stake.setup(period, address(token), pairTokenAddress, routerAddress);
    }

    function isDeveloper(address dev) public view returns (bool) {
        return developerIds[dev] > 0;
    }

    function addDeveloper(address dev) external onlyOwner {
        distribute();
        require(!isDeveloper(dev), "Developer: Already set");
        developers[++devCount] = dev;
        developerIds[dev] = devCount;
    }

    function removeDeveloper(address dev) external onlyOwner {
        distribute();
        require(isDeveloper(dev), "Developer: Not set");
        uint256 devId = developerIds[dev];
        delete developers[devId];
        delete developerIds[dev];
        if(devId < devCount) {
            developers[devId] = developers[devCount];
            developerIds[developers[devCount]] = devId;
        }
        devCount--;
    }

    function distribute() public {
        _distribute(address(token));
    }

    function distributeToken(address tokenAddress) public {
        _distribute(tokenAddress);
    }

    function _distribute(address tokenAddress) internal {
        if(devCount == 0) return;
        IERC20 _token = IERC20(tokenAddress);
        uint256 tokenBalance = _token.balanceOf(address(this));
        if(tokenBalance == 0) return;
        uint256 amountToSend = tokenBalance / devCount;
        if(amountToSend == 0) return;
        for(uint256 i = 1; i <= devCount; i++) {
            _token.transfer(developers[i], amountToSend);
        }
    }
}