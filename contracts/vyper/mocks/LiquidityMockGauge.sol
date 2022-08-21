// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

contract LiquidityMockGauge {
    using SafeERC20 for IERC20;

    address public token;
    uint256 public test = 4000 * (10**18);

    function updateTest(uint256 newVal) external {
        test = newVal;
    }

    function setToken(address addr) external {
        token = addr;
    }

    // solhint-disable-next-line func-name-mixedcase
    function integrate_fraction(address) external view returns (uint256) {
        return test;
    }

    // solhint-disable-next-line func-name-mixedcase
    function user_checkpoint(address) external returns (bool) {
        test = 4000 * (10**18);
        return true;
    }

    function addRewards(uint256 amount) external {
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
    }
}
