// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import "tapioca-sdk/dist/contracts/YieldBox/contracts/YieldBox.sol";
import "tapioca-sdk/dist/contracts/YieldBox/contracts/mocks/WETH9Mock.sol"; // To include it in compilation

contract YieldBoxMock is YieldBox {
    constructor(
        IWrappedNative wrappedNative_,
        YieldBoxURIBuilder uriBuilder_
    ) YieldBox(wrappedNative_, uriBuilder_) {}
}
