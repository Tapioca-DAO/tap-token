// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

/**
 * Tap Token core contracts
 */
import {TapiocaOptionLiquidityProvision} from "contracts/options/TapiocaOptionLiquidityProvision.sol";

/**
 * Peripheral contracts
 */
import {IWrappedNative} from "yieldbox/interfaces/IWrappedNative.sol";
import {YieldBoxURIBuilder} from "yieldbox/YieldBoxURIBuilder.sol";
import {Pearlmit, IPearlmit} from "tapioca-periph/pearlmit/Pearlmit.sol";
import {YieldBox} from "yieldbox/YieldBox.sol";

/**
 * Tests
 */
import "forge-std/Test.sol";

contract UnitBaseTest is Test {
    uint256 internal adminPKey = 0x1;
    address public adminAddr = vm.addr(adminPKey);

    /**
     * Tap Token core contracts
     */
    function createTolpInstance(address _yieldBox, uint256 _epochDuration, IPearlmit _pearlmit, address _owner)
        internal
        returns (TapiocaOptionLiquidityProvision)
    {
        return new TapiocaOptionLiquidityProvision(_yieldBox, _epochDuration, _pearlmit, _owner);
    }

    /**
     * Peripheral contracts
     */
    function createPearlmit(address _owner) internal returns (Pearlmit) {
        return new Pearlmit("Pearlmit", "1", _owner, 0);
    }

    function createYieldBox(Pearlmit _pearlmit, address _owner) internal returns (YieldBox) {
        YieldBoxURIBuilder uriBuilder = new YieldBoxURIBuilder();
        return new YieldBox(IWrappedNative(address(0)), uriBuilder, _pearlmit, _owner);
    }
}
