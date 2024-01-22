// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.22;

// External

import {MockToken} from "gitsub_tapioca-sdk/src/contracts/mocks/MockToken.sol";

// Tapioca Tests
import {TapTestHelper} from "../helpers/TapTestHelper.t.sol";

import {MockToken} from "gitsub_tapioca-sdk/src/contracts/mocks/MockToken.sol";

import {Errors} from "../helpers/errors.sol";
import {LTap} from "../../contracts/tokens/LTap.sol";

// import "forge-std/Test.sol";
import {stdStorage, StdStorage} from "forge-std/Test.sol";
import "forge-std/console.sol";

contract LTapTest is TapTestHelper, Errors { //100% DONE
    using stdStorage for StdStorage;

    LTap public ltap;
    MockToken public mockToken; //instance of MockToken (erc20)

    uint256 internal userAPKey = 0x1;
    uint256 internal userBPKey = 0x2;
    address public owner = vm.addr(userAPKey);
    address public tokenBeneficiary = vm.addr(userBPKey);

    function setUp() public override {
        vm.deal(owner, 1000 ether); //give owner some ether
        vm.deal(tokenBeneficiary, 1000 ether); //give tokenBeneficiary some ether
        vm.label(owner, "owner"); //label address for test traces
        vm.label(tokenBeneficiary, "tokenBeneficiary"); //label address for test traces
        vm.startPrank(owner);
        mockToken = new MockToken("MockERC20", "Mock"); //deploy MockToken
        ltap = new LTap(mockToken, block.timestamp + 7 days); //deploy LTap and set address to owner
        vm.label(address(mockToken), "erc20Mock"); //label address for test traces
        mockToken.transfer(address(this), 1_000_001); //transfer some tokens to address(this)
        vm.stopPrank();
        super.setUp();
    }

    function test_constructor() public {
        //ok
        vm.startPrank(owner);
        uint256 lockedUntil = ltap.lockedUntil();
        uint256 maxLockedUntil = ltap.maxLockedUntil();
        assertEq(lockedUntil, block.timestamp + 7 days);
        assertEq(maxLockedUntil, block.timestamp + 7 days);
        vm.startPrank(owner);
    }

    function test_deposit_more_than_balance() public {
        //ok
        vm.startPrank(owner);
        uint256 balBefore = mockToken.balanceOf(address(this));
        uint256 balOwnerBefore = mockToken.balanceOf(address(owner));
        mockToken.approve(address(ltap), 1000000000000000000 ether);
        vm.expectRevert(bytes("ERC20: transfer amount exceeds balance"));
        ltap.deposit(1000000000000000000 ether);
        uint256 balAfter = mockToken.balanceOf(address(this));
        assertEq(balAfter, balBefore);
        uint256 balOwnerAfter = mockToken.balanceOf(address(owner));
        assertEq(balOwnerBefore, balOwnerAfter);

        vm.stopPrank();
    }

    function test_deposit() public {
        //ok
        vm.startPrank(owner);
        uint256 balBefore = mockToken.balanceOf(address(ltap));
        mockToken.approve(address(ltap), 1000 ether);
        ltap.deposit(1000 ether);
        uint256 balAfter = mockToken.balanceOf(address(ltap));
        assertEq(balAfter - balBefore, 1000 ether);
        assertEq(balAfter, balBefore + 1000 ether);
        uint256 balLtap = ltap.balanceOf(address(owner));
        assertEq(balLtap, 1000 ether);
        vm.stopPrank();
    }

    function test_redeem_early() public {
        vm.startPrank(owner);
        uint256 balBefore = mockToken.balanceOf(address(ltap));
        vm.expectRevert(StillLocked.selector);
        ltap.redeem();
        uint256 balAfter = mockToken.balanceOf(address(ltap));
        assertEq(balAfter, balBefore);
        vm.stopPrank();
    }

    function test_redeem() public {
        //1000 ltap
        vm.startPrank(owner);
        mockToken.approve(address(ltap), 1000 ether);
        ltap.deposit(1000 ether);
        uint256 balBefore = mockToken.balanceOf(owner);
        // assertEq(balBefore , 0);
        vm.warp(block.timestamp + 8 days);
        ltap.redeem();
        uint256 balAfter = mockToken.balanceOf(owner);
        assertEq( balAfter , balBefore +  1000 ether);
        uint256 balLtap = ltap.balanceOf(address(owner));
        assertEq(balLtap, 0);
        vm.stopPrank();
    }

    function test_set_locked_until_not_owner() public {
        vm.startPrank(tokenBeneficiary);
        uint256 lockedUntilBefore = ltap.lockedUntil();
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        ltap.setLockedUntil(block.timestamp + 8 days);
        uint256 lockedUntilAfter = ltap.lockedUntil();

        assertEq(lockedUntilBefore, lockedUntilAfter);
        vm.stopPrank();
    }

    function test_set_locked_until_too_late() public {
        vm.startPrank(owner);
        uint256 lockedUntilBefore = ltap.lockedUntil();
        assertEq(lockedUntilBefore, block.timestamp + 7 days);
        vm.expectRevert(TooLate.selector);
        ltap.setLockedUntil(block.timestamp + 10 days);
        uint256 lockedUntilAfter = ltap.lockedUntil();

        assertEq(lockedUntilBefore, lockedUntilAfter);
        vm.stopPrank();
    }

    function test_set_locked_until() public {
        vm.startPrank(owner);
        uint256 lockedUntilBefore = ltap.lockedUntil();
        assertEq(lockedUntilBefore, block.timestamp + 7 days);
        ltap.setLockedUntil(block.timestamp + 7 days);
        uint256 lockedUntilAfter = ltap.lockedUntil();
        assertEq(lockedUntilBefore, lockedUntilAfter);
        vm.stopPrank();
    }
}
