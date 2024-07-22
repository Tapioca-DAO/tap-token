// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

/**
 * External
 */
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * Core
 */
import {ITapiocaOracle} from "tapioca-periph/interfaces/periph/ITapiocaOracle.sol";
import {ICluster} from "tapioca-periph/interfaces/periph/ICluster.sol";

/**
 * Tests
 */
import {
    UnitBaseTest,
    TapiocaOptionLiquidityProvision,
    YieldBox1155Mock,
    Pearlmit,
    IPearlmit,
    TwTAP
} from "../../UnitBaseTest.sol";
import {ERC20Mock} from "tapioca-mocks/ERC20Mock.sol";
import {TapTokenMock} from "test/TapTokenMock.sol";

contract twTapBaseTest is UnitBaseTest {
    TapTokenMock public tapOFT;
    TwTAP public twTap;

    ERC20Mock public daiMock;
    ERC20Mock public usdcMock;

    // Constants
    uint256 public EPOCH_DURATION = 1 weeks;

    // Addresses
    address public PAYMENT_TOKEN_RECEIVER = address(bytes20(keccak256("PAYMENT_TOKEN_RECEIVER")));
    address public TAP_CONTRIBUTOR = address(bytes20(keccak256("TAP_CONTRIBUTOR")));
    address public TAP_EARLY_SUPPORTERS = address(bytes20(keccak256("TAP_EARLY_SUPPORTERS")));
    address public TAP_SUPPORTERS = address(bytes20(keccak256("TAP_SUPPORTERS")));
    address public TAP_LBP = address(bytes20(keccak256("TAP_LBP")));
    address public TAP_DAO = address(bytes20(keccak256("TAP_DAO")));
    address public TAP_AIRDROP = address(bytes20(keccak256("TAP_AIRDROP")));

    function setUp() public virtual override {
        super.setUp();

        /**
         * Deploy contracts
         */
        daiMock = new ERC20Mock("DAI", "DAI", 100e18, 18, adminAddr);
        usdcMock = new ERC20Mock("USDC", "USDC", 100e6, 6, adminAddr);

        tapOFT = createTapOftInstance(
            EPOCH_DURATION,
            ENDPOINT_A,
            TAP_CONTRIBUTOR,
            TAP_EARLY_SUPPORTERS,
            TAP_SUPPORTERS,
            TAP_LBP,
            TAP_DAO,
            TAP_AIRDROP,
            EID_A,
            adminAddr
        );
        twTap = createTwTap(payable(tapOFT), IPearlmit(address(pearlmit)), adminAddr);

        /**
         * Set the contract
         */
        vm.startPrank(adminAddr);
        twTap.setCluster(ICluster(address(cluster)));
        cluster.setRoleForContract(adminAddr, keccak256("NEW_EPOCH"), true);
        vm.stopPrank();
    }

    modifier advanceWeeks(uint256 _num) {
        vm.prank(adminAddr);
        twTap.advanceWeek(_num);
        _;
    }

    modifier skipWeeks(uint256 _amount) {
        skip(EPOCH_DURATION * _amount);
        _;
    }

    modifier distributeRewards() {
        vm.startPrank(adminAddr);
        daiMock.mintTo(adminAddr, 1e25);
        usdcMock.mintTo(adminAddr, 1e13);
        twTap.addRewardToken(IERC20(address(daiMock)));
        twTap.addRewardToken(IERC20(address(usdcMock)));
        daiMock.approve(address(twTap), type(uint256).max);
        usdcMock.approve(address(twTap), type(uint256).max);
        twTap.distributeReward(1, 1e25);
        twTap.distributeReward(2, 1e13);
        vm.stopPrank();

        _;
    }

    modifier participate(uint256 _amount, uint256 _duration) {
        _participate(_amount, _duration);
        _;
    }

    function _participate(uint256 _amount, uint256 _duration) internal {
        vm.startPrank(aliceAddr);
        tapOFT.freeMint(aliceAddr, _amount);
        tapOFT.approve(address(pearlmit), _amount);
        pearlmit.approve(20, address(tapOFT), 0, address(twTap), uint200(_amount), uint48(block.timestamp + 1));
        twTap.participate(aliceAddr, _amount, _duration * twTap.EPOCH_DURATION());
        vm.stopPrank();
    }
}
