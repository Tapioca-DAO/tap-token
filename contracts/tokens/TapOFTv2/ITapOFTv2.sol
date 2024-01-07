// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {SendParam, MessagingFee} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";

interface ITapOFTv2 {
    /**
     * EVENTS
     */
    event LockTwTapReceived(
        address indexed user,
        uint96 duration,
        uint256 amount
    );

    /**
     * ERRORS
     */
    error TwTapAlreadySet();
    error OnlyHostChain(); // Can execute an action only on host chain
}

struct ERC20PermitStruct {
    address owner;
    address spender;
    uint256 value;
    uint256 nonce;
    uint256 deadline;
}

/**
 * @param user The user address to lock in the tokens.
 * @param duration The duration of the lock.
 * @param amount The amount of TAP to lock.
 */
struct LockTwTapPositionMsg {
    address user;
    uint96 duration;
    uint256 amount;
}

/**
 * @notice Encodes the message for the ercPermitApproval() operation.
 */
struct ERC20PermitApprovalMsg {
    address token;
    address owner;
    address spender;
    uint256 value;
    uint256 deadline;
    uint8 v;
    bytes32 r;
    bytes32 s;
}

/**
 * @param sendParam The parameters for the send operation.
 * @param fee The calculated fee for the send() operation.
 *      - nativeFee: The native fee.
 *      - lzTokenFee: The lzToken fee.
 * @param _extraOptions Additional options for the send() operation.
 * @param refundAddress The address to refund the native fee to.
 */
struct LZSendParam {
    SendParam sendParam;
    MessagingFee fee;
    bytes extraOptions;
    address refundAddress;
}
