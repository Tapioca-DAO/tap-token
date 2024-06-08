// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.22;

// Tapioca Tests
import {TapTestHelper} from "./helpers/TapTestHelper.t.sol";

import {ERC20Mock} from "./Mocks/ERC20Mock.sol";

import {Errors} from "./helpers/errors.sol";
import {LTap} from "tap-token/option-airdrop/LTap.sol";

// import "forge-std/Test.sol";
import {stdStorage, StdStorage} from "forge-std/Test.sol";
import "forge-std/console.sol";

contract LTapTest is TapTestHelper, Errors {
    using stdStorage for StdStorage;

    LTap public ltap;
    ERC20Mock public mockTap; //instance of ERC20Mock (erc20)

    uint256 internal userAPKey = 0x1;
    uint256 internal userBPKey = 0x2;
    address public owner = vm.addr(userAPKey);
    address public lbp = vm.addr(userBPKey);
    address public alice = address(0x3);

    function setUp() public override {
        vm.deal(owner, 1000 ether); //give owner some ether
        vm.deal(lbp, 1000 ether); //give tokenBeneficiary some ether
        vm.label(owner, "owner"); //label address for test traces
        vm.label(lbp, "lbp"); //label address for test traces
        
        vm.startPrank(owner);
        mockTap = new ERC20Mock("MockERC20", "Mock"); //deploy MockToken
        ltap = new LTap(lbp, owner); //deploy LTap and set address to owner
        vm.label(address(mockTap), "mockTap"); //label address for test traces
        mockTap.mint(address(ltap),  5_000_000); //transfer initial amount of mockTap to LTap
        vm.stopPrank();

        super.setUp();
    }

    function test_constructor() public {
        // LTap is minted to the LBP address
        uint256 lbpLtapBalance = ltap.balanceOf(lbp);
        assertEq(lbpLtapBalance, 5_000_000 * 1e18);
        // owner is the owner of LTap
        assertEq(owner,ltap.owner());
        // lbp is added to transferAllowList
        assertTrue(ltap.transferAllowList(lbp));
    }

    /// @notice can't redeem when redemptions not open
    function test_redeem_not_open() public {
        vm.startPrank(owner);
        // tap token needs to initially be set
        ltap.setTapToken(address(mockTap));

        uint256 balBefore = mockTap.balanceOf(address(ltap));

        vm.expectRevert(LTap.RedemptionNotOpen.selector);
        ltap.redeem();

        uint256 balAfter = mockTap.balanceOf(address(ltap));
        assertEq(balAfter, balBefore);

        vm.stopPrank();
    }

    /// @notice redemption works 
    function test_redeem() public {
        // transfer LTap to owner to not redeem the entire lbp balance 
        vm.startPrank(lbp);
        ltap.transfer(owner, 5_000);
        assertEq(5_000, ltap.balanceOf(owner));
        vm.stopPrank();

        vm.startPrank(owner);

        // set tap token and open redemption
        ltap.setTapToken(address(mockTap));
        ltap.setOpenRedemption();

        // first redemption increases user tap balance
        uint256 lTapBalanceOfOwnerBefore = ltap.balanceOf(owner);
        uint256 tapBalanceOfOwnerBefore = mockTap.balanceOf(owner);
        ltap.redeem();
        uint256 lTapBalanceOfOwnerAfter = ltap.balanceOf(owner);
        uint256 tapBalanceOfOwnerAfterFirstRedemption = mockTap.balanceOf(owner);

        assertEq(lTapBalanceOfOwnerAfter, 0);
        assertEq(lTapBalanceOfOwnerBefore, tapBalanceOfOwnerAfterFirstRedemption);

        vm.stopPrank();
    }

    /// @notice user can't redeem more than their balance
    function test_cant_redeem_more_than_balance() public {
        // transfer LTap to owner to not redeem the entire lbp balance 
        vm.startPrank(lbp);
        ltap.transfer(owner, 5_000);
        assertEq(5_000, ltap.balanceOf(owner));
        vm.stopPrank();

        vm.startPrank(owner);

        // set tap token and open redemption
        ltap.setTapToken(address(mockTap));
        ltap.setOpenRedemption();

        // first redemption increases user tap balance
        uint256 lTapBalanceOfOwnerBefore = ltap.balanceOf(owner);
        uint256 tapBalanceOfOwnerBefore = mockTap.balanceOf(owner);
        ltap.redeem();
        uint256 lTapBalanceOfOwnerAfter = ltap.balanceOf(owner);
        uint256 tapBalanceOfOwnerAfterFirstRedemption = mockTap.balanceOf(owner);

        assertEq(lTapBalanceOfOwnerAfter, 0);
        assertEq(lTapBalanceOfOwnerBefore, tapBalanceOfOwnerAfterFirstRedemption);

        // second redemption shouldn't increase balance
        ltap.redeem();

        uint256 tapBalanceOfOwnerAfterSecondRedemeption = mockTap.balanceOf(owner);
        assertEq(tapBalanceOfOwnerAfterFirstRedemption, tapBalanceOfOwnerAfterSecondRedemeption);

        vm.stopPrank();
    }

    /// @notice only owner can set openRedemption
    function test_not_owner_open_redemption() public {
        vm.startPrank(lbp);

        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        ltap.setOpenRedemption();
        
        vm.stopPrank();
    }

    /// @notice openRedemption works
    function test_open_redemption() public {
        vm.startPrank(owner);
        // tap token must be set before setting openRedemption
        ltap.setTapToken(address(mockTap));

        ltap.setOpenRedemption();
        assertTrue(ltap.openRedemption());
        
        vm.stopPrank();
    }

    /// @notice can't redeem if tapToken not set
    function test_redeem_tap_token_not_set() public {
        // transfer LTap to owner to not redeem the entire lbp balance 
        vm.startPrank(lbp);
        ltap.transfer(owner, 5_000);
        assertEq(5_000, ltap.balanceOf(owner));
        vm.stopPrank();

        vm.startPrank(owner);

        uint256 lTapBalanceOfOwnerBefore = ltap.balanceOf(owner);
        uint256 tapBalanceOfOwnerBefore = mockTap.balanceOf(owner);

        vm.expectRevert(LTap.TapNotSet.selector);
        ltap.redeem();

        uint256 lTapBalanceOfOwnerAfter = ltap.balanceOf(owner);
        uint256 tapBalanceOfOwnerAfterFirstRedemption = mockTap.balanceOf(owner);

        assertEq(lTapBalanceOfOwnerAfter, lTapBalanceOfOwnerBefore);
        assertEq(tapBalanceOfOwnerBefore, tapBalanceOfOwnerAfterFirstRedemption);

        vm.stopPrank();
    }

    /// @notice can't transfer to address not on transferAllowList
    function test_transfer_not_allowed() public {
        // transfer LTap to owner to not redeem the entire lbp balance 
        vm.startPrank(lbp);
        ltap.transfer(owner, 5_000);
        assertEq(5_000, ltap.balanceOf(owner));
        vm.stopPrank();

        vm.startPrank(owner);

        // set tap token and open redemption
        ltap.setTapToken(address(mockTap));
        ltap.setOpenRedemption();

        uint256 lTapBalanceOfOwnerBefore = ltap.balanceOf(owner);
        vm.expectRevert(LTap.TransferNotAllowed.selector);
        ltap.transfer(lbp, 5_000);
        uint256 lTapBalanceOfOwnerAfter = ltap.balanceOf(owner);

        assertEq(lTapBalanceOfOwnerBefore, lTapBalanceOfOwnerAfter);

        vm.stopPrank();
    }

    /// @notice allow list and approvals are independent
    function test_transfer_not_approved() public {
        vm.startPrank(owner);

        // set tap token and open redemption
        ltap.setTapToken(address(mockTap));
        ltap.setOpenRedemption();

        // add owner to transfer allow list
        ltap.setTransferAllowList(owner, true);

        uint256 lTapBalanceOfOwnerBefore = ltap.balanceOf(owner);
        vm.expectRevert(bytes("ERC20: insufficient allowance"));
        ltap.transferFrom(lbp, owner, 5_000);
        uint256 lTapBalanceOfOwnerAfter = ltap.balanceOf(owner);

        assertEq(lTapBalanceOfOwnerBefore, lTapBalanceOfOwnerAfter);

        vm.stopPrank();
    }

    /// @notice approved but not on allow list doesn't transfer
    function test_approved_but_not_allowed() public { 
        // transfer ltap to owner
        vm.startPrank(lbp);
        ltap.transfer(owner, 5_000);
        vm.stopPrank();

        // approve alice for owner's ltap
        vm.startPrank(owner);
        ltap.approve(alice, 5_000);
        vm.stopPrank();

        // alice tries to transfer from owner without owner being on transferAllowList
        vm.startPrank(alice);

        uint256 aliceLTapBalanceBefore = ltap.balanceOf(owner);
        vm.expectRevert(LTap.TransferNotAllowed.selector);
        ltap.transferFrom(owner, alice, 5_000);
        uint256 aliceLTapBalanceAfter = ltap.balanceOf(owner);

        assertEq(aliceLTapBalanceBefore, aliceLTapBalanceAfter);

        vm.stopPrank();
    }

    /// @notice transferAllowList works
    function test_transfer_allowed() public {
        // transfer LTap to owner to not redeem the entire lbp balance 
        vm.startPrank(lbp);
        ltap.transfer(owner, 5_000);
        assertEq(5_000, ltap.balanceOf(owner));
        vm.stopPrank();

        vm.startPrank(owner);
        // add owner to transfer allow list 
        ltap.setTransferAllowList(owner, true);

        // set tap token and open redemption
        ltap.setTapToken(address(mockTap));
        ltap.setOpenRedemption();

        uint256 lTapBalanceOfOwnerBefore = ltap.balanceOf(owner);
        ltap.transfer(lbp, 5_000);
        uint256 lTapBalanceOfOwnerAfter = ltap.balanceOf(owner);

        assertEq(lTapBalanceOfOwnerAfter, 0);

        vm.stopPrank();
    }

    /// @notice can't transfer after removed from transferAllowList
     function test_transfer_remove_allowed() public {
        // transfer LTap to owner to not redeem the entire lbp balance 
        vm.startPrank(lbp);
        ltap.transfer(owner, 5_000);
        assertEq(5_000, ltap.balanceOf(owner));
        vm.stopPrank();

        vm.startPrank(owner);
        // add owner to transfer allow list 
        ltap.setTransferAllowList(owner, true);

        // set tap token and open redemption
        ltap.setTapToken(address(mockTap));
        ltap.setOpenRedemption();

        // first transfer works because on allow list 
        uint256 lTapBalanceOfOwnerBeforeFirst = ltap.balanceOf(owner);
        ltap.transfer(lbp, 2_500);
        uint256 lTapBalanceOfOwnerAfterFirst = ltap.balanceOf(owner);

        assertEq(lTapBalanceOfOwnerAfterFirst, 2_500);

        // remove owner from allow list
        ltap.setTransferAllowList(owner, false);

        // second transfer should fail after removal from allow list
        uint256 lTapBalanceOfOwnerBeforeSecond = ltap.balanceOf(owner);
        vm.expectRevert(LTap.TransferNotAllowed.selector);
        ltap.transfer(lbp, 2_500);
        uint256 lTapBalanceOfOwnerAfterSecond = ltap.balanceOf(owner);

        assertEq(lTapBalanceOfOwnerBeforeSecond, lTapBalanceOfOwnerAfterSecond);

        vm.stopPrank();
    }
}
