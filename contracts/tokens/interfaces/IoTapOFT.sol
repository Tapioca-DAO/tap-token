// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IoTapOFT {
    struct Option {
        uint256 amount;
        uint256 redeemableAmount;
        uint256 expiry;
        bool exercised;
    }

    function options(uint256 _id)
        external
        view
        returns (
            uint256 amount,
            uint256 redeemableAmount,
            uint256 expiry,
            bool exercised
        );

    function claim(
        address _for,
        uint256 _amount,
        bytes calldata _oracleData
    ) external returns (uint256 id);

    function calc(uint256 _tapAmount, bytes calldata _oracleData) external view returns (uint256);

    function execute(address _for, uint256 _id) external returns (uint256 transferableAmount, uint256 treasuryAmount);
}
