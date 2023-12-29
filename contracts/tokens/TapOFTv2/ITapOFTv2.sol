// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {SendParam, MessagingFee} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";

/**
 * @param _sendParam The parameters for the send operation.
 * @param _fee The calculated fee for the send() operation.
 *      - nativeFee: The native fee.
 *      - lzTokenFee: The lzToken fee.
 * @param _extraOptions Additional options for the send() operation.
 * @param refundAddress The address to refund the native fee to.
 */
struct LZSendParam {
    SendParam _sendParam;
    MessagingFee _fee;
    bytes _extraOptions;
    address refundAddress;
}

struct LockTwTapPositionMsg {
    address user;
    uint256 duration;
}
