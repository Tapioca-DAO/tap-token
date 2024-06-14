// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.22;

// External
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Tapioca Tests

import {TapTestHelper} from "../helpers/TapTestHelper.t.sol";
import {ERC721Mock} from "../Mocks/ERC721Mock.sol";
import {TapTokenMock as TapOFTV2Mock} from "../Mocks/TapOFTV2Mock.sol";

import {TapOracleMock} from "../Mocks/TapOracleMock.sol";

// Tapioca contracts
import {OTAP} from "../../contracts/options/oTAP.sol";

// Import contract to test
import {AirdropBroker} from "../../contracts/option-airdrop/AirdropBroker.sol";
import {IPearlmit, Pearlmit} from "tapioca-periph/pearlmit/Pearlmit.sol";

import {Errors} from "../helpers/errors.sol";

// import "forge-std/Test.sol";
import {stdStorage, StdStorage} from "forge-std/Test.sol";
import "forge-std/console.sol";

contract oTapTest is TapTestHelper, Errors {
    using stdStorage for StdStorage;

    OTAP public otap; //instance of AOTAP

    uint256 internal userAPKey = 0x1;
    uint256 internal userBPKey = 0x2;
    address public owner = vm.addr(userAPKey);
    address public tokenBeneficiary = vm.addr(userBPKey);

    function setUp() public override {
        vm.deal(owner, 1000 ether); //give owner some ether
        vm.deal(tokenBeneficiary, 1000 ether); //give tokenBeneficiary some ether
        vm.label(owner, "owner"); //label address for test traces
        vm.label(tokenBeneficiary, "tokenBeneficiary"); //label address for test traces

        Pearlmit pearlmit = new Pearlmit("Pearlmit", "1", owner, type(uint256).max);
        otap = new OTAP(IPearlmit(address(pearlmit)), address(this)); //deploy OTAP
        super.setUp();
    }

    function test_constructor() public {
        address _broker = otap.broker();
        assertEq(_broker, address(0));
        assertEq(otap.owner(), address(this));
    }

    /// @notice setting the broker works
    function test_set_broker() public {
        vm.startPrank(owner);
        otap.brokerClaim();
        address _broker = otap.broker();
        assertEq(_broker, address(owner));
        vm.stopPrank();
    }

    /// @notice trying to set the broker after it's already been set fails
    function test_claim_broker_twice() public {
        vm.startPrank(owner);
        otap.brokerClaim();
        address _broker = otap.broker();
        assertEq(_broker, address(owner));
        vm.expectRevert(OnlyOnce.selector);
        otap.brokerClaim();
        vm.stopPrank();
    }

    /// @notice only broker can mint
    function test_cannot_mint_no_broker() public {
        vm.expectRevert(OTAP.OnlyBroker.selector);
        otap.mint(address(owner), 1, 1, 1);
        uint256 balance = otap.balanceOf(address(owner));
        assertEq(balance, 0);
    }

    /// @notice test minting oTAP works
    function test_mint_otap() public {
        vm.startPrank(owner);
        otap.brokerClaim();
        uint256 tokenId = otap.mint(address(owner), 1, 1, 1);
        uint256 balance = otap.balanceOf(address(owner));
        assertEq(balance, 1);
        vm.stopPrank();
    }

    /// @notice when a token is minted it should exist
    function test_exists() public {
        vm.startPrank(owner);
        otap.brokerClaim();
        uint256 tokenId = otap.mint(address(owner), 1, 1, 1);
        uint256 balance = otap.balanceOf(address(owner));
        assertEq(balance, 1);
        vm.stopPrank();
        (bool exists) = otap.exists(1);
        assertEq(exists, true);
    }

    /// @notice minting multiple oTAP is properly accounted for minter
    function test_mint_several_otap() public {
        vm.startPrank(owner);
        otap.brokerClaim();
        uint256 i;
        for (i; i < 10; i++) {
            uint256 tokenId = otap.mint(address(owner), 1, 1, 1);
            uint256 balance = otap.balanceOf(address(owner));
            assertEq(balance, i + 1);
        }
        uint256 _balance = otap.balanceOf(address(owner));
        assertEq(_balance, i);
        vm.stopPrank();
    }

    /// @notice oTAP can be transferred to a different address
    function test_transfer_from() public {
        vm.startPrank(owner);
        otap.brokerClaim();
        otap.mint(owner, 1, 1, 1);
        otap.safeTransferFrom(owner, tokenBeneficiary, 1);
        address new_owner = otap.ownerOf(1);
        assertEq(tokenBeneficiary, new_owner);
        uint256 bal = otap.balanceOf(tokenBeneficiary);
        assertEq(bal, 1);
        vm.stopPrank();
    }

    /// @notice oTAP is successfully burned
    function test_burn() public {
        vm.startPrank(owner);
        otap.brokerClaim();
        otap.mint(owner, 1, 1, 1);
        otap.burn(1);
        uint256 bal = otap.balanceOf(owner);
        assertEq(bal, (0));
        vm.stopPrank();
    }

    /// @notice only broker can burn
    function test_fail_burning() public {
        vm.startPrank(owner);
        otap.brokerClaim();
        otap.mint(owner, 1, 1, 1);
        vm.stopPrank();
        vm.startPrank(tokenBeneficiary);
        vm.expectRevert(OTAP.OnlyBroker.selector);
        otap.burn(1);
        vm.stopPrank();
    }

    /// @notice approvals don't change owner
    function test_approvals() public {
        vm.startPrank(owner);
        otap.brokerClaim();
        otap.mint(owner, 1, 1, 1);
        otap.approve(tokenBeneficiary, 1);
        address _owner = otap.ownerOf(1);
        assertEq(owner, _owner);
        address _approved = otap.getApproved(1);
        assertEq(tokenBeneficiary, _approved);
        vm.stopPrank();
    }

    /// @notice approval approves correct user
    function test_get_approved() public {
        vm.startPrank(owner);
        otap.brokerClaim();
        otap.mint(owner, 1, 1, 1);
        otap.approve(tokenBeneficiary, 1);
        address _approved = otap.getApproved(1);
        assertEq(_approved, tokenBeneficiary);
        vm.stopPrank();
    }

    /// @notice approval for all works
    function test_set_approval_for_all() public {
        vm.startPrank(owner);
        otap.brokerClaim();
        otap.mint(owner, 1, 1, 1);
        otap.setApprovalForAll(tokenBeneficiary, true);
        bool _approved = otap.isApprovedForAll(owner, tokenBeneficiary);
        assertEq(_approved, true);
        vm.stopPrank();
    }

    // Testing of events

    function testTransferEvent() public {
        vm.startPrank(owner);
        otap.brokerClaim();
        otap.mint(owner, 1, 1, 1);
        vm.expectEmit(address(otap));
        emit IERC721.Transfer(address(owner), address(tokenBeneficiary), 1);
        otap.safeTransferFrom(owner, tokenBeneficiary, 1);
        vm.stopPrank();
    }

    function testApprovalEvent() public {
        vm.startPrank(owner);
        otap.brokerClaim();
        otap.mint(owner, 1, 1, 1);
        vm.expectEmit(address(otap));
        emit IERC721.Approval(address(owner), address(tokenBeneficiary), 1);
        otap.approve(tokenBeneficiary, 1);
        vm.stopPrank();
    }

    function testApprovalForAllEvent() public {
        vm.startPrank(owner);
        otap.brokerClaim();
        otap.mint(owner, 1, 1, 1);
        vm.expectEmit(address(otap));
        emit IERC721.ApprovalForAll(address(owner), address(tokenBeneficiary), true);
        otap.setApprovalForAll(tokenBeneficiary, true);
        vm.stopPrank();
    }
}
