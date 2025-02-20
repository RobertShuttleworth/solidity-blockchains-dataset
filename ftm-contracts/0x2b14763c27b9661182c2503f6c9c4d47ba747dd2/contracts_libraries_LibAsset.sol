// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./contracts_interfaces_IWETH.sol";

error AssetNotReceived();
error ApprovalFailed();
error TransferFromFailed();
error TransferFailed();
error FailedWrap();
error FailedUnwrap();

library LibAsset {
    using LibAsset for address;

    address constant NATIVE_ASSETID = address(0);

    /// @dev Checks if the given address (self) represents a native asset (Ether).
    /// @param self The asset that will be checked for a native token.
    /// @return Flag to identify if the asset is native or not.
    function isNative(address self) internal pure returns (bool) {
        return self == NATIVE_ASSETID;
    }

    /// @dev Wraps the specified asset.
    /// @param self The asset that will be wrapped.
    function wrap(address self, uint256 amount) internal {
        uint256 ptr;
        assembly {
            ptr := mload(0x40)
            mstore(0x40, add(ptr, 4))
            mstore(ptr, 0xd0e30db000000000000000000000000000000000000000000000000000000000)
        }

        if (!execute(self, amount, ptr, 4, 0, 0)) {
            revert FailedWrap();
        }
    }

    /// @dev Unwraps the specified asset.
    /// @param self The asset that will be unwrapped.
    function unwrap(address self, uint256 amount) internal {
        uint256 ptr;
        assembly {
            ptr := mload(0x40)
            mstore(0x40, add(ptr, 36))
            mstore(ptr, 0x2e1a7d4d00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), amount)
        }

        if (!execute(self, 0, ptr, 36, 0, 0)) {
            revert FailedUnwrap();
        }
    }

    /// @dev Retrieves the balance of the current contract for a given asset (self).
    /// @param self Asset whose balance needs to be found.
    /// @return Balance of the specific asset.
    function getBalance(address self) internal view returns (uint256) {
        return getBalanceOf(self, address(this));
    }

    /// @dev Retrieves the balance of the target address for a given asset (self).
    /// @param self Asset whose balance needs to be found.
    /// @param targetAddress The address where the balance is checked from.
    /// @return amount Balance of the specific asset.
    function getBalanceOf(address self, address targetAddress) internal view returns (uint256 amount) {
        assembly {
            switch self
            case 0 {
                amount := balance(targetAddress)
            }
            default {
                let currentInputPtr := mload(0x40)
                mstore(0x40, add(currentInputPtr, 68))
                mstore(currentInputPtr, 0x70a0823100000000000000000000000000000000000000000000000000000000)
                mstore(add(currentInputPtr, 4), targetAddress)
                let currentOutputPtr := add(currentInputPtr, 36)
                if iszero(staticcall(gas(), self, currentInputPtr, 36, currentOutputPtr, 32)) {
                    returndatacopy(0, 0, returndatasize())
                    revert(0, returndatasize())
                }

                amount := mload(currentOutputPtr)
            }
        }
    }

    /// @dev Performs a safe transferFrom operation for a given asset (self) from one address (from) to another address (to).
    /// @param self Asset that will be transferred.
    /// @param from Address that will send the asset.
    /// @param to Address that will receive the asset.
    /// @param amount Transferred amount.
    function transferFrom(address self, address from, address to, uint256 amount) internal {
        uint256 ptr;
        assembly {
            ptr := mload(0x40)
            mstore(0x40, add(ptr, 100))
            mstore(ptr, 0x23b872dd00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), from)
            mstore(add(ptr, 36), to)
            mstore(add(ptr, 68), amount)
        }

        if (!execute(self, 0, ptr, 100, 0, 0)) {
            revert TransferFromFailed();
        }
    }

    /// @dev Transfers a given amount of an asset (self) to a recipient address (recipient).
    /// @param self Asset that will be transferred.
    /// @param recipient Address that will receive the transferred asset.
    /// @param amount Transferred amount.
    function transfer(address self, address recipient, uint256 amount) internal {
        if (self.isNative()) {
            (bool success, ) = payable(recipient).call{value: amount}("");
            if (!success) {
                revert TransferFailed();
            }
        } else {
            uint256 ptr;
            assembly {
                ptr := mload(0x40)
                mstore(0x40, add(ptr, 68))
                mstore(ptr, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
                mstore(add(ptr, 4), recipient)
                mstore(add(ptr, 36), amount)
            }
            if (!execute(self, 0, ptr, 68, 0, 0)) {
                revert TransferFailed();
            }
        }
    }

    /// @dev Approves a spender address (spender) to spend a specified amount of an asset (self).
    /// @param self The asset that will be approved.
    /// @param spender Address of a contract that will spend the owners asset.
    /// @param amount Asset amount that can be spent.
    function approve(address self, address spender, uint256 amount) internal {
        uint256 ptr;
        assembly {
            ptr := mload(0x40)
            mstore(0x40, add(ptr, 68))
            mstore(ptr, 0x095ea7b300000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), spender)
            mstore(add(ptr, 36), amount)
        }

        if (!execute(self, 0, ptr, 68, 0, 0)) {
            assembly {
                mstore(add(ptr, 36), 0)
            }
            if (!execute(self, 0, ptr, 68, 0, 0)) {
                revert ApprovalFailed();
            }
            assembly {
                mstore(add(ptr, 36), amount)
            }
            if (!execute(self, 0, ptr, 68, 0, 0)) {
                revert ApprovalFailed();
            }
        }
    }

    function permit(
        address self,
        address owner,
        address spender,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        assembly {
            let ptr := mload(0x40)
            mstore(0x40, add(ptr, 228))
            mstore(ptr, 0xd505accf00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), owner)
            mstore(add(ptr, 36), spender)
            mstore(add(ptr, 68), amount)
            mstore(add(ptr, 100), deadline)
            mstore(add(ptr, 132), v)
            mstore(add(ptr, 164), r)
            mstore(add(ptr, 196), s)
            let success := call(gas(), self, 0, ptr, 228, 0, 0)
        }
    }

    /// @dev Determines if a call was successful.
    /// @param target Address of the target contract.
    /// @param success To check if the call to the contract was successful or not.
    /// @param data The data was sent while calling the target contract.
    /// @return result The success of the call.
    function isSuccessful(address target, bool success, bytes memory data) private view returns (bool result) {
        if (success) {
            if (data.length == 0) {
                // isContract
                if (target.code.length > 0) {
                    result = true;
                }
            } else {
                assembly {
                    result := mload(add(data, 32))
                }
            }
        }
    }

    /// @dev Executes a low level call.
    function execute(
        address self,
        uint256 currentNativeAmount,
        uint256 currentInputPtr,
        uint256 currentInputLength,
        uint256 currentOutputPtr,
        uint256 outputLength
    ) internal returns (bool result) {
        assembly {
            function isSuccessfulCall(targetAddress) -> isSuccessful {
                switch iszero(returndatasize())
                case 1 {
                    if gt(extcodesize(targetAddress), 0) {
                        isSuccessful := 1
                    }
                }
                case 0 {
                    returndatacopy(0, 0, 32)
                    isSuccessful := gt(mload(0), 0)
                }
            }

            if iszero(
                call(
                    gas(),
                    self,
                    currentNativeAmount,
                    currentInputPtr,
                    currentInputLength,
                    currentOutputPtr,
                    outputLength
                )
            ) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }

            result := isSuccessfulCall(self)
        }
    }
}