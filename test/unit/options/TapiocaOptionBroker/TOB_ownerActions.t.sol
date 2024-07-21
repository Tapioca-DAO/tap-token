// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {TobBaseTest, TapiocaOptionBroker} from "test/unit/options/TapiocaOptionBroker/TobBaseTest.sol";
import {ITapiocaOracle} from "tapioca-periph/interfaces/periph/ITapiocaOracle.sol";
import {ICluster} from "tapioca-periph/interfaces/periph/ICluster.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TOB_ownerActions is TobBaseTest {
    function test_WhenCallingInit() external {
        // it should revert if called multiple times
        tob.init();
        vm.expectRevert();
        tob.init();
    }

    function test_WhenCallingSetVirtualTotalAmount() external {
        // it should revert if not owner
        vm.expectRevert("Ownable: caller is not the owner");
        tob.setVirtualTotalAmount(1);

        vm.startPrank(adminAddr);
        tob.setVirtualTotalAmount(1);
    }

    function test_WhenCallingSetMinWeightFactor() external {
        // it should revert if not owner
        vm.expectRevert("Ownable: caller is not the owner");
        tob.setMinWeightFactor(1);

        vm.startPrank(adminAddr);
        tob.setMinWeightFactor(1);
        assertEq(
            tob.MIN_WEIGHT_FACTOR(), 1, "TOB_ownerActions::test_WhenCallingSetMinWeightFactor: Invalid minWeightFactor"
        );
    }

    function test_WhenCallingSetTapOracle() external {
        // it should revert if not owner
        vm.expectRevert("Ownable: caller is not the owner");
        tob.setTapOracle(ITapiocaOracle(address(0xff)), bytes("420"));

        vm.startPrank(adminAddr);
        tob.setTapOracle(ITapiocaOracle(address(0xff)), bytes("420"));
        assertEq(
            address(tob.tapOracle()), address(0xff), "TOB_ownerActions::test_WhenCallingSetTapOracle: Invalid tapOracle"
        );
        assertEq(
            tob.tapOracleData(), bytes("420"), "TOB_ownerActions::test_WhenCallingSetTapOracle: Invalid tapOracleData"
        );
    }

    function test_WhenCallingSetPaymentToken() external {
        // it should revert if not owner
        vm.expectRevert("Ownable: caller is not the owner");
        tob.setPaymentToken(ERC20(address(0xff)), ITapiocaOracle(address(0xff)), bytes("420"));

        vm.startPrank(adminAddr);
        tob.setPaymentToken(ERC20(address(0xff)), ITapiocaOracle(address(0xff)), bytes("420"));

        (ITapiocaOracle oracle, bytes memory oracleData) = tob.paymentTokens(ERC20(address(0xff)));
        assertEq(address(oracle), address(0xff), "TOB_ownerActions::test_WhenCallingSetPaymentToken: Invalid oracle");
        assertEq(oracleData, bytes("420"), "TOB_ownerActions::test_WhenCallingSetPaymentToken: Invalid oracleData");
    }

    function test_WhenCallingSetPaymentTokenBeneficiary() external {
        // it should revert if not owner
        vm.expectRevert("Ownable: caller is not the owner");
        tob.setPaymentTokenBeneficiary(aliceAddr);

        vm.startPrank(adminAddr);
        tob.setPaymentTokenBeneficiary(aliceAddr);
        assertEq(
            tob.paymentTokenBeneficiary(),
            aliceAddr,
            "TOB_ownerActions::test_WhenCallingSetPaymentTokenBeneficiary: Invalid paymentTokenBeneficiary"
        );
    }

    function test_WhenCallingCollectPaymentTokens() external {
        // it should revert if not owner
        address[] memory paymentTokens = new address[](1);
        paymentTokens[0] = address(daiMock);

        vm.expectRevert("Ownable: caller is not the owner");
        tob.collectPaymentTokens(paymentTokens);

        vm.startPrank(adminAddr);
        tob.collectPaymentTokens(paymentTokens);
    }

    function test_WhenCallingSetCluster() external {
        // it should revert if not owner
        vm.expectRevert("Ownable: caller is not the owner");
        tob.setCluster(ICluster(address(0xff)));

        vm.startPrank(adminAddr);
        tob.setCluster(ICluster(address(0xff)));
        assertEq(address(tob.cluster()), address(0xff), "TOB_ownerActions::test_WhenCallingSetCluster: Invalid cluster");
    }

    function test_WhenCallingSetPause() external {
        // it should revert if not owner
        vm.expectRevert(TapiocaOptionBroker.NotAuthorized.selector);
        tob.setPause(true);

        vm.startPrank(adminAddr);
        tob.setPause(true);
        assertEq(tob.paused(), true, "TOB_ownerActions::test_WhenCallingSetPause: Invalid paused");
    }
}
