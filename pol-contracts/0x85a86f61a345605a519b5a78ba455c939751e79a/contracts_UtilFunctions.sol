// Compatible with OpenZeppelin Contracts ^5.0.0
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./contracts_Structs.sol";
import "./contracts_CommonEventsAndErrors.sol";

contract UtilFunctions {
    function _getContractWithInterface(
        address defaultContract_,
        ContractType contractType_
    ) private view returns (address) {
        return
            IDefaultsUpgradeable(defaultContract_).getContractById(
                contractType_
            );
    }

    function _updateUser(
        StructUserAccount storage userAccount_,
        address user_,
        StructAnalytics storage analytics_
    ) internal {
        if (userAccount_.user == address(0)) {
            _updateUserAddress(userAccount_, user_);
            analytics_.users.push(user_);
        }
    }

    function _updateUserAddress(
        StructUserAccount storage userAccount_,
        address user_
    ) internal {
        if (userAccount_.user == address(0)) {
            userAccount_.user = user_;
        }
    }

    function _proceedTransferFrom(
        StructSupportedToken memory tokenAccount_,
        uint256 valueInWei_
    ) internal {
        if (valueInWei_ == 0)
            revert CommonError("You have not provided the token value.");
        if (tokenAccount_.isNative) {
            if (valueInWei_ != msg.value)
                revert CommonError("Token is native value mismatch");
        } else {
            IERC20_EXT ierc20 = IERC20_EXT(tokenAccount_.contractAddress);

            bool success = ierc20.transferFrom(
                msg.sender,
                address(this),
                _weiToTokens(valueInWei_, ierc20.decimals())
            );

            if (!success) revert CommonError("transfer from failed");
        }
    }

    function _transferFunds(
        StructSupportedToken memory tokenAccount_,
        address to_,
        uint256 valueInWei_
    ) internal {
        if (to_ == address(0)) {
            revert CommonError("_transfer: Transfer to zero address.");
        }

        if (valueInWei_ == 0) {
            revert CommonError("_transfer: Transfer of zero value.");
        }

        if (tokenAccount_.isNative) {
            // Transfer ETH
            (bool success, ) = payable(to_).call{value: valueInWei_}("");
            if (!success) {
                revert CommonError("_transfer: ETH transfer failed.");
            }
        } else {
            // Transfer ERC20 token
            bool success = IERC20_EXT(tokenAccount_.contractAddress).transfer(
                to_,
                _weiToTokens(valueInWei_, tokenAccount_.decimals)
            );

            if (!success) {
                revert CommonError("_transfer: ERC20 transfer failed.");
            }
        }
    }

    function _getPriceInUSD(
        IChainLinkV3Aggregator IChainLinkV3_
    ) internal view returns (uint256 priceInUSD) {
        int256 price = IChainLinkV3_.latestAnswer();

        if (price <= 0)
            revert CommonError("_getPriceInUSD: token price is invalid");

        priceInUSD = (uint256(price) * 1e18) / 10 ** IChainLinkV3_.decimals();
    }

    function _usdToTokens(
        uint256 valueInUSD_,
        StructSupportedToken memory tokenAccount_
    ) internal view returns (uint256 valueInTokens) {
        uint256 priceInUSD = _getPriceInUSD(
            IChainLinkV3Aggregator(tokenAccount_.chainLinkAggregatorV3Address)
        );

        valueInTokens =
            (valueInUSD_ * 10 ** tokenAccount_.decimals) /
            priceInUSD;
    }

    function _tokensToUSD(
        IChainLinkV3Aggregator IChainLinkV3_,
        uint256 valueInWei_
    ) internal view returns (uint256 valueInUSD) {
        uint256 price = _getPriceInUSD(IChainLinkV3_);
        valueInUSD = (valueInWei_ * price) / 1e18;
    }

    function _weiToTokens(
        uint256 valueInWei_,
        uint256 decimals_
    ) internal pure returns (uint256) {
        return (valueInWei_ * 10 ** decimals_) / 1e18;
    }

    function _tokensToWei(
        uint256 valueInToken_,
        uint256 decimals_
    ) internal pure returns (uint256) {
        return (valueInToken_ * 1e18) / 10 ** decimals_;
    }
}