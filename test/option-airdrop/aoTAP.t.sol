// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.22;

// LZ
import {SendParam, MessagingFee, MessagingReceipt, OFTReceipt} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import {OFTComposeMsgCodec} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTComposeMsgCodec.sol";
import {OptionsBuilder} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";
import {OFTMsgCodec} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTMsgCodec.sol";
import {BytesLib} from "@layerzerolabs/solidity-bytes-utils/contracts/BytesLib.sol";
import {Origin} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OApp.sol";

import {IMessagingChannel} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessagingChannel.sol";

// External
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

//Tapioca
import {ITapOFTv2, LockTwTapPositionMsg, UnlockTwTapPositionMsg, LZSendParam, ERC20PermitStruct, ERC721PermitStruct, ERC20PermitApprovalMsg, ERC721PermitApprovalMsg, ClaimTwTapRewardsMsg, RemoteTransferMsg} from "@contracts/tokens/TapOFTv2/ITapOFTv2.sol";
import {TapOFTv2Helper, PrepareLzCallData, PrepareLzCallReturn, ComposeMsgData} from "@contracts/tokens/TapOFTv2/extensions/TapOFTv2Helper.sol";
import {TapOFTMsgCoder} from "@contracts/tokens/TapOFTv2/TapOFTMsgCoder.sol";
import {TwTAP, Participation} from "@contracts/governance/twTAP.sol";
import {TapOFTReceiver} from "@contracts/tokens/TapOFTv2/TapOFTReceiver.sol";
import {TapOFTSender} from "@contracts/tokens/TapOFTv2/TapOFTSender.sol";

// Tapioca Tests
import {TapTestHelper} from "../TapTestHelper.t.sol";
import {ERC721Mock} from "../ERC721Mock.sol";
import {TapOFTV2Mock} from "../TapOFTV2Mock.sol";

import {TapOracleMock} from "../Mocks/TapOracleMock.sol";

// Tapioca contracts
import {AOTAP} from "../../contracts/option-airdrop/AOTAP.sol";

// Import contract to test
import {AirdropBroker} from "../../contracts/option-airdrop/AirdropBroker.sol";

// import "forge-std/Test.sol";
import {stdStorage, StdStorage} from "forge-std/Test.sol";   
import "forge-std/console.sol";           

contract aoTapTest is TapTestHelper {



    
}