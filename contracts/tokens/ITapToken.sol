// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {SendParam, MessagingFee} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";

interface ITapToken {
    /**
     * EVENTS
     */
    event LockTwTapReceived(address indexed user, uint96 duration, uint256 amount);
    /// @dev twTAP unlock operation received.
    event UnlockTwTapReceived(address indexed user, uint256 tokenId, uint256 amount);

    /**
     * ERRORS
     */
    error TwTapAlreadySet();
    error OnlyHostChain(); // Can execute an action only on host chain

    enum Module {
        NonModule, //0
        TapOFTSender,
        TapOFTReceiver
    }

    /**
     * =======================
     * LZ functions
     * =======================
     */
    function combineOptions(uint32 _eid, uint16 _msgType, bytes calldata _extraOptions)
        external
        view
        returns (bytes memory);

    /**
     * =======================
     * Tapioca added functions
     * =======================
     */
    function getTypedDataHash(ERC20PermitStruct calldata _permitData) external view returns (bytes32);

    function quoteSendPacket(
        SendParam calldata _sendParam,
        bytes calldata _extraOptions,
        bool _payInLzToken,
        bytes calldata _composeMsg,
        bytes calldata /*_oftCmd*/ // @dev unused in the default implementation.
    ) external view returns (MessagingFee memory msgFee);
}

/// =======================
/// ========= LZ ==========
/// =======================

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

/// =============================
/// ========= EXTERNAL ==========
/// =============================

/// ================================
/// ========= TAP COMPOSE ==========
/// ================================

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
 * @param user The user address to unlock the tokens.
 * @param tokenId The tokenId of the TwTap position to unlock.
 */
struct UnlockTwTapPositionMsg {
    address user;
    uint256 tokenId;
}

/**
 * @param tokenId The tokenId of the TwTap position to claim rewards from.
 * @param sendParam The parameter for the send operation.
 */
struct ClaimTwTapRewardsMsg {
    uint256 tokenId;
    LZSendParam[] sendParam;
}

/**
 * @dev Used in TapOFTv2Helper.
 */
struct RemoteTransferMsg {
    address owner;
    LZSendParam lzSendParam;
    bytes composeMsg;
}

/**
 * Structure of an ERC20 permit message.
 */
struct ERC20PermitStruct {
    address owner;
    address spender;
    uint256 value;
    uint256 nonce;
    uint256 deadline;
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
 * Structure of an ERC721 permit message.
 */
struct ERC721PermitStruct {
    address spender;
    uint256 tokenId;
    uint256 nonce;
    uint256 deadline;
}

/**
 * @notice Encodes the message for the ercPermitApproval() operation.
 */
struct ERC721PermitApprovalMsg {
    address token;
    address spender;
    uint256 tokenId;
    uint256 deadline;
    uint8 v;
    bytes32 r;
    bytes32 s;
}
