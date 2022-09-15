// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IBoostV2 {
   function boost(address _to,  uint256 _amount, uint256 _endtime,address _from) external;
}