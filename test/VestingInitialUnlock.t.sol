// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import "forge-std/Test.sol";
import {Vesting} from "contracts/tokens/Vesting.sol";

contract VestingInitialUnlockTest is Test, Vesting {
    // Early Supporters:
    // totalAmount = 3,500,000 TAP
    // initial unlock = 210,000 TAP
    // duration = 2 years

    uint256 totalAmount = 3500000; // 3,500,000 TAP
    uint256 initialUnlockAmount = 210000; // 210,000 TAP

    address public __owner = address(123); //owner of the contract

    constructor() Vesting(0, 2 * 365 days, __owner) {}

    function setUp() public {
        start = 1718286203;
    }

    function test_initial() public {
        console.log("start : ", start);
        console.log("duration: ", duration);
        console.log("totalAmount : ", totalAmount);
        console.log("initialUnlockAmount : ", initialUnlockAmount);

        uint256 initialUnlockTimeOffset = _computeTimeFromAmount(start, totalAmount, initialUnlockAmount, duration);
        console.log("initialUnlockTimeOffset : ", initialUnlockTimeOffset);
        __initialUnlockTimeOffset = initialUnlockTimeOffset;

        {
            vm.warp(start + 0 days);
            uint256 vestedAmount = _vested(totalAmount);
            // assertLt(vestedAmount, totalAmount);
            console.log("vestedAmount before the duration is completed : ", vestedAmount);
        }

        {
            vm.warp(start + 686 days);
            uint256 vestedAmount = _vested(totalAmount);
            // assertLt(vestedAmount, totalAmount);
            console.log("vestedAmount before the duration is completed : ", vestedAmount);
        }
        {
            vm.warp(start + 687 days);
            uint256 vestedAmount = _vested(totalAmount);
            // assertEq(vestedAmount, totalAmount);
            console.log("vestedAmount after the duration is completed : ", vestedAmount);
        }
    }
}
