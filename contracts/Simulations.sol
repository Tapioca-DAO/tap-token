// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;
import {TWAML} from "./twAML.sol";

// import "hardhat/console.sol";

contract Simulations is TWAML {
    // tOB simulations
    function test() public {
        uint256 cumulative;
        uint256 averageMagnitude;
        for (uint256 p; p < 10; p++) {
            uint256 magnitude = computeMagnitude(10, cumulative);
            uint256 discount = computeTarget(5, 50, magnitude, cumulative);

            averageMagnitude = computeAM(averageMagnitude, magnitude, p + 1);
            cumulative = computeCumulative(10, cumulative, magnitude);

            // console.log("participants: %s", p);
            // console.log("discount: %s", discount);
            // console.log("cumulative: %s", cumulative);
            // console.log("averageMagnitude: %s", averageMagnitude);
            // console.log("magnitude: %s", magnitude);
            // console.log("");
        }
    }

    function computeAM(
        uint256 am,
        uint256 m,
        uint256 p
    ) public pure returns (uint256) {
        return (am + m) / p;
    }

    function computeCumulative(
        uint256 weight,
        uint256 cumulative,
        uint256 am
    ) public pure returns (uint256) {
        bool divergenceForce = weight >= cumulative;
        if (divergenceForce) {
            cumulative += am;
        } else {
            if (cumulative > am) {
                cumulative -= am;
            } else {
                cumulative = 0;
            }
        }

        return cumulative;
    }
}
