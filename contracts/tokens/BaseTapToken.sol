// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// Tapioca
import {BaseTapiocaOmnichainEngine} from "tapioca-periph/tapiocaOmnichainEngine/BaseTapiocaOmnichainEngine.sol";
import {BaseTapTokenMsgType} from "./BaseTapTokenMsgType.sol";
import {TwTAP} from "contracts/governance/twTAP.sol";

/*
__/\\\\\\\\\\\\\\\_____/\\\\\\\\\_____/\\\\\\\\\\\\\____/\\\\\\\\\\\_______/\\\\\_____________/\\\\\\\\\_____/\\\\\\\\\____        
 _\///////\\\/////____/\\\\\\\\\\\\\__\/\\\/////////\\\_\/////\\\///______/\\\///\\\________/\\\////////____/\\\\\\\\\\\\\__       
  _______\/\\\________/\\\/////////\\\_\/\\\_______\/\\\_____\/\\\_______/\\\/__\///\\\____/\\\/____________/\\\/////////\\\_      
   _______\/\\\_______\/\\\_______\/\\\_\/\\\\\\\\\\\\\/______\/\\\______/\\\______\//\\\__/\\\_____________\/\\\_______\/\\\_     
    _______\/\\\_______\/\\\\\\\\\\\\\\\_\/\\\/////////________\/\\\_____\/\\\_______\/\\\_\/\\\_____________\/\\\\\\\\\\\\\\\_    
     _______\/\\\_______\/\\\/////////\\\_\/\\\_________________\/\\\_____\//\\\______/\\\__\//\\\____________\/\\\/////////\\\_   
      _______\/\\\_______\/\\\_______\/\\\_\/\\\_________________\/\\\______\///\\\__/\\\_____\///\\\__________\/\\\_______\/\\\_  
       _______\/\\\_______\/\\\_______\/\\\_\/\\\______________/\\\\\\\\\\\____\///\\\\\/________\////\\\\\\\\\_\/\\\_______\/\\\_ 
        _______\///________\///________\///__\///______________\///////////_______\/////_____________\/////////__\///________\///__

*/

abstract contract BaseTapToken is BaseTapiocaOmnichainEngine, BaseTapTokenMsgType {
    uint16 internal constant PT_LOCK_TWTAP = 870;
    uint16 internal constant PT_UNLOCK_TWTAP = 871;
    uint16 internal constant PT_CLAIM_REWARDS = 872;

    /// @dev Can't be set as constructor params because TwTAP is deployed after TapToken. TwTAP constructor needs TapOFT as param.
    TwTAP public twTap;

    constructor(string memory _name, string memory _symbol, address _endpoint, address _delegate)
        BaseTapiocaOmnichainEngine(_name, _symbol, _endpoint, _delegate)
    {}

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
