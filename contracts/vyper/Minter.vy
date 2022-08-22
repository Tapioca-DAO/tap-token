# @version ^0.2.0
"""
@title Liquidity Gauges provisioner
@author Curve Finance
@license MIT
"""

#TODO: update add_rewards with timestamp and retain addedInWeek

interface LiquidityGauge:
    # Presumably, other gauges will provide the same interfaces
    def addRewards(amount:uint256): nonpayable

interface TapOFT:
    def extractTAP(_to: address, _value: uint256): nonpayable
    def balanceOf(addr:address) -> uint256: view
    def approve(_to:address, _value: uint256): nonpayable

interface GaugeController:
    def gauge_types(addr: address) -> int128: view
    def gauge_relative_weight(addr: address, time:uint256) -> uint256:view



event AddedRewards:
    gauge: indexed(address)
    sender: indexed(address)
    added: uint256


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
@view
def _extractable_rewards(gauge_addr: address) -> uint256:
    assert GaugeController(self.controller).gauge_types(gauge_addr) >= 0,"gauge not valid" 
    weight:uint256 = GaugeController(self.controller).gauge_relative_weight(gauge_addr, block.timestamp)
    available: uint256 = TapOFT(self.token).balanceOf(self.token)

    to_add: uint256 =  weight * available / 10**18
    return to_add

@internal 
def _add_rewards(gauge_addr: address, sender: address)-> uint256:
    to_add: uint256 = self._extractable_rewards(gauge_addr)
    available: uint256 = TapOFT(self.token).balanceOf(self.token)

    if to_add > 0:
        assert to_add <= available, "exceeds balance"
        TapOFT(self.token).extractTAP(self, to_add)
        TapOFT(self.token).approve(gauge_addr,to_add)
        LiquidityGauge(gauge_addr).addRewards(to_add)
        log AddedRewards(gauge_addr, sender, to_add)

    return to_add


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


@external
@nonreentrant('lock')
def add_rewards(gauge_addr: address) -> uint256:
    """
    @notice Adds rewards to LiquidityGage
    @param gauge_addr `LiquidityGauge` address
    """
    assert msg.sender == self.admin,"unauthorized"
    return self._add_rewards(gauge_addr, msg.sender)

@external
@nonreentrant('lock')
def add_rewards_many(gauge_addrs: address[8]):
    """
    @notice Adds rewards to multiple gauges
    @param gauge_addrs List of `LiquidityGauge` addresses
    """
    assert msg.sender == self.admin,"unauthorized"

    for i in range(8):
        if gauge_addrs[i] == ZERO_ADDRESS:
            break
        self._add_rewards(gauge_addrs[i], msg.sender)


# View methods
@external
@view
def available_rewards(gauge_addr: address) -> uint256:
    return self._extractable_rewards(gauge_addr)


