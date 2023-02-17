// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import 'tapioca-sdk/dist/contracts/YieldBox/contracts/strategies/BaseStrategy.sol';

contract YieldBoxVaultStrat is BaseERC20Strategy {
    string public name;
    string public description;

    constructor(
        IYieldBox _yieldBox,
        address _contractAddress,
        string memory _name,
        string memory _description
    ) BaseERC20Strategy(_yieldBox, _contractAddress) {
        name = _name;
        description = _description;
    }

    function _currentBalance() internal view override returns (uint256 amount) {
        return IERC20(contractAddress).balanceOf(address(this));
    }

    function _deposited(uint256 amount) internal virtual override {}

    function _withdraw(address to, uint256 amount) internal virtual override {}
}
