// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

/**
 * External
 */
import {IERC20 as BoringIERC20} from "@boringcrypto/boring-solidity/contracts/libraries/BoringERC20.sol";

/**
 * Tap Token core contracts
 */
import {TapiocaOptionLiquidityProvision} from "contracts/options/TapiocaOptionLiquidityProvision.sol";
import {TapiocaOptionBroker} from "contracts/options/TapiocaOptionBroker.sol";
import {TapTokenReceiver} from "contracts/tokens/TapTokenReceiver.sol";
import {TapTokenSender} from "contracts/tokens/TapTokenSender.sol";
import {ITapToken} from "contracts/tokens/ITapToken.sol";
import {TwTAP} from "contracts/governance/twTAP.sol";
import {OTAP} from "contracts/options/oTAP.sol";

/**
 * Utils contracts
 */
import {TapiocaOmnichainExtExec} from "tap-utils/tapiocaOmnichainEngine/extension/TapiocaOmnichainExtExec.sol";
import {ILeverageExecutor} from "tap-utils/interfaces/bar/ILeverageExecutor.sol";
import {ITapiocaOracle} from "tap-utils/interfaces/periph/ITapiocaOracle.sol";
import {IZeroXSwapper} from "tap-utils/interfaces/periph/IZeroXSwapper.sol";
import {Module as BBModule} from "tap-utils/interfaces/bar/IMarket.sol";
import {Pearlmit, IPearlmit} from "tap-utils/pearlmit/Pearlmit.sol";
import {ICluster} from "tap-utils/interfaces/periph/ICluster.sol";
import {IPenrose} from "tap-utils/interfaces/bar/IPenrose.sol";
import {Cluster} from "tap-utils/Cluster/Cluster.sol";

/**
 * YieldBox
 */
import {ERC20WithoutStrategy} from "yieldbox/strategies/ERC20WithoutStrategy.sol";
import {IWrappedNative} from "yieldbox/interfaces/IWrappedNative.sol";
import {YieldBox, IYieldBox, TokenType} from "yieldbox/YieldBox.sol";
import {YieldBox1155Mock} from "tapioca-mocks/YieldBox1155Mock.sol";
import {YieldBoxURIBuilder} from "yieldbox/YieldBoxURIBuilder.sol";

/**
 * Bar
 */
import {SimpleLeverageExecutor} from "tapioca-bar/markets/leverage/SimpleLeverageExecutor.sol";
import {SGLInterestHelper} from "tapioca-bar/markets/singularity/SGLInterestHelper.sol";
import {BBDebtRateHelper} from "tapioca-bar/markets/bigBang/BBDebtRateHelper.sol";
import {SGLLiquidation} from "tapioca-bar/markets/singularity/SGLLiquidation.sol";
import {SGLCollateral} from "tapioca-bar/markets/singularity/SGLCollateral.sol";
import {SGLLeverage} from "tapioca-bar/markets/singularity/SGLLeverage.sol";
import {BBLiquidation} from "tapioca-bar/markets/bigBang/BBLiquidation.sol";
import {Singularity} from "tapioca-bar/markets/singularity/Singularity.sol";
import {BBCollateral} from "tapioca-bar/markets/bigBang/BBCollateral.sol";
import {SGLBorrow} from "tapioca-bar/markets/singularity/SGLBorrow.sol";
import {BBLeverage} from "tapioca-bar/markets/bigBang/BBLeverage.sol";
import {SGLInit} from "tapioca-bar/markets/singularity/SGLInit.sol";
import {MarketHelper} from "tapioca-bar/markets/MarketHelper.sol";
import {BBBorrow} from "tapioca-bar/markets/bigBang/BBBorrow.sol";
import {BigBang} from "tapioca-bar/markets/bigBang/BigBang.sol";
import {Penrose} from "tapioca-bar/Penrose.sol";
import {Usdo} from "tapioca-bar/usdo/Usdo.sol";

/**
 * Mocks
 */
import {ZeroXSwapperMock} from "tapioca-mocks/ZeroXSwapperMock.sol";
import {OracleMock} from "tapioca-mocks/OracleMock.sol";
import {ERC20Mock} from "tapioca-mocks/ERC20Mock.sol";
import {UsdoMock} from "tapioca-mocks/UsdoMock.sol";

/**
 * Tests
 */
import {TestHelper} from "test/LZSetup/TestHelper.sol";
import {TapTokenMock} from "test/TapTokenMock.sol";
import "forge-std/Test.sol";

contract UnitBaseTest is TestHelper {
    /**
     * Users
     */
    uint256 internal adminPKey = 0x1;
    address public adminAddr = vm.addr(adminPKey);
    uint256 internal alicePKey = 0x2;
    address public aliceAddr = vm.addr(alicePKey);
    uint256 internal bobPKey = 0x3;
    address public bobAddr = vm.addr(bobPKey);

    /**
     * Peripheral contracts
     */
    YieldBox1155Mock public yieldBox;
    Pearlmit public pearlmit;
    Cluster public cluster;

    /**
     * Bar contracts
     */
    // Mock tokens
    address public tapMockPenrose;
    address public ethTokenPenrose;
    address public ethTokenPenroseStrat;
    UsdoMock public usdoMock;

    // main contracts
    Penrose public penrose;
    BigBang public bigBangMasterContract;
    BigBang public bigBangEthMarket;
    Singularity public singularityMasterContract;
    Singularity public singularityEthMarket;

    // misc
    MarketHelper public marketHelper;
    ITapiocaOracle public bigBangEthOracle;
    uint256 public ethTokenPenroseId;
    uint256 singularityEthMarketAssetId = 1;
    uint256 usdoMockTokenId = 100;

    /**
     * Constants
     */
    uint32 public EID_A = 1;
    address public ENDPOINT_A;

    uint32 public EID_B = 2;
    address public ENDPOINT_B;

    function setUp() public virtual override {
        vm.label(aliceAddr, "Alice");

        // Peripheral contracts
        pearlmit = createPearlmit(adminAddr);
        yieldBox = createYieldBox1155Mock();
        cluster = createCluster(0, adminAddr);

        // Mocks tokens
        tapMockPenrose = address(new ERC20Mock("TAP_MOCK_PENROSE", "TAP_MOCK_PENROSE", 100e18, 18, adminAddr));
        ethTokenPenrose = address(new ERC20Mock("ETH_MOCK_PENROSE", "ETH_MOCK_PENROSE", 100e18, 18, adminAddr));
        usdoMock = new UsdoMock("USDO_MOCK", "USDO_MOCK", 18, adminAddr);

        // Misc
        vm.warp(10000 weeks); // Set it to a big number

        setUpEndpoints(3, LibraryType.UltraLightNode);
        ENDPOINT_A = address(endpoints[EID_A]);
        ENDPOINT_B = address(endpoints[EID_B]);

        // Bar contracts
        marketHelper = new MarketHelper();

        bigBangEthOracle =
            ITapiocaOracle(address(OracleMock(address(new OracleMock("ETH_ORACLE", "ETH_ORACLE", 5e14)))));

        (penrose, bigBangMasterContract, singularityMasterContract) = createPenrose(
            address(yieldBox),
            address(cluster),
            tapMockPenrose,
            ethTokenPenrose,
            IPearlmit(address(pearlmit)),
            adminAddr
        );

        setUpBigBang();
        setUpSingularity();
    }

    /**
     * Tap Token core contracts
     */
    function createTolpInstance(
        address _yieldBox,
        uint256 _epochDuration,
        IPearlmit _pearlmit,
        address _penrose,
        address _owner
    ) internal returns (TapiocaOptionLiquidityProvision) {
        TapiocaOptionLiquidityProvision tolp =
            new TapiocaOptionLiquidityProvision(_yieldBox, _epochDuration, _pearlmit, _penrose, _owner);

        vm.startPrank(_owner);
        tolp.setCluster(ICluster(address(new Cluster(0, _owner))));
        vm.stopPrank();

        return tolp;
    }

    function createTobInstance(
        address _tOLP,
        address _oTAP,
        address payable _tapOFT,
        address _paymentTokenBeneficiary,
        uint256 _epochDuration,
        IPearlmit _pearlmit,
        address _owner
    ) internal returns (TapiocaOptionBroker) {
        TapiocaOptionBroker tob =
            new TapiocaOptionBroker(_tOLP, _oTAP, _tapOFT, _paymentTokenBeneficiary, _epochDuration, _pearlmit, _owner);

        vm.startPrank(_owner);
        tob.setCluster(ICluster(address(new Cluster(0, _owner))));
        vm.stopPrank();

        return tob;
    }

    function createTapOftInstance(
        uint256 _epochDuration,
        address _endpoint,
        address _contributor,
        address _earlySupporters,
        address _supporters,
        address _lbp,
        address _dao,
        address _airdrop,
        uint256 _governanceEid,
        address _owner
    ) internal returns (TapTokenMock) {
        return new TapTokenMock(
            ITapToken.TapTokenConstructorData(
                _epochDuration,
                _endpoint,
                _contributor,
                _earlySupporters,
                _supporters,
                _lbp,
                _dao,
                _airdrop,
                _governanceEid,
                _owner,
                address(new TapTokenSender("", "", _endpoint, _owner, address(0))),
                address(new TapTokenReceiver("", "", _endpoint, _owner, address(0))),
                address(new TapiocaOmnichainExtExec()),
                IPearlmit(address(pearlmit)),
                ICluster(address(cluster))
            )
        );
    }

    function createOtapInstance(IPearlmit _pearlmit, address _owner) internal returns (OTAP) {
        return new OTAP(_pearlmit, _owner);
    }

    function createTwTap(address payable _tapOft, IPearlmit _pearlmit, address _owner) internal returns (TwTAP) {
        return new TwTAP(_tapOft, _pearlmit, _owner);
    }

    /**
     * Peripheral contracts
     */

    //  -------  Utils
    function createPearlmit(address _owner) internal returns (Pearlmit) {
        return new Pearlmit("Pearlmit", "1", _owner, 0);
    }

    // -------  YieldBox
    function createYieldBox(Pearlmit _pearlmit, address _owner) internal returns (YieldBox) {
        YieldBoxURIBuilder uriBuilder = new YieldBoxURIBuilder();
        return new YieldBox(IWrappedNative(address(0)), uriBuilder, _pearlmit, _owner);
    }

    function createYieldBox1155Mock() internal returns (YieldBox1155Mock) {
        return new YieldBox1155Mock();
    }

    function createYieldBoxEmptyStrategy(address _yieldBox, address _erc20) internal returns (ERC20WithoutStrategy) {
        return new ERC20WithoutStrategy(IYieldBox(_yieldBox), BoringIERC20(_erc20));
    }

    // -------  Cluster
    function createCluster(uint32 _lzChainId, address _owner) internal returns (Cluster) {
        return new Cluster(_lzChainId, _owner);
    }

    // -------  Bar
    function createPenrose(
        address _yb,
        address _cluster,
        address _tap,
        address _mainToken,
        IPearlmit _pearlmit,
        address _owner
    ) internal returns (Penrose penrose, BigBang bbMasterContract, Singularity sglMasterContract) {
        address tapStrat = address(createYieldBoxEmptyStrategy(_yb, _tap));
        address mainTokenStrat = address(createYieldBoxEmptyStrategy(_yb, _mainToken));

        uint256 tapAssetId = IYieldBox(_yb).registerAsset(TokenType.ERC20, _tap, tapStrat, 0);
        uint256 mainTokenAssetId = IYieldBox(_yb).registerAsset(TokenType.ERC20, _mainToken, mainTokenStrat, 0);

        penrose = new Penrose(
            IYieldBox(_yb),
            ICluster(_cluster),
            BoringIERC20(_tap),
            BoringIERC20(_mainToken),
            _pearlmit,
            tapAssetId,
            mainTokenAssetId,
            _owner
        );

        bbMasterContract = new BigBang();
        sglMasterContract = new Singularity();
        vm.startPrank(adminAddr);
        penrose.registerBigBangMasterContract(address(bbMasterContract), IPenrose.ContractType.mediumRisk);
        penrose.registerSingularityMasterContract(address(sglMasterContract), IPenrose.ContractType.mediumRisk);
        penrose.setUsdoToken(address(usdoMock), usdoMockTokenId);
        vm.stopPrank();
    }

    struct BigBangInitData {
        address penrose;
        address collateral;
        uint256 collateralId;
        ITapiocaOracle oracle;
        ILeverageExecutor leverageExecutor;
        uint256 debtRateAgainstEth;
        uint256 debtRateMin;
        uint256 debtRateMax;
    }

    function createBigBang(BigBangInitData memory _bbInitData, address _mc) internal returns (BigBang) {
        BigBang bigBang = new BigBang();

        vm.prank(adminAddr);
        Penrose(_bbInitData.penrose).addBigBang(_mc, address(bigBang));
        (
            BigBang._InitMemoryModulesData memory initModulesData,
            BigBang._InitMemoryDebtData memory initDebtData,
            BigBang._InitMemoryData memory initMemoryData,
            address debtRateHelper
        ) = _getBigBangInitData(_bbInitData, bigBang);

        bigBang.init(abi.encode(initModulesData, initDebtData, initMemoryData));

        return bigBang;
    }

    function _getBigBangInitData(BigBangInitData memory _bbInitData, BigBang _bigBang)
        private
        returns (
            BigBang._InitMemoryModulesData memory modulesData,
            BigBang._InitMemoryDebtData memory debtData,
            BigBang._InitMemoryData memory data,
            address debtRateHelper
        )
    {
        // Init modules
        BBLiquidation bbLiq = new BBLiquidation();
        BBBorrow bbBorrow = new BBBorrow();
        BBCollateral bbCollateral = new BBCollateral();
        BBLeverage bbLev = new BBLeverage();

        modulesData =
            BigBang._InitMemoryModulesData(address(bbLiq), address(bbBorrow), address(bbCollateral), address(bbLev));

        debtData = BigBang._InitMemoryDebtData(
            _bbInitData.debtRateAgainstEth, _bbInitData.debtRateMin, _bbInitData.debtRateMax
        );

        data = BigBang._InitMemoryData(
            IPenrose(_bbInitData.penrose),
            BoringIERC20(_bbInitData.collateral),
            _bbInitData.collateralId,
            ITapiocaOracle(address(_bbInitData.oracle)),
            0,
            75000,
            80000,
            _bbInitData.leverageExecutor
        );

        _bigBang.setAssetOracle(address(_bbInitData.oracle), "0x");
        _bigBang.setDebtRateHelper(address(new BBDebtRateHelper()));

        vm.prank(adminAddr);
        Penrose(_bbInitData.penrose).setBigBangEthMarket(address(_bigBang));
    }

    struct SingularityInitData {
        address penrose;
        BoringIERC20 asset;
        uint256 assetId;
        BoringIERC20 collateral;
        uint256 collateralId;
        ITapiocaOracle oracle;
        ILeverageExecutor leverageExecutor;
    }

    function createSingularity(SingularityInitData memory _sglInitData, address _mc) internal returns (Singularity) {
        SGLInterestHelper sglInterestHelper = new SGLInterestHelper();
        Singularity sgl = new Singularity();
        SGLInit sglInit = new SGLInit();

        vm.prank(adminAddr);
        Penrose(_sglInitData.penrose).addSingularity(_mc, address(sgl));

        (
            Singularity._InitMemoryModulesData memory _modulesData,
            Singularity._InitMemoryTokensData memory _tokensData,
            Singularity._InitMemoryData memory _data
        ) = _getSingularityInitData(_sglInitData);

        sgl.init(address(sglInit), abi.encode(_modulesData, _tokensData, _data));

        bytes memory payload = abi.encodeWithSelector(
            Singularity.setSingularityConfig.selector,
            sgl.borrowOpeningFee(),
            0,
            0,
            0,
            0,
            0,
            0,
            address(sglInterestHelper),
            0
        );
        address[] memory mc = new address[](1);
        mc[0] = address(sgl);

        bytes[] memory data = new bytes[](1);
        data[0] = payload;
        vm.prank(adminAddr);
        Penrose(_sglInitData.penrose).executeMarketFn(mc, data, false);

        return sgl;
    }

    function _getSingularityInitData(SingularityInitData memory _sglInitData)
        private
        returns (
            Singularity._InitMemoryModulesData memory modulesData,
            Singularity._InitMemoryTokensData memory tokensData,
            Singularity._InitMemoryData memory data
        )
    {
        SGLLiquidation sglLiq = new SGLLiquidation();
        SGLBorrow sglBorrow = new SGLBorrow();
        SGLCollateral sglCollateral = new SGLCollateral();
        SGLLeverage sglLev = new SGLLeverage();

        modulesData = Singularity._InitMemoryModulesData(
            address(sglLiq), address(sglBorrow), address(sglCollateral), address(sglLev)
        );

        tokensData = Singularity._InitMemoryTokensData(
            _sglInitData.asset, _sglInitData.assetId, _sglInitData.collateral, _sglInitData.collateralId
        );

        data = Singularity._InitMemoryData(
            IPenrose(_sglInitData.penrose),
            ITapiocaOracle(address(_sglInitData.oracle)),
            0,
            75000,
            80000,
            _sglInitData.leverageExecutor
        );
    }

    function createLeverageExecutor(address _swapper, address _cluster, address _pearlmit)
        public
        returns (SimpleLeverageExecutor)
    {
        return new SimpleLeverageExecutor(
            IZeroXSwapper(address(_swapper)), ICluster(_cluster), address(0), IPearlmit(_pearlmit)
        );
    }

    /**
     * @dev Setup a big bang market with ETH as collateral
     * Important to initialize other values before calling this function
     */
    function setUpBigBang() internal {
        ZeroXSwapperMock zeroXSwapper = new ZeroXSwapperMock(cluster, adminAddr);
        SimpleLeverageExecutor leverageExecutor =
            createLeverageExecutor(address(zeroXSwapper), address(cluster), address(pearlmit));

        bigBangEthMarket = createBigBang(
            BigBangInitData({
                penrose: address(penrose),
                collateral: ethTokenPenrose,
                collateralId: ethTokenPenroseId,
                oracle: bigBangEthOracle,
                leverageExecutor: ILeverageExecutor(address(leverageExecutor)),
                debtRateAgainstEth: 0,
                debtRateMin: 0,
                debtRateMax: 0
            }),
            address(bigBangMasterContract)
        );
        vm.label(address(bigBangEthMarket), "BigBangEthMarket");

        vm.startPrank(adminAddr);
        cluster.updateContract(0, address(bigBangEthMarket), true);
        usdoMock.setWhitelist(address(bigBangEthMarket), true);
        vm.stopPrank();
    }

    function depositCollateral(address to, uint256 amount) public {
        vm.startPrank(to);

        // approvals
        BoringIERC20(ethTokenPenrose).approve(address(yieldBox), type(uint256).max);
        BoringIERC20(ethTokenPenrose).approve(address(pearlmit), type(uint256).max);
        yieldBox.setApprovalForAll(address(bigBangEthMarket), true);
        yieldBox.setApprovalForAll(address(pearlmit), true);
        pearlmit.approve(
            1155,
            address(yieldBox),
            ethTokenPenroseId,
            address(bigBangEthMarket),
            type(uint200).max,
            uint48(block.timestamp)
        );

        // Deposit collateral

        deal(address(ethTokenPenrose), to, amount);
        uint256 share = yieldBox.toShare(ethTokenPenroseId, amount, false);
        yieldBox.depositAsset(ethTokenPenroseId, to, share);
        (BBModule[] memory modules, bytes[] memory calls) = marketHelper.addCollateral(to, to, false, 0, share);
        bigBangEthMarket.execute(modules, calls, true);

        // Borrow

        bigBangEthMarket.updateExchangeRate();
        // amount is gonna be <=75% of the amount of collateral converted into USD at `rate` USD per ETH
        uint256 rate = 1e36 / bigBangEthOracle.peekSpot("");
        uint256 amountUsd = (amount * rate * 50) / 1e21;
        (modules, calls) = marketHelper.borrow(to, to, amountUsd);
        bigBangEthMarket.execute(modules, calls, true);
        vm.stopPrank();
    }

    function setUpSingularity() internal {
        // Register tokens in YieldBox

        ZeroXSwapperMock zeroXSwapper = new ZeroXSwapperMock(cluster, adminAddr);
        SimpleLeverageExecutor leverageExecutor =
            createLeverageExecutor(address(zeroXSwapper), address(cluster), address(pearlmit));

        singularityEthMarket = createSingularity(
            SingularityInitData({
                penrose: address(penrose),
                asset: BoringIERC20(ethTokenPenrose),
                assetId: ethTokenPenroseId,
                collateral: BoringIERC20(ethTokenPenrose),
                collateralId: ethTokenPenroseId,
                oracle: bigBangEthOracle,
                leverageExecutor: ILeverageExecutor(address(leverageExecutor))
            }),
            address(singularityMasterContract)
        );
        vm.prank(adminAddr);
        cluster.updateContract(0, address(singularityEthMarket), true);
        vm.label(address(singularityEthMarket), "SingularityEthMarket");
    }

    /**
     * UTILS
     */
    function _resetPrank(address caller) internal {
        vm.stopPrank();
        vm.startPrank(caller);
    }

    modifier assumeGt(uint256 a, uint256 b) {
        vm.assume(a > b);
        _;
    }

    modifier assumeLt(uint256 a, uint256 b) {
        vm.assume(a < b);
        _;
    }
}
