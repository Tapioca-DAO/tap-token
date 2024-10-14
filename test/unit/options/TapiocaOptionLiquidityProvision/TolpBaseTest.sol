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

import {TapiocaOmnichainExtExec} from "tap-utils/tapiocaOmnichainEngine/extension/TapiocaOmnichainExtExec.sol";
import {TOFTOptionsReceiverModule} from "tapiocaz/tOFT/modules/TOFTOptionsReceiverModule.sol";
import {TOFTGenericReceiverModule} from "tapiocaz/tOFT/modules/TOFTGenericReceiverModule.sol";
import {TOFTMarketReceiverModule} from "tapiocaz/tOFT/modules/TOFTMarketReceiverModule.sol";
import {TOFTInitStruct, TOFTModulesInitStruct} from "tap-utils/interfaces/oft/ITOFT.sol";
import {mTOFTReceiver} from "tapiocaz/tOFT/modules/mTOFTReceiver.sol";
import {IYieldBox, TokenType} from "yieldbox/YieldBox.sol";
import {TOFTReceiver} from "tapiocaz/tOFT/modules/TOFTReceiver.sol";
import {TOFTSender} from "tapiocaz/tOFT/modules/TOFTSender.sol";
import {TOFTVault} from "tapiocaz/tOFT/TOFTVault.sol";
import {TOFT} from "tapiocaz/tOFT/TOFT.sol";

import "forge-std/console.sol";

contract TolpBaseTest is UnitBaseTest {
    TapiocaOptionLiquidityProvision public tolp;
    TOFT public toftSglEthMarket;
    address public ybStratToftSglEthMarket;
    uint256 public ybAssetIdToftSglEthMarket;

    uint256 public MIN_USDO_PARTICIPATION_BOUNDARY = 1e18;
    uint256 public MAX_USDO_PARTICIPATION_BOUNDARY = 1e27;

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

        tolp = createTolpInstance(address(yieldBox), 7 days, IPearlmit(address(pearlmit)), address(penrose), adminAddr);
        toftSglEthMarket = createTOFT(
            "TOFT SGL ETH Market",
            address(yieldBox),
            address(cluster),
            address(singularityEthMarket),
            address(pearlmit),
            EID_A,
            EID_A
        );
        ybStratToftSglEthMarket = address(createYieldBoxEmptyStrategy(address(yieldBox), address(toftSglEthMarket)));
        ybAssetIdToftSglEthMarket = IYieldBox(address(yieldBox)).registerAsset(
            TokenType.ERC20, address(toftSglEthMarket), ybStratToftSglEthMarket, 0
        );
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
        tolp.registerSingularity(IERC20(address(toftSglEthMarket)), ybAssetIdToftSglEthMarket, 0); // sglAddr, yb assetId, weight
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
        tolp.requestSglPoolRescue(ybAssetIdToftSglEthMarket);
        tolp.activateSGLPoolRescue(IERC20(address(toftSglEthMarket)));
        vm.stopPrank();
        _;
    }

    /**
     * @notice Create a lock for with Alice on asset ID 1
     */
    modifier initAndCreateLock(address _user, uint128 _weight, uint128 _lockDuration) {
        _registerSingularityPool();
        (_weight, _lockDuration) = _boundValues(_weight, _lockDuration);

        _createLock(_user, _weight, _lockDuration);
        _;
    }

    /**
     * @dev Create a lock for with Alice on asset ID 1
     * if _lockDuration is 0, it will use the EPOCH_DURATION, if not, uses a multiple of it.
     */
    modifier createLock(address _user, uint256 _weight, uint128 _lockDuration) {
        _createLock(_user, _weight, _lockDuration);
        _;
    }

    function _createLock(address _user, uint256 _weight, uint128 _lockDuration) internal {
        depositBBCollateral(_user, _weight);
        depositSGLAsset(_user, _weight);

        (, uint256 shares) = yieldBox.depositAsset(ybAssetIdToftSglEthMarket, _user, _weight);
        vm.startPrank(_user);
        yieldBox.setApprovalForAll(address(pearlmit), true);
        pearlmit.approve(
            1155,
            address(yieldBox),
            ybAssetIdToftSglEthMarket,
            address(tolp),
            type(uint200).max,
            uint48(block.timestamp + 1)
        );
        tolp.lock(_user, IERC20(address(toftSglEthMarket)), _lockDuration, uint128(shares), _user);
        vm.stopPrank();
    }

    modifier setSglInRescue(IERC20 sgl, uint256 assetId) {
        _setSglInRescue(sgl, assetId);
        _;
    }

    function _setSglInRescue(IERC20 sgl, uint256 assetId) internal {
        vm.startPrank(adminAddr);
        tolp.requestSglPoolRescue(assetId);
        vm.warp(block.timestamp + tolp.rescueCooldown());
        tolp.activateSGLPoolRescue(sgl);
        vm.stopPrank();
    }

    function _boundValues(uint128 _lockAmount, uint128 _lockDuration) internal returns (uint128, uint128) {
        _lockAmount = uint128(bound(_lockAmount, MIN_USDO_PARTICIPATION_BOUNDARY, MAX_USDO_PARTICIPATION_BOUNDARY));
        _lockDuration = uint128(tolp.EPOCH_DURATION() * bound(_lockDuration, 1, 2));
        return (_lockAmount, _lockDuration);
    }

    // =========
    //  TapiocaZ
    // =========

    function createTOFT(
        string memory name,
        address yieldBox,
        address cluster,
        address erc20,
        address pearlmit,
        uint32 endointId,
        uint32 hostEid
    ) public returns (TOFT toft) {
        TOFTVault toftVault = new TOFTVault(address(erc20));
        TapiocaOmnichainExtExec extExec = new TapiocaOmnichainExtExec();

        TOFTInitStruct memory toftInitStruct = TOFTInitStruct({
            name: name,
            symbol: name,
            endpoint: address(endpoints[endointId]),
            delegate: address(this), // owner
            yieldBox: yieldBox,
            cluster: cluster,
            erc20: erc20,
            vault: address(toftVault),
            hostEid: hostEid,
            extExec: address(extExec),
            pearlmit: IPearlmit(pearlmit)
        });

        {
            TOFTSender toftSender = new TOFTSender(toftInitStruct);
            mTOFTReceiver toftReceiver = new mTOFTReceiver(toftInitStruct);
            TOFTMarketReceiverModule toftMarketReceiverModule = new TOFTMarketReceiverModule(toftInitStruct);
            TOFTOptionsReceiverModule toftOptionsReceiverModule = new TOFTOptionsReceiverModule(toftInitStruct);
            TOFTGenericReceiverModule toftGenericReceiverModule = new TOFTGenericReceiverModule(toftInitStruct);
            TOFTModulesInitStruct memory toftModulesInitStruct = TOFTModulesInitStruct({
                tOFTSenderModule: address(toftSender),
                tOFTReceiverModule: address(toftReceiver),
                marketReceiverModule: address(toftMarketReceiverModule),
                optionsReceiverModule: address(toftOptionsReceiverModule),
                genericReceiverModule: address(toftGenericReceiverModule)
            });
            toft = new TOFT(toftInitStruct, toftModulesInitStruct);
        }
    }
}
