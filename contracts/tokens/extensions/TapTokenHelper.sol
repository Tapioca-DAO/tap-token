// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// Tapioca
import {
    TapiocaOmnichainEngineHelper,
    PrepareLzCallData,
    PrepareLzCallReturn,
    ComposeMsgData
} from "tapioca-periph/tapiocaOmnichainEngine/extension/TapiocaOmnichainEngineHelper.sol";
import {ITapToken, LockTwTapPositionMsg, UnlockTwTapPositionMsg, ClaimTwTapRewardsMsg} from "../ITapToken.sol";
import {BaseTapTokenMsgType} from "../BaseTapTokenMsgType.sol";
import {TapTokenCodec} from "../TapTokenCodec.sol";

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

/**
 * @title TapTokenHelper
 * @author TapiocaDAO
 * @notice Used as a helper contract to build calls to the TapToken contract and view functions.
 */
contract TapTokenHelper is TapiocaOmnichainEngineHelper, BaseTapTokenMsgType {
    /// =======================
    /// Builder functions
    /// =======================

    /**
     * @notice Encodes the message for the lockTwTapPosition() operation.
     *
     */
    function buildLockTwTapPositionMsg(LockTwTapPositionMsg calldata _lockTwTapPositionMsg)
        public
        pure
        returns (bytes memory)
    {
        return TapTokenCodec.buildLockTwTapPositionMsg(_lockTwTapPositionMsg);
    }

    /**
     * @notice Encodes the message for the unlockTwTapPosition() operation.
     *
     */
    function buildUnlockTwpTapPositionMsg(UnlockTwTapPositionMsg memory _unlockTwTapPositionMsg)
        public
        pure
        returns (bytes memory)
    {
        return TapTokenCodec.buildUnlockTwTapPositionMsg(_unlockTwTapPositionMsg);
    }

    /**
     * @notice Encodes the message for the `claimTwpTapRewards` operation.
     * @dev !!! NOTE: Will get all the claimable rewards for the TwTap position.
     * The caller must ensure that the TwTap contract is approved to claim the.
     * @dev The amount field is trivial in this message as it'll be overwritten by the receiver contract.
     * Any dust amount will be sent to the user on the same chain as TwTap.
     *
     * @param _claimTwTapRewardsMsg The claim rewards message.
     *        - tokenId::uint256: The tokenId of the TwTap position to claim rewards from.
     *        - lzSendParams::LZSendParam[]: The LZ send params to pass on the remote chain. (B->A)
     */
    function buildClaimRewardsMsg(ClaimTwTapRewardsMsg memory _claimTwTapRewardsMsg)
        public
        pure
        returns (bytes memory)
    {
        return TapTokenCodec.buildClaimTwTapRewards(_claimTwTapRewardsMsg);
    }

    /**
     * @inheritdoc TapiocaOmnichainEngineHelper
     */
    function _sanitizeMsgTypeExtended(uint16 _msgType) internal pure override returns (bool) {
        if (_msgType == MSG_LOCK_TWTAP || _msgType == MSG_UNLOCK_TWTAP || _msgType == MSG_CLAIM_REWARDS) {
            return true;
        }
        return false;
    }
}
