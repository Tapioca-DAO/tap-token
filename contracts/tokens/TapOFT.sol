// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import './OFT20/PausableOFT.sol';

/// @title Tapioca OFT token
/// @notice OFT compatible TAP token
contract TapOFT is PausableOFT {
    /// @notice returns the minter address
    address public minter;

    // ==========
    // *EVENTS*
    // ==========
    /// @notice event emitted when a new minter is set
    event MinterUpdated(address indexed _old, address indexed _new);
    /// @notice event emitted when new TAP is minted
    event Minted(address indexed _by, address indexed _to, uint256 _amount);
    /// @notice event emitted when new TAP is burned
    event Burned(address indexed _by, address indexed _from, uint256 _amount);

    // ==========
    // * METHODS *
    // ==========
    /// @notice Creates a new TAP OFT type token
    /// @dev The initial supply of 100M is not minted here as we have the wrap method
    /// @param _lzEndpoint the layer zero address endpoint deployed on the current chain
    constructor(
        address _lzEndpoint,
        address _team,
        address _advisors,
        address _globalIncentives,
        address _initialDexLiquidity,
        address _seed,
        address _private,
        address _ido,
        address _airdrop
    ) PausableOFT('Tapioca', 'TAP', _lzEndpoint) {
        require(_lzEndpoint != address(0), 'Not a valid LZ endpoint');

        _mint(_team, 1e18 * 15_000_000);
        _mint(_advisors, 1e18 * 4_000_000);
        _mint(_globalIncentives, 1e18 * 50_000_000);
        _mint(_initialDexLiquidity, 1e18 * 4_000_000);
        _mint(_seed, 1e18 * 10_000_000);
        _mint(_private, 1e18 * 12_000_000);
        _mint(_ido, 1e18 * 3_000_000);
        _mint(_airdrop, 1e18 * 2_000_000);

        //todo: set trusted remote?
    }

    ///-- Onwer methods --
    function setMinter(address _minter) external onlyOwner {
        require(_minter != address(0), 'invalid address');
        emit MinterUpdated(minter, _minter);
        minter = _minter;
    }

    //-- View methods --
    /// @notice returns token's decimals
    function decimals() public pure override returns (uint8) {
        return 18;
    }

    ///-- Write methods --
    /// @notice mints more TAP
    /// @param _to the receiver address
    /// @param _amount TAP amount
    function createTAP(address _to, uint256 _amount) external whenNotPaused {
        require(msg.sender == minter || msg.sender == owner(), 'unauthorized');
        _mint(_to, _amount);
        emit Minted(msg.sender, _to, _amount);

        //TODO: check rate reduction over time based on Tapioca's emissions rate
    }

    /// @notice burns TAP
    /// @param _from the address to burn from
    /// @param _amount TAP amount
    function removeTAP(address _from, uint256 _amount) external whenNotPaused {
        require(msg.sender == minter || msg.sender == owner(), 'unauthorized');
        _burn(_from, _amount);
        emit Burned(msg.sender, _from, _amount);
    }
}
