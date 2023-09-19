// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {TwTAP} from "../twTAP.sol";

contract FakeTwTAP is TwTAP {
    constructor(
        address payable _tapOFT,
        address _owner,
        address _layerZeroEndpoint,
        uint256 _hostChainID,
        uint256 _minGas
    ) TwTAP(_tapOFT, _owner, _layerZeroEndpoint, _hostChainID, _minGas) {}

    /// @dev For test purposes, return the chain ID given by the LZ endpoint, which should be a mock contract too
    function _getChainId() internal view override returns (uint256) {
        return lzEndpoint.getChainId();
    }
}
