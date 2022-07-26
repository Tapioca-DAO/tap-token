// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import '@boringcrypto/boring-solidity/contracts/ERC20.sol';
import './interfaces/IERC20Metadata.sol';

import 'hardhat/console.sol';

// Should be reimplemented using OFT20 instead of ERC20.
contract Tap is ERC20WithSupply, IERC20Metadata {
    string public name = 'TAP';
    string public symbol = 'TAP';
    uint8 public decimals = 18;

    constructor(
        address team,
        address advisors,
        address globalIncentives,
        address initialDexLiquidity,
        address seed,
        address _private,
        address ido,
        address airdrop
    ) {
        _mint(team, 1e18 * 15_000_000);
        _mint(advisors, 1e18 * 4_000_000);
        _mint(globalIncentives, 1e18 * 50_000_000);
        _mint(initialDexLiquidity, 1e18 * 4_000_000);
        _mint(seed, 1e18 * 10_000_000);
        _mint(_private, 1e18 * 12_000_000);
        _mint(ido, 1e18 * 3_000_000);
        _mint(airdrop, 1e18 * 2_000_000);

        require(totalSupply <= 10e18 * 100_000_000, 'Minter: totalSupply != 10e18 * 100_000_000');
    }
}
