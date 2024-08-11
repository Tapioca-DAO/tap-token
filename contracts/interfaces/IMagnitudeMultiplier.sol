// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

interface ITobMagnitudeMultiplier {
    function getPositiveMagnitudeMultiplier(uint256 _tOLPTokenID) external view returns (uint256);
    function getNegativeMagnitudeMultiplier(uint256 _tOLPTokenID) external view returns (uint256);
}

interface ITwTapMagnitudeMultiplier {
    function getPositiveMagnitudeMultiplier(address _participant, uint256 _amount, uint256 _duration)
        external
        view
        returns (uint256);
    function getNegativeMagnitudeMultiplier(address _participant, uint256 _amount, uint256 _duration)
        external
        view
        returns (uint256);
}
