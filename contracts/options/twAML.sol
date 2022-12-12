// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

abstract contract TWAML {
    /// @notice Compute the minimum weight to participate in the twAML voting mechanism
    /// @param _totalWeight The total weight of the twAML system
    /// @param _minWeightFactor The minimum weight factor in BPS
    function computeMinWeight(uint256 _totalWeight, uint256 _minWeightFactor) internal pure returns (uint256) {
        uint256 mul = (_totalWeight * _minWeightFactor);
        return mul >= 1e4 ? _totalWeight : mul / 1e4;
    }

    function computeMagnitude(uint256 _timeWeight, uint256 _cumulative) internal pure returns (uint256) {
        return sqrt(_timeWeight * _timeWeight + _cumulative * _cumulative) - _cumulative;
    }

    function computeTarget(
        uint256 _dMin,
        uint256 _dMax,
        uint256 _magnitude,
        uint256 _cumulative
    ) internal pure returns (uint256) {
        if (_cumulative == 0) {
            return _dMax;
        }
        uint256 target = (_magnitude * _dMax) / _cumulative;
        target = target > _dMax ? _dMax : target < _dMin ? _dMin : target;
        return target;
    }

    // babylonian method (https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method)
    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}
