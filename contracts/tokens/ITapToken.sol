// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// Tapioca
import {
    ITapiocaOmnichainEngine,
    ERC20PermitApprovalMsg,
    ERC721PermitApprovalMsg,
    LZSendParam,
    ERC20PermitStruct,
    ERC721PermitStruct,
    ERC20PermitApprovalMsg,
    ERC721PermitApprovalMsg,
    RemoteTransferMsg
} from "tapioca-periph/interfaces/periph/ITapiocaOmnichainEngine.sol";
import {IPearlmit} from "tapioca-periph/interfaces/periph/IPearlmit.sol";

/*

████████╗ █████╗ ██████╗ ██╗ ██████╗  ██████╗ █████╗ 
╚══██╔══╝██╔══██╗██╔══██╗██║██╔═══██╗██╔════╝██╔══██╗
   ██║   ███████║██████╔╝██║██║   ██║██║     ███████║
   ██║   ██╔══██║██╔═══╝ ██║██║   ██║██║     ██╔══██║
   ██║   ██║  ██║██║     ██║╚██████╔╝╚██████╗██║  ██║
   ╚═╝   ╚═╝  ╚═╝╚═╝     ╚═╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝
   
*/

interface ITapToken is ITapiocaOmnichainEngine {
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
        TapTokenSender,
        TapTokenReceiver
    }

    struct TapTokenConstructorData {
        uint256 epochDuration;
        address endpoint;
        address contributors;
        address earlySupporters;
        address supporters;
        address lTap;
        address dao;
        address airdrop;
        uint256 governanceEid;
        address owner;
        address tapTokenSenderModule;
        address tapTokenReceiverModule;
        address extExec;
        IPearlmit pearlmit;
    }
}

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
