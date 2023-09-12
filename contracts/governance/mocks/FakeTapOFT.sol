// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {ERC20Mock} from "tapioca-sdk/dist/contracts/mocks/ERC20Mock.sol";
import {TwTAP} from "../twTAP.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract FakeTapOFT is ERC20Mock {
    constructor() ERC20Mock("Fake TapOFT", "FTAP") {}

    function freeMint(uint _amount) public {
        _mint(msg.sender, _amount);
    }

    function fakeClaimAndSendReward(
        TwTAP twTap,
        uint256 _tokenId,
        IERC20[] memory _rewardTokens
    ) public {
        twTap.claimAndSendRewards(_tokenId, _rewardTokens);
    }
}
