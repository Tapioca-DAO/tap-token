// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import "forge-std/Test.sol";

import {LTap} from "contracts/option-airdrop/LTap.sol";

library LTapErrors {
    error TransferNotAllowed();
}

contract LTapTest is Test {
    LTap public ltap;

    uint256 internal aliceKey = 0x1;
    address public alice = vm.addr(aliceKey);
    uint256 internal bobKey = 0x2;
    address public bob = vm.addr(bobKey);

    uint256 public constant INITIAL_SUPPLY = 5_000_000 * 1e18;

    function setUp() public {
        ltap = new LTap(address(this), address(this));
        vm.label(address(this), "owner");
        vm.label(alice, "alice");
    }

    function test_setup() public {
        assertEq(ltap.totalSupply(), INITIAL_SUPPLY);
        assertEq(ltap.balanceOf(address(this)), INITIAL_SUPPLY);
        assertEq(ltap.owner(), address(this));
        assertEq(ltap.transferAllowList(address(this)), true);

        assertEq(ltap.openRedemption(), false);

        assertEq(ltap.decimals(), 18);
        assertEq(ltap.symbol(), "LTAP");
        assertEq(ltap.name(), "LTAP");
    }

    function test_transfer_allow_list() public {
        assertEq(ltap.transferAllowList(alice), false);

        vm.prank(alice);
        vm.expectRevert(LTapErrors.TransferNotAllowed.selector);
        ltap.transfer(bob, 1 ether);

        deal(address(ltap), alice, 1 ether);
        ltap.setTransferAllowList(alice, true);
        assertEq(ltap.transferAllowList(alice), true);
        vm.prank(alice);
        ltap.transfer(bob, 1 ether);
        assertEq(ltap.balanceOf(bob), 1 ether);
    }
}
