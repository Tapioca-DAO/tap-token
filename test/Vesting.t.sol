// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.22;

// Tapioca Tests
import {TapTestHelper} from "./helpers/TapTestHelper.t.sol";

import {ERC20Mock} from "./Mocks/ERC20Mock.sol";

import {Errors} from "./helpers/errors.sol";
import {Vesting} from "tap-token/tokens/Vesting.sol";

// import "forge-std/Test.sol";
import {stdStorage, StdStorage} from "forge-std/Test.sol";
import "forge-std/console.sol";

contract VestingTest is TapTestHelper, Errors {
    using stdStorage for StdStorage;

    Vesting public vesting;
    Vesting public _vesting;
    ERC20Mock public mockToken; //instance of ERC20Mock (erc20)

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
        mockToken = new ERC20Mock("MockERC20", "Mock"); //deploy ERC20Mock
        vm.label(address(mockToken), "erc20Mock"); //label address for test traces
        mockToken.mint(address(this), 1_000_001); //transfer some tokens to address(this)
        mockToken.mint(address(vesting), 9_999_899); //transfer some tokens to address(this)
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

    /// @notice only owner can register multiple users 
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

    /// @notice only owner can register single user
    function test_register_user_not_owner() public {
        vm.startPrank(tokenBeneficiary);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vesting.registerUser(address(owner), 1000);
        vm.stopPrank();
    }

    /// @notice multiple users can't be registered once vesting period has started
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

    /// @notice single user can't be registered once vesting period has started
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

    /// @notice each user must have corresponding amount to vest when registering
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

    /// @notice vesting amount must be > 0 for multiple users
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

    /// @notice vesting amount must be > 0 for singe user
    function test_register_user_amount_not_valid() public {
        vm.startPrank(owner);
        vm.expectRevert(AmountNotValid.selector);
        vesting.registerUser(address(owner), 0);
        vm.stopPrank();
    }

    function testFuzz_register_users(uint256 amountToRegister1, uint256 amountToRegister2) public { 
        amountToRegister1 = bound(amountToRegister1, 1, 1_000_000_000);
        amountToRegister2 = bound(amountToRegister2, 1, 1_000_000_000);
        test_register_users(amountToRegister1, amountToRegister2);
    }

    function test_register_users_wrapper() public {
        test_register_users(1_000_000, 1_000_000);
    }

    /// @notice registering individual user via registerUsers works
    // @audit add an additional user here
    function test_register_users(uint256 amountToRegister1, uint256 amountToRegister2) public {
        vm.startPrank(owner);
        address[] memory users = new address[](2);
        users[0] = address(owner);
        users[1] = address(tokenBeneficiary);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amountToRegister1;
        amounts[1] = amountToRegister2;
        vesting.registerUsers(users, amounts);
        vm.stopPrank();
    }

    /// @notice registering single user works
    function test_register_user() public {
        vm.startPrank(owner);
        vesting.registerUser(address(owner), 100);
        vm.stopPrank();
    }

    /// @notice can't register same user more than once using registerUsers
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

    /// @notice can't register same user more than once using registerUser
    function test_register_user_twice() public {
        vm.startPrank(owner);
        vesting.registerUser(address(owner), 100);
        vm.expectRevert(AlreadyRegistered.selector);
        vesting.registerUser(address(owner), 100);

        vm.stopPrank();
    }

    /// @notice only owner can initialize vesting period
    function test_init_not_owner() public {
        vm.startPrank(tokenBeneficiary);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        vesting.init((mockToken), 1_000_000, 10);
        assertEq(vesting.start(), 0);
        assertEq(address(vesting.token()), address(0));
        vm.stopPrank();
    }

    /// @notice vesting period can only be initialized once
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

    /// @notice must provide a seededAmount > 0 to initialize vesting
    function test_init_no_tokens() public {
        vm.startPrank(owner);
        vm.expectRevert(NoTokens.selector);
        vesting.init((mockToken), 0, 10);
        assertEq(vesting.start(), 0);
        assertEq(address(vesting.token()), address(0));
        vm.stopPrank();
    }

    /// @notice available token balance in contract must be > seededAmount
    function test_init_no_balance() public {
        vm.startPrank(owner);
        vm.expectRevert(BalanceTooLow.selector);
        vesting.init((mockToken), 10_000_000, 10);
        assertEq(vesting.start(), 0);
        assertEq(address(vesting.token()), address(0));
        vm.stopPrank();
    }

    /// @notice seededAmount must be >= totalRegisteredAmount
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

    /// @notice initializing vesting period works
    function test_init() public {
        vm.startPrank(owner);
        uint256 amount1 = mockToken.balanceOf(address(vesting));
        assertEq(amount1, 9_999_899);
        assertEq(vesting.start(), 0);
        assertEq(address(vesting.token()), address(0));
        vm.warp(1717912068); // warp to current block timestamp
        vesting.init((mockToken), 9_999_899, 500); //initialize with 5% initialUnlock
        assertEq(vesting.start(), block.timestamp);
        assertEq(address(vesting.token()), address(mockToken));
        vm.stopPrank();
    }

    /// @notice can't claim before start 
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

    /// @notice user can't claim 0 amount
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

    /// @notice claiming with an initialUnlock amount > 0
    function test_claim_initial_unlock() public {
        vm.startPrank(owner);

        vesting.registerUser(address(owner), 100);

        uint256 seededAmount = mockToken.balanceOf(address(vesting));
        assertEq(seededAmount, 9_999_899);
        assertEq(vesting.start(), 0);
        assertEq(address(vesting.token()), address(0));

        uint256 initialUnlock = 500; // 5 BPS
        vm.warp(1717912068); // warp to current block timestamp
        vesting.init((mockToken), seededAmount, initialUnlock);
        assertEq(vesting.start(), block.timestamp);
        assertEq(address(vesting.token()), address(mockToken));

        uint256 amountBefore = mockToken.balanceOf(address(owner));
        vm.expectRevert(NothingToClaim.selector);
        vesting.claim();
        uint256 amountAfter = mockToken.balanceOf(address(owner));
        assertEq(amountAfter, amountBefore);

        vm.stopPrank();
    }

    /// @notice claiming with an initialUnlock amount == 0
    function test_claim() public {
        vm.startPrank(owner);

        vesting.registerUser(address(owner), 100);

        uint256 seededAmount = mockToken.balanceOf(address(vesting));
        assertEq(seededAmount, 9_999_899);
        assertEq(vesting.start(), 0);
        assertEq(address(vesting.token()), address(0));

        vm.warp(1717912068); // warp to current block timestamp
        vesting.init((mockToken), seededAmount, 0);
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
