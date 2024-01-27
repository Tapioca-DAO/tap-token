// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

abstract contract BaseTapTokenMsgType {
    uint16 internal constant MSG_LOCK_TWTAP = 870;
    uint16 internal constant MSG_UNLOCK_TWTAP = 871;
    uint16 internal constant MSG_CLAIM_REWARDS = 872;
}
