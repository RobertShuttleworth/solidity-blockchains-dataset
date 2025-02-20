// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import "./src_interfaces_IEVault.sol";
import "./src_interfaces_IstUSR.sol";
import "./src_interfaces_IwstUSR.sol";
import "./src_interfaces_IErc20.sol";
import "./src_interfaces_ICurveStableSwapPool.sol";
import "./src_interfaces_ICurveCryptoSwapPool.sol";


contract GoldBadgeBulk {
    address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address USR = 0x66a1E37c9b0eAddca17d3662D6c05F4DECf3e110;
    address RLP = 0x4956b52aE2fF65D74CA2d61207523288e4528f96;
    address curveUSRUSDPool = 0x3eE841F47947FEFbE510366E4bbb49e145484195;
    address curveUSRRLPPool = 0xC907ba505C2E1cbc4658c395d4a2c7E6d2c32656;
    address stUSR = 0x6c8984bc7DBBeDAf4F6b2FD766f16eBB7d10AAb4;
    address wstUSR = 0x1202F5C7b4B9E47a1A484E8B270be34dbbC75055;
    address usdcEvault = 0xcBC9B61177444A793B85442D3a953B90f6170b7D;
    address usrEvault = 0x3A8992754E2EF51D8F90620d2766278af5C59b90;
    address wstUsrEvault = 0x9f12d29c7CC72bb3d237E2D042A6D890421f9899;
    address payee = 0x0e6AA8e0fF9a9E5f0918c43B4679E53C19cc445B;
    
    function getGoldBadge() external {
        address user = msg.sender;
        // Transfer one-time operation payment from user (12 USDC) + 8 USDC for activities
        IErc20(USDC).transferFrom(user, address(this), 20e6);

        // 1. Buy 6 USDC worth of USR
        IErc20(USDC).approve(curveUSRUSDPool, 6e6);
        uint256 USRout = ICurveStableSwapPool(curveUSRUSDPool).exchange(1, 0, 6e6, 0, address(this));

        if (USRout < 4e18) {
            // If USRout is less than 3 USR, revert
            revert("Not enough USR bought");
        }

        // 2. Buy 1 USR worth of RLP
        IErc20(USR).approve(curveUSRRLPPool, 1e18);
        ICurveCryptoSwapPool(curveUSRRLPPool).exchange(0, 1, 1e18, 0, user);

        // 3. Stake 1 USR to stUSR
        IErc20(USR).approve(stUSR, 1e18);
        IstUSR(stUSR).deposit(1e18, user);

        // 4. Supply 1 USDC on Euler resolv market
        IErc20(USDC).approve(usdcEvault, 1e6);
        IEVault(usdcEvault).deposit(1e6, user);

        // 5. Supply 1 USR on Euler resolv market
        IErc20(USR).approve(usrEvault, 1e18);
        IEVault(usrEvault).deposit(1e18, user);

        // 6. Supply 1 USR worth of wstUSR on Euler resolv market
        IErc20(USR).approve(wstUSR, 1e18);
        uint wstUSRAmnt = IwstUSR(wstUSR).deposit(1e18, address(this));
        IErc20(wstUSR).approve(wstUsrEvault, wstUSRAmnt);
        IEVault(wstUsrEvault).deposit(wstUSRAmnt, user);

        // 7. Provide liquidity on USR pool
        IErc20(USDC).approve(curveUSRUSDPool, 1e6);
        uint256[] memory params = new uint256[](2);
        params[0] = 0;
        params[1] = 1e6;

        // Transfer all USR to user
        IErc20(USR).transfer(user, IErc20(USR).balanceOf(address(this)));

        ICurveStableSwapPool(curveUSRUSDPool).add_liquidity(params, 0, user);
    }

    function withdrawPayment() external {
        IErc20(USDC).transfer(payee, IErc20(USDC).balanceOf(address(this)));
    }
}