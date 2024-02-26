// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.22;

// External

import {MockToken} from "gitsub_tapioca-sdk/src/contracts/mocks/MockToken.sol";

// Tapioca Tests
import {TapTestHelper} from "./helpers/TapTestHelper.t.sol";

import {MockToken} from "gitsub_tapioca-sdk/src/contracts/mocks/MockToken.sol";

import {Errors} from "./helpers/errors.sol";
import {Vesting} from "../contracts/Vesting.sol";

// import "forge-std/Test.sol";
import {stdStorage, StdStorage} from "forge-std/Test.sol";
import "forge-std/console.sol";

contract VestingTest is TapTestHelper, Errors {
    using stdStorage for StdStorage;

    Vesting public vesting;
    Vesting public _vesting;
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

        vm.expectRevert(VestingDurationNotValid.selector);
        _vesting = new Vesting(52 weeks, 0, address(owner));
        vesting = new Vesting(52 weeks, 208 weeks, address(owner));
        mockToken = new MockToken("MockERC20", "Mock"); //deploy MockToken
        vm.label(address(mockToken), "erc20Mock"); //label address for test traces
        mockToken.transfer(address(this), 1_000_001); //transfer some tokens to address(this)
        mockToken.transfer(address(vesting), 9_999_899); //transfer some tokens to address(this)
        super.setUp();
    }

    function test_constructor() public {
        vm.startPrank(owner);
        assertEq(vesting.duration(), 208 weeks);
        assertEq(vesting.cliff(), 52 weeks);
        assertEq(vesting.owner(), address(owner));
        uint256 amount1 = mockToken.balanceOf(address(vesting));
        assertEq(amount1, 9_999_899);
        vm.stopPrank();
    }

    function test_register_users_not_owner() public {
        vm.startPrank(tokenBeneficiary);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        address[] memory users = new address[](1);
        users[0] = address(owner);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1_000_000;
        vesting.registerUsers(users, amounts);
        vm.stopPrank();
    }

    function test_register_user_not_owner() public {
        vm.startPrank(tokenBeneficiary);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vesting.registerUser(address(owner), 1000);
        vm.stopPrank();
    }

    function test_register_users_init() public {
        vm.startPrank(owner);
        address[] memory users = new address[](1);
        users[0] = address(owner);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1_000_000;
        uint256 amount1 = mockToken.balanceOf(address(vesting));
        assertEq(amount1, 9_999_899);
        assertEq(vesting.start(), 0);
        assertEq(address(vesting.token()), address(0));
        vesting.init((mockToken), 1_000_000, 0);
        assertEq(vesting.start(), block.timestamp);
        assertEq(address(vesting.token()), address(mockToken));
        vm.expectRevert(Initialized.selector);
        vesting.registerUsers(users, amounts);
        vm.stopPrank();
    }

    function test_register_user_init() public {
        vm.startPrank(owner);
        uint256 amount1 = mockToken.balanceOf(address(vesting));
        assertEq(amount1, 9_999_899);
        assertEq(vesting.start(), 0);
        assertEq(address(vesting.token()), address(0));
        vesting.init((mockToken), 1_000_000, 0);
        assertEq(vesting.start(), block.timestamp);
        assertEq(address(vesting.token()), address(mockToken));
        vm.expectRevert(Initialized.selector);
        vesting.registerUser(address(owner), 1000);
        vm.stopPrank();
    }

    function test_register_users_different_lengths() public {
        vm.startPrank(owner);
        address[] memory users = new address[](1);
        users[0] = address(owner);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1_000_000;
        amounts[1] = 1_000_000;
        vm.expectRevert(bytes("Lengths not equal"));
        vesting.registerUsers(users, amounts);
        vm.stopPrank();
    }

    function test_register_users_amount_not_valid() public {
        vm.startPrank(owner);
        address[] memory users = new address[](2);
        users[0] = address(owner);
        users[1] = address(tokenBeneficiary);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1_000_000;
        amounts[1] = 0;
        vm.expectRevert(AmountNotValid.selector);
        vesting.registerUsers(users, amounts);
        amounts[0] = 0;
        amounts[1] = 1_000_000;
        vm.expectRevert(AmountNotValid.selector);
        vesting.registerUsers(users, amounts);
        vm.stopPrank();
    }

    function test_register_user_amount_not_valid() public {
        vm.startPrank(owner);
        vm.expectRevert(AmountNotValid.selector);
        vesting.registerUser(address(owner), 0);
        vm.stopPrank();
    }

    function test_register_users() public {
        vm.startPrank(owner);
        address[] memory users = new address[](1);
        users[0] = address(owner);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1_000_000;
        vesting.registerUsers(users, amounts);
        vm.stopPrank();
    }

    function test_register_user() public {
        vm.startPrank(owner);
        vesting.registerUser(address(owner), 100);
        vm.stopPrank();
    }

    function test_register_users_twice() public {
        vm.startPrank(owner);
        address[] memory users = new address[](1);
        users[0] = address(owner);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1_000_000;
        vesting.registerUsers(users, amounts);
        vm.expectRevert(AlreadyRegistered.selector);
        vesting.registerUsers(users, amounts);
        vm.stopPrank();
    }

    function test_register_user_twice() public {
        vm.startPrank(owner);
        vesting.registerUser(address(owner), 100);
        vm.expectRevert(AlreadyRegistered.selector);
        vesting.registerUser(address(owner), 100);

        vm.stopPrank();
    }

    function test_init_not_owner() public {
        vm.startPrank(tokenBeneficiary);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vesting.init((mockToken), 1_000_000, 10);
        assertEq(vesting.start(), 0);
        assertEq(address(vesting.token()), address(0));
        vm.stopPrank();
    }

    function test_init_twice() public {
        vm.startPrank(owner);
        uint256 amount1 = mockToken.balanceOf(address(vesting));
        assertEq(amount1, 9_999_899);
        assertEq(vesting.start(), 0);
        assertEq(address(vesting.token()), address(0));
        vesting.init((mockToken), 1_000_000, 0);
        assertEq(vesting.start(), block.timestamp);
        assertEq(address(vesting.token()), address(mockToken));
        vm.expectRevert(Initialized.selector);
        vesting.init((mockToken), 1_000_000, 0);
        vm.stopPrank();
    }

    function test_init_no_tokens() public {
        vm.startPrank(owner);
        vm.expectRevert(NoTokens.selector);
        vesting.init((mockToken), 0, 10);
        assertEq(vesting.start(), 0);
        assertEq(address(vesting.token()), address(0));
        vm.stopPrank();
    }

    function test_init_no_balance() public {
        vm.startPrank(owner);
        vm.expectRevert(BalanceTooLow.selector);
        vesting.init((mockToken), 10_000_000, 10);
        assertEq(vesting.start(), 0);
        assertEq(address(vesting.token()), address(0));
        vm.stopPrank();
    }

    function test_init_not_enough() public {
        vm.startPrank(owner);
        address[] memory users = new address[](1);
        users[0] = address(owner);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1_000_000;
        vesting.registerUsers(users, amounts);
        vm.expectRevert(NotEnough.selector);
        vesting.init((mockToken), 999_999, 10);
        assertEq(vesting.start(), 0);
        assertEq(address(vesting.token()), address(0));
        vm.stopPrank();
    }

    function test_init() public {
        vm.startPrank(owner);
        uint256 amount1 = mockToken.balanceOf(address(vesting));
        assertEq(amount1, 9_999_899);
        assertEq(vesting.start(), 0);
        assertEq(address(vesting.token()), address(0));
        vesting.init((mockToken), 1_000_000, 0);
        assertEq(vesting.start(), block.timestamp);
        assertEq(address(vesting.token()), address(mockToken));
        vm.stopPrank();
    }

    function test_claim_no_start() public {
        vm.startPrank(owner);
        uint256 amountBefore = mockToken.balanceOf(address(owner));
        uint256 claimable = vesting.claimable(address(owner));
        assertEq(claimable, 0);
        vm.expectRevert(NotStarted.selector);
        vesting.claim();
        uint256 amountAfter = mockToken.balanceOf(address(owner));
        assertEq(amountAfter, amountBefore);
        vm.stopPrank();
    }

    function test_nothing_to_claim() public {
        vm.startPrank(owner);
        vesting.init((mockToken), 1_000_000, 0);
        uint256 amountBefore = mockToken.balanceOf(address(owner));
        uint256 claimable = vesting.claimable(address(owner));
        vm.expectRevert(NothingToClaim.selector);
        vesting.claim();
        uint256 amountAfter = mockToken.balanceOf(address(owner));
        assertEq(amountAfter, amountBefore + claimable);
        vm.stopPrank();
    }

    function test_claim() public {
        vm.startPrank(owner);
        uint256 amount1 = mockToken.balanceOf(address(vesting));
        assertEq(amount1, 9_999_899);
        assertEq(vesting.start(), 0);
        assertEq(address(vesting.token()), address(0));
        vesting.init((mockToken), 1_000_000, 0);
        assertEq(vesting.start(), block.timestamp);
        assertEq(address(vesting.token()), address(mockToken));
        uint256 amountBefore = mockToken.balanceOf(address(owner));
        vm.expectRevert(NothingToClaim.selector);
        vesting.claim();
        uint256 amountAfter = mockToken.balanceOf(address(owner));
        assertEq(amountAfter, amountBefore);
        vm.stopPrank();
    }
}
