// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// External
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Tapioca
import {
    UnitBaseTest,
    TapiocaOptionLiquidityProvision,
    YieldBox1155Mock,
    Pearlmit,
    IPearlmit,
    ICluster
} from "../../UnitBaseTest.sol";
import {SingularityPool} from "contracts/options/TapiocaOptionLiquidityProvision.sol";

contract TolpBaseTest is UnitBaseTest {
    TapiocaOptionLiquidityProvision public tolp;

    event Mint(
        address indexed to,
        uint256 indexed sglAssetId,
        address sglAddress,
        uint256 tolpTokenId,
        uint128 lockDuration,
        uint128 ybShares
    );
    event Burn(address indexed from, uint256 indexed sglAssetId, address sglAddress, uint256 tolpTokenId);

    error NotRegistered();
    error InvalidSingularity();
    error DurationTooShort();
    error DurationTooLong();
    error SharesNotValid();
    error SingularityInRescueMode();
    error SingularityNotActive();
    error PositionExpired();
    error LockNotExpired();
    error AlreadyActive();
    error AssetIdNotValid();
    error DuplicateAssetId();
    error AlreadyRegistered();
    error NotAuthorized();
    error NotInRescueMode();
    error NotActive();
    error RescueCooldownNotReached();
    error TransferFailed();
    error TobIsHolder();
    error NotValid();
    error EmergencySweepCooldownNotReached();

    function setUp() public virtual override {
        super.setUp();

        tolp = createTolpInstance(address(yieldBox), 7 days, IPearlmit(address(pearlmit)), adminAddr);
    }

    /**
     * @dev Register 5 singularity pools, and set the last one in rescue mode
     */
    modifier registerSingularityPool() {
        _registerSingularityPool();
        _;
    }

    function _registerSingularityPool() internal {
        vm.startPrank(adminAddr);
        tolp.registerSingularity(IERC20(address(0x1)), 1, 0); // sglAddr, yb assetId, weight
        tolp.registerSingularity(IERC20(address(0x2)), 2, 0);
        tolp.registerSingularity(IERC20(address(0x3)), 3, 0);
        tolp.registerSingularity(IERC20(address(0x4)), 4, 0);
        tolp.registerSingularity(IERC20(address(0x5)), 5, 0);
        vm.stopPrank();
    }

    /**
     * @dev Set the asset ID 5 in rescue mode
     */
    modifier setPoolRescue() {
        vm.startPrank(adminAddr);
        tolp.setRescueCooldown(0);
        tolp.requestSglPoolRescue(5);
        tolp.activateSGLPoolRescue(IERC20(address(0x5)));
        vm.stopPrank();
        _;
    }

    /**
     * @dev Create a lock for with Alice on asset ID 1
     * if _lockDuration is 0, it will use the EPOCH_DURATION, if not, uses a multiple of it.
     */
    modifier createLock(address _user, uint256 _weight, uint128 _lockDuration) {
        uint128 lockDuration = uint128(tolp.EPOCH_DURATION());
        lockDuration = _lockDuration == 0 ? lockDuration : lockDuration * _lockDuration;
        _createLock(_user, _weight, lockDuration);
        _;
    }

    function _createLock(address _user, uint256 _weight, uint128 _lockDuration) internal {
        (, uint256 shares) = yieldBox.depositAsset(1, _user, _weight);
        vm.startPrank(_user);
        yieldBox.setApprovalForAll(address(pearlmit), true);
        pearlmit.approve(1155, address(yieldBox), 1, address(tolp), type(uint200).max, uint48(block.timestamp + 1));
        tolp.lock(_user, IERC20(address(0x1)), _lockDuration, uint128(shares));
        vm.stopPrank();
    }

    modifier setSglInRescue(IERC20 sgl, uint256 assetId) {
        vm.startPrank(adminAddr);
        tolp.requestSglPoolRescue(assetId);
        vm.warp(block.timestamp + tolp.rescueCooldown());
        tolp.activateSGLPoolRescue(sgl);
        vm.stopPrank();
        _;
    }
}
