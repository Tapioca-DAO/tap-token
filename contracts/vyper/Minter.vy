# @version ^0.2.0
"""
@title Token Minter
@author Curve Finance
@license MIT
"""


interface LiquidityGauge:
    # Presumably, other gauges will provide the same interfaces
    def integrate_fraction(addr: address) -> uint256: view
    def user_checkpoint(addr: address) -> bool: nonpayable

interface TapOFT:
    def createTAP(_to: address, _value: uint256): nonpayable

interface GaugeController:
    def gauge_types(addr: address) -> int128: view


event Minted:
    recipient: indexed(address)
    gauge: address
    minted: uint256


token: public(address)
controller: public(address)
admin: public(address)  # Can be a smart contract
future_admin: public(address)

# user -> gauge -> value
minted: public(HashMap[address, HashMap[address, uint256]])

# minter -> user -> can mint?
allowed_to_mint_for: public(HashMap[address, HashMap[address, bool]])


event CommitOwnership:
    admin: address

event ApplyOwnership:
    admin: address

@external
def __init__(_token: address, _controller: address):
    self.token = _token
    self.controller = _controller
    self.admin = msg.sender


# Internal methods
@internal
def _mint_for(gauge_addr: address, _for: address):
    assert GaugeController(self.controller).gauge_types(gauge_addr) >= 0,"gauge not valid" 

    LiquidityGauge(gauge_addr).user_checkpoint(_for)
    total_mint: uint256 = LiquidityGauge(gauge_addr).integrate_fraction(_for)
    to_mint: uint256 = total_mint - self.minted[_for][gauge_addr]

    if to_mint != 0:
        TapOFT(self.token).createTAP(_for, to_mint)
        self.minted[_for][gauge_addr] = total_mint

        log Minted(_for, gauge_addr, total_mint)


# Owner methods
@external
def commit_transfer_ownership(addr: address):
    """
    @notice Transfer ownership of VotingEscrow contract to `addr`
    @param addr Address to have ownership transferred to
    """
    assert msg.sender == self.admin,"unauthorized"  # dev: admin only
    self.future_admin = addr
    log CommitOwnership(addr)

@external
def apply_transfer_ownership():
    """
    @notice Apply ownership transfer
    """
    assert msg.sender == self.admin,"unauthorized"  # dev: admin only
    _admin: address = self.future_admin
    assert _admin != ZERO_ADDRESS,"admin not valid"  # dev: admin not set
    self.admin = _admin
    log ApplyOwnership(_admin)


# Write methods
@external
@nonreentrant('lock')
def mint(gauge_addr: address):
    """
    @notice Mint everything which belongs to `msg.sender` and send to them
    @param gauge_addr `LiquidityGauge` address to get mintable amount from
    """
    self._mint_for(gauge_addr, msg.sender)

@external
@nonreentrant('lock')
def mint_many(gauge_addrs: address[8]):
    """
    @notice Mint everything which belongs to `msg.sender` across multiple gauges
    @param gauge_addrs List of `LiquidityGauge` addresses
    """
    for i in range(8):
        if gauge_addrs[i] == ZERO_ADDRESS:
            break
        self._mint_for(gauge_addrs[i], msg.sender)

@external
@nonreentrant('lock')
def mint_for(gauge_addr: address, _for: address):
    """
    @notice Mint tokens for `_for`
    @dev Only possible when `msg.sender` has been approved via `toggle_approve_mint`
    @param gauge_addr `LiquidityGauge` address to get mintable amount from
    @param _for Address to mint to
    """
    if self.allowed_to_mint_for[msg.sender][_for]:
        self._mint_for(gauge_addr, _for)

@external
def toggle_approve_mint(minting_user: address):
    """
    @notice allow `minting_user` to mint for `msg.sender`
    @param minting_user Address to toggle permission for
    """
    self.allowed_to_mint_for[minting_user][msg.sender] = not self.allowed_to_mint_for[minting_user][msg.sender]