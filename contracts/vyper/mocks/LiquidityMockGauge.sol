// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract LiquidityMockGauge {
    uint256 public test = 4000 * (10**18);

    function updateTest(uint256 newVal) external {
        test = newVal;
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
}
