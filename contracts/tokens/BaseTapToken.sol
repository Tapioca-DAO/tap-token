// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// Tapioca
import {BaseTapiocaOmnichainEngine} from "tapioca-periph/tapiocaOmnichainEngine/BaseTapiocaOmnichainEngine.sol";
import {IPearlmit} from "tapioca-periph/interfaces/periph/IPearlmit.sol";
import {BaseTapTokenMsgType} from "./BaseTapTokenMsgType.sol";
import {TwTAP} from "contracts/governance/twTAP.sol";

/*

████████╗ █████╗ ██████╗ ██╗ ██████╗  ██████╗ █████╗ 
╚══██╔══╝██╔══██╗██╔══██╗██║██╔═══██╗██╔════╝██╔══██╗
   ██║   ███████║██████╔╝██║██║   ██║██║     ███████║
   ██║   ██╔══██║██╔═══╝ ██║██║   ██║██║     ██╔══██║
   ██║   ██║  ██║██║     ██║╚██████╔╝╚██████╗██║  ██║
   ╚═╝   ╚═╝  ╚═╝╚═╝     ╚═╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝
   
*/

abstract contract BaseTapToken is BaseTapiocaOmnichainEngine, BaseTapTokenMsgType {
    uint16 internal constant PT_LOCK_TWTAP = 870;
    uint16 internal constant PT_UNLOCK_TWTAP = 871;
    uint16 internal constant PT_CLAIM_REWARDS = 872;

    /// @dev Can't be set as constructor params because TwTAP is deployed after TapToken. TwTAP constructor needs TapOFT as param.
    TwTAP public twTap;

    constructor(
        string memory _name,
        string memory _symbol,
        address _endpoint,
        address _delegate,
        address _extExec,
        IPearlmit _pearlmit
    ) BaseTapiocaOmnichainEngine(_name, _symbol, _endpoint, _delegate, _extExec, _pearlmit) {}

    error twTapNotSet();

    modifier twTapExists() {
        if (address(twTap) == address(0)) revert twTapNotSet();
        _;
    }

    /**
     * @notice set the twTAP address, can be done only once.
     */
    function setTwTAP(address _twTap) external virtual {}
}
