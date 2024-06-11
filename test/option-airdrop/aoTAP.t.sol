// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.22;

// External
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ERC20Mock} from "../Mocks/ERC20Mock.sol";

// Tapioca Tests

import {IPearlmit, Pearlmit} from "tapioca-periph/pearlmit/Pearlmit.sol";
import {TapTokenMock as TapOFTV2Mock} from "../Mocks/TapOFTV2Mock.sol";
import {TapTestHelper} from "../helpers/TapTestHelper.t.sol";
import {ERC721Mock} from "../Mocks/ERC721Mock.sol";

import {TapOracleMock} from "../Mocks/TapOracleMock.sol";

// Tapioca contracts
import {AOTAP} from "../../contracts/option-airdrop/AOTAP.sol";

// Import contract to test
import {AirdropBroker} from "../../contracts/option-airdrop/AirdropBroker.sol";

import {Errors} from "../helpers/errors.sol";

// import "forge-std/Test.sol";
import {stdStorage, StdStorage} from "forge-std/Test.sol";
import "forge-std/console.sol";

contract aoTapTest is TapTestHelper, Errors {
    using stdStorage for StdStorage;

    IPearlmit pearlmit;
    AOTAP public aotap; //instance of AOTAP

    uint256 internal userAPKey = 0x1;
    uint256 internal userBPKey = 0x2;
    address public owner = vm.addr(userAPKey);
    address public tokenBeneficiary = vm.addr(userBPKey);

    event Transfer(
        address indexed _from,
        address indexed _to,
        uint256 indexed _tokenId
    );
    event Approval(
        address indexed _owner,
        address indexed _approved,
        uint256 indexed _tokenId
    );

    function setUp() public override {
        vm.deal(owner, 1000 ether); //give owner some ether
        vm.deal(tokenBeneficiary, 1000 ether); //give tokenBeneficiary some ether
        vm.label(owner, "owner"); //label address for test traces
        vm.label(tokenBeneficiary, "tokenBeneficiary"); //label address for test traces

        pearlmit = IPearlmit(
            address(new Pearlmit("Pearlmit", "1", owner, type(uint256).max))
        ); // NOTE: setting nativeValueToCheckPauseState in Pearlmit to max to avoid potentially setting pause state unintentionally
        aotap = new AOTAP(pearlmit, address(owner)); //deploy AOTAP and set address to owner

        super.setUp();
    }

    /// @notice only broker can mint
    function test_cannot_mint_no_broker() public {
        uint128 expiry = uint128(block.timestamp + 7 days);
        vm.expectRevert(OnlyBroker.selector);
        aotap.mint(address(owner), expiry, 1, 1, 1);
    }

    /// @notice only token owner or approved account can set the token URI
    function test_set_uri_not_approved() public {
        vm.startPrank(owner);
        aotap.brokerClaim();
        uint128 expiry = uint128(block.timestamp + 7 days);
        uint256 tokenId = aotap.mint(address(owner), expiry, 1, 1, 1);
        uint256 balance = aotap.balanceOf(address(owner));
        assertEq(balance, 1);
        aotap.transferFrom(owner, tokenBeneficiary, 1);
        uint256 balanceBeneficiary = aotap.balanceOf(address(tokenBeneficiary));
        assertEq(balanceBeneficiary, 1);
        assertEq(aotap.balanceOf(address(owner)), 0);

        vm.expectRevert(NotAuthorized.selector);
        aotap.setTokenURI(1, "https://tapioca.games");
        string memory tokenURI = aotap.tokenURI(1);
        assertEq(tokenURI, "");
        vm.stopPrank();
    }

    /// @notice can't set URI on token that hasn't been minted
    function test_set_uri_not_invalid_id() public {
        vm.startPrank(owner);
        vm.expectRevert(bytes("ERC721: invalid token ID"));
        aotap.setTokenURI(1, "https://tapioca.games");
        string memory tokenURI = aotap.tokenURI(1);
        assertEq(tokenURI, "");
        vm.stopPrank();
    }

    /// @notice owner can successfully set URI on their token
    function test_set_uri() public {
        vm.startPrank(owner);
        aotap.brokerClaim();
        uint128 expiry = uint128(block.timestamp + 7 days);
        uint256 tokenId = aotap.mint(address(owner), expiry, 1, 1, 1);
        uint256 balance = aotap.balanceOf(address(owner));
        assertEq(balance, 1);
        aotap.setTokenURI(1, "https://tapioca.games");
        string memory tokenURI = aotap.tokenURI(1);
        assertEq(tokenURI, "https://tapioca.games");
        vm.stopPrank();
    }

    /// @notice broker can mint aoTAP
    function test_mint_aoTAP() public {
        vm.startPrank(owner);
        aotap.brokerClaim();
        uint128 expiry = uint128(block.timestamp + 7 days);
        uint256 tokenId = aotap.mint(address(owner), expiry, 1, 1, 1);
        uint256 balance = aotap.balanceOf(address(owner));
        assertEq(balance, 1);
        vm.stopPrank();
    }

    /// @notice broker can mint multiple aoTAP
    function test_mint_several_aoTAP() public {
        vm.startPrank(owner);
        aotap.brokerClaim();
        uint128 expiry = uint128(block.timestamp + 7 days);
        uint256 i;
        for (i; i < 10; i++) {
            uint256 tokenId = aotap.mint(address(owner), expiry, 1, 1, 1);
            uint256 balance = aotap.balanceOf(address(owner));
            assertEq(balance, i + 1);
        }
        uint256 _balance = aotap.balanceOf(address(owner));
        assertEq(_balance, i);
        vm.stopPrank();
    }

    /// @notice existence check works correctly for minted aoTAP tokens
    function test_exists() public {
        vm.startPrank(owner);
        aotap.brokerClaim();
        uint128 expiry = uint128(block.timestamp + 7 days);
        uint256 tokenId = aotap.mint(address(owner), expiry, 1, 1, 1);
        uint256 balance = aotap.balanceOf(address(owner));
        assertEq(balance, 1);
        vm.stopPrank();
        bool exists = aotap.exists(1);
        assertEq(exists, true);
    }

    /// @notice transferFrom works
    function test_transfer_from() public {
        vm.startPrank(owner);
        aotap.brokerClaim();
        uint128 expiry = uint128(block.timestamp + 7 days);
        aotap.mint(owner, expiry, 1, 1, 1);
        aotap.safeTransferFrom(owner, tokenBeneficiary, 1);
        address new_owner = aotap.ownerOf(1);
        assertEq(tokenBeneficiary, new_owner);
        uint256 bal = aotap.balanceOf(tokenBeneficiary);
        assertEq(bal, 1);
        vm.stopPrank();
    }

    /// @notice burning works
    function test_burn() public {
        vm.startPrank(owner);
        aotap.brokerClaim();
        uint128 expiry = uint128(block.timestamp + 7 days);
        aotap.mint(owner, expiry, 1, 1, 1);
        aotap.burn(1);
        uint256 bal = aotap.balanceOf(owner);
        assertEq(bal, (0));
        vm.stopPrank();
    }

    /// @notice only owner or approved can burn
    function test_fail_burning() public {
        vm.startPrank(owner);
        aotap.brokerClaim();
        uint128 expiry = uint128(block.timestamp + 7 days);
        aotap.mint(owner, expiry, 1, 1, 1);
        vm.stopPrank();
        vm.startPrank(tokenBeneficiary);
        vm.expectRevert(NotAuthorized.selector);
        aotap.burn(1);
        vm.stopPrank();
    }

    /// @notice approved account can mint
    function test_approvals() public {
        vm.startPrank(owner);
        aotap.brokerClaim();
        uint128 expiry = uint128(block.timestamp + 7 days);
        aotap.mint(owner, expiry, 1, 1, 1);
        aotap.approve(tokenBeneficiary, 1);
        address _owner = aotap.ownerOf(1);
        assertEq(owner, _owner);
        address _approved = aotap.getApproved(1);
        assertEq(tokenBeneficiary, _approved);
        vm.stopPrank();
    }

    /// @notice getApproved works correctly
    function test_get_approved() public {
        vm.startPrank(owner);
        aotap.brokerClaim();
        uint128 expiry = uint128(block.timestamp + 7 days);
        aotap.mint(owner, expiry, 1, 1, 1);
        aotap.approve(tokenBeneficiary, 1);
        address _approved = aotap.getApproved(1);
        assertEq(_approved, tokenBeneficiary);
        vm.stopPrank();
    }

    /// @notice setApprovalForAll works correctly
    function test_set_approval_for_all() public {
        vm.startPrank(owner);
        aotap.brokerClaim();
        uint128 expiry = uint128(block.timestamp + 7 days);
        aotap.mint(owner, expiry, 1, 1, 1);
        aotap.setApprovalForAll(tokenBeneficiary, true);
        bool _approved = aotap.isApprovedForAll(owner, tokenBeneficiary);
        assertEq(_approved, true);
        vm.stopPrank();
    }

    // NOTE: expiry time in minting can be in the past
    function test_mint_past_expiry_time() public {
        vm.startPrank(owner);
        aotap.brokerClaim();
        vm.warp(block.timestamp + 7 days);
        uint128 expiry = uint128(block.timestamp - 7 days);
        uint256 tokenId = aotap.mint(address(owner), expiry, 1, 1, 1);
        uint256 balance = aotap.balanceOf(address(owner));
        assertEq(balance, 1);
        vm.stopPrank();
    }

    // Testing of events

    function testTransferEvent() public {
        vm.startPrank(owner);
        aotap.brokerClaim();
        uint128 expiry = uint128(block.timestamp + 7 days);
        aotap.mint(owner, expiry, 1, 1, 1);
        vm.expectEmit(address(aotap));
        emit IERC721.Transfer(address(owner), address(tokenBeneficiary), 1);
        aotap.safeTransferFrom(owner, tokenBeneficiary, 1);
        vm.stopPrank();
    }

    function testApprovalEvent() public {
        vm.startPrank(owner);
        aotap.brokerClaim();
        uint128 expiry = uint128(block.timestamp + 7 days);
        aotap.mint(owner, expiry, 1, 1, 1);
        vm.expectEmit(address(aotap));
        emit IERC721.Approval(address(owner), address(tokenBeneficiary), 1);
        aotap.approve(tokenBeneficiary, 1);
        vm.stopPrank();
    }

    function testApprovalForAllEvent() public {
        vm.startPrank(owner);
        aotap.brokerClaim();
        uint128 expiry = uint128(block.timestamp + 7 days);
        aotap.mint(owner, expiry, 1, 1, 1);
        vm.expectEmit(address(aotap));
        emit IERC721.ApprovalForAll(
            address(owner),
            address(tokenBeneficiary),
            true
        );
        aotap.setApprovalForAll(tokenBeneficiary, true);
        vm.stopPrank();
    }
}
