// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "tapioca-sdk/dist/contracts/YieldBox/contracts/strategies/ERC20WithoutStrategy.sol";

// solhint-disable const-name-snakecase
// solhint-disable no-empty-blocks

contract ERC20WithoutStrategyMock is ERC20WithoutStrategy {
    using BoringERC20 for IERC20;

    constructor(
        IYieldBox _yieldBox,
        IERC20 tokn
    ) ERC20WithoutStrategy(_yieldBox, tokn) {}
}
