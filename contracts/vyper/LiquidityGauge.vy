# @version ^0.2.0


"""
@title Liquidity Gauge
@author Curve Finance
@license MIT
@notice Used for measuring liquidity and insurance
"""

from vyper.interfaces import ERC20

interface TapToken:
    def balanceOf(addr: address) -> uint256: view

interface Controller:
    def period() -> int128: view
    def period_write() -> int128: nonpayable
    def period_timestamp(p: int128) -> uint256: view
    def gauge_relative_weight(addr: address, time: uint256) -> uint256: view
    def voting_escrow() -> address: view
    def checkpoint(): nonpayable
    def checkpoint_gauge(addr: address): nonpayable

interface Minter:
    def token() -> address: view
    def controller() -> address: view
    def minted(user: address, gauge: address) -> uint256: view

interface VotingEscrow:
    def user_point_epoch(addr: address) -> uint256: view
    def user_point_history__ts(addr: address, epoch: uint256) -> uint256: view

interface ERC20Extended:
    def symbol() -> String[26]: view


event Deposit:
    provider: indexed(address)
    value: uint256

event Withdraw:
    provider: indexed(address)
    value: uint256

event UpdateLiquidityLimit:
    user: address
    original_balance: uint256
    original_supply: uint256
    working_balance: uint256
    working_supply: uint256

event CommitOwnership:
    admin: address

event ApplyOwnership:
    admin: address


TOKENLESS_PRODUCTION: constant(uint256) = 100
BOOST_WARMUP: constant(uint256) = 2 * 7 * 86400
WEEK: constant(uint256) = 604800

minter: public(address)
TAP_token: public(address)
lp_token: public(address)
controller: public(address)
voting_escrow: public(address)
balanceOf: public(HashMap[address, uint256])
totalSupply: public(uint256)
future_epoch_time: public(uint256)

# caller -> recipient -> can deposit?
approved_to_deposit: public(HashMap[address, HashMap[address, bool]])

working_balances: public(HashMap[address, uint256])
working_supply: public(uint256)

# The goal is to be able to calculate ∫(rate * balance / totalSupply dt) from 0 till checkpoint
# All values are kept in units of being multiplied by 1e18
period: public(int128)
period_timestamp: public(uint256[100000000000000000000000000000])

# 1e18 * ∫(rate(t) / totalSupply(t) dt) from 0 till checkpoint
integrate_inv_supply: public(uint256[100000000000000000000000000000])  # bump epoch when rate() changes

# 1e18 * ∫(rate(t) / totalSupply(t) dt) from (last_action) till checkpoint
integrate_inv_supply_of: public(HashMap[address, uint256])
integrate_checkpoint_of: public(HashMap[address, uint256])


# ∫(balance * rate(t) / totalSupply(t) dt) from 0 till checkpoint
# Units: rate * t = already number of coins per address to issue
integrate_fraction: public(HashMap[address, uint256])

inflation_rate: public(uint256)

admin: public(address)
future_admin: public(address)  # Can and will be a smart contract
is_killed: public(bool)

name: public(String[64])
symbol: public(String[32])

initialized: public(bool)

@external
def __init__(lp_addr: address, _minter: address, _admin: address):
    """
    @notice Contract constructor
    @param lp_addr Liquidity Pool contract address
    @param _minter Minter contract address
    @param _admin Admin who can kill the gauge
    """

    assert lp_addr != ZERO_ADDRESS,"lp not valid"
    assert _minter != ZERO_ADDRESS,"minter not valid"

    self.initialized = True

    _symbol: String[26] = ERC20Extended(lp_addr).symbol()
    self.name = concat("tapioca.loan ", _symbol, " Gauge Deposit")
    self.symbol = concat(_symbol, "-gauge")

    self.lp_token = lp_addr
    self.minter = _minter
    TAP_addr: address = Minter(_minter).token()
    self.TAP_token = TAP_addr
    controller_addr: address = Minter(_minter).controller()
    self.controller = controller_addr
    self.voting_escrow = Controller(controller_addr).voting_escrow()
    self.period_timestamp[0] = block.timestamp
    self.admin = _admin

# Internal methods
@internal
def _update_liquidity_limit(addr: address, l: uint256, L: uint256):
    """
    @notice Calculate limits which depend on the amount of TAP token per-user.
            Effectively it calculates working balances to apply amplification
            of TAP production by Tapioca
    @param addr User address
    @param l User's amount of liquidity (LP tokens)
    @param L Total amount of liquidity (LP tokens)
    """
    # To be called after totalSupply is updated
    _voting_escrow: address = self.voting_escrow

    lim: uint256 = 0
    if(l>0) and (L>0):
        lim = 10**18 * l/L
 
    old_bal: uint256 = self.working_balances[addr]
    self.working_balances[addr] = lim
    _working_supply: uint256 = self.working_supply + lim - old_bal
    self.working_supply = _working_supply

    log UpdateLiquidityLimit(addr, l, L, lim, _working_supply)

@internal
def _checkpoint(addr: address):
    """
    @notice Checkpoint for a user
    @param addr User address
    """
    _controller: address = self.controller
    _period: int128 = self.period
    _period_time: uint256 = self.period_timestamp[_period]
    _integrate_inv_supply: uint256 = self.integrate_inv_supply[_period]
    rate: uint256 = self.inflation_rate
    new_rate: uint256 = rate
    prev_future_epoch: uint256 = self.future_epoch_time
   
    Controller(_controller).checkpoint_gauge(self)

    _working_balance: uint256 = self.working_balances[addr]

    available: uint256 = TapToken(self.TAP_token).balanceOf(self.TAP_token)

    if self.is_killed:
        available = 0  # Stop distributing inflation as soon as killed

    # Update integral of 1/supply
    if block.timestamp > _period_time:
        w: uint256 = Controller(_controller).gauge_relative_weight(self, block.timestamp)
        _integrate_inv_supply =  w * available / 10**18


    _period += 1
    self.period = _period
    self.period_timestamp[_period] = block.timestamp
    self.integrate_inv_supply[_period] = _integrate_inv_supply

    # Update user-specific integrals
    self.integrate_fraction[addr] += _working_balance * (_integrate_inv_supply - self.integrate_inv_supply_of[addr]) / 10 ** 18
    self.integrate_inv_supply_of[addr] = _integrate_inv_supply
    self.integrate_checkpoint_of[addr] = block.timestamp


# Owner methods
@external
def kill_me():
    assert msg.sender == self.admin,"unauthorized"
    self.is_killed = not self.is_killed


@external
def commit_transfer_ownership(addr: address):
    """
    @notice Transfer ownership of GaugeController to `addr`
    @param addr Address to have ownership transferred to
    """
    assert msg.sender == self.admin,"unauthorized"  # dev: admin only
    self.future_admin = addr
    log CommitOwnership(addr)


@external
def apply_transfer_ownership():
    """
    @notice Apply pending ownership transfer
    """
    assert msg.sender == self.admin,"unauthorized"  # dev: admin only
    _admin: address = self.future_admin
    assert _admin != ZERO_ADDRESS,"admin not valid"  # dev: admin not set
    self.admin = _admin
    log ApplyOwnership(_admin)

# View methods
@external
@view
def integrate_checkpoint() -> uint256:
    return self.period_timestamp[self.period]



# Write methods
@external
def user_checkpoint(addr: address) -> bool:
    """
    @notice Record a checkpoint for `addr`
    @param addr User address
    @return bool success
    """
    assert (msg.sender == addr) or (msg.sender == self.minter),"unauthorized"  # dev: unauthorized
    self._checkpoint(addr)
    self._update_liquidity_limit(addr, self.balanceOf[addr], self.totalSupply)
    return True

@external
def claimable_tokens(addr: address) -> uint256:
    """
    @notice Get the number of claimable tokens per user
    @dev This function should be manually changed to "view" in the ABI
    @return uint256 number of claimable tokens per user
    """
    self._checkpoint(addr)
    return self.integrate_fraction[addr] - Minter(self.minter).minted(addr, self)


@external
def kick(addr: address):
    """
    @notice Kick `addr` for abusing their boost
    @dev Only if either they had another voting event, or their voting escrow lock expired
    @param addr Address to kick
    """
    _voting_escrow: address = self.voting_escrow
    t_last: uint256 = self.integrate_checkpoint_of[addr]
    t_ve: uint256 = VotingEscrow(_voting_escrow).user_point_history__ts(
        addr, VotingEscrow(_voting_escrow).user_point_epoch(addr)
    )
    _balance: uint256 = self.balanceOf[addr]

    assert ERC20(self.voting_escrow).balanceOf(addr) == 0 or t_ve > t_last,"kick not allowed" 
    assert self.working_balances[addr] > _balance * TOKENLESS_PRODUCTION / 100,"kick not needed"  

    self._checkpoint(addr)
    self._update_liquidity_limit(addr, self.balanceOf[addr], self.totalSupply)


@external
def set_approve_deposit(addr: address, can_deposit: bool):
    """
    @notice Set whether `addr` can deposit tokens for `msg.sender`
    @param addr Address to set approval on
    @param can_deposit bool - can this account deposit for `msg.sender`?
    """
    self.approved_to_deposit[addr][msg.sender] = can_deposit


@external
@nonreentrant('lock')
def deposit(_value: uint256, addr: address = msg.sender):
    """
    @notice Deposit `_value` LP tokens
    @param _value Number of tokens to deposit
    @param addr Address to deposit for
    """
    if addr != msg.sender:
        assert self.approved_to_deposit[msg.sender][addr],"unauthorized"

    self._checkpoint(addr)

    if _value != 0:
        _balance: uint256 = self.balanceOf[addr] + _value
        _supply: uint256 = self.totalSupply + _value
        self.balanceOf[addr] = _balance
        self.totalSupply = _supply

        self._update_liquidity_limit(addr, _balance, _supply)

        assert ERC20(self.lp_token).transferFrom(msg.sender, self, _value),"deposit failed"

    log Deposit(addr, _value)


@external
@nonreentrant('lock')
def withdraw(_value: uint256):
    """
    @notice Withdraw `_value` LP tokens
    @param _value Number of tokens to withdraw
    """
    #self._checkpoint(msg.sender)

    _balance: uint256 = self.balanceOf[msg.sender] - _value
    _supply: uint256 = self.totalSupply - _value
    self.balanceOf[msg.sender] = _balance
    self.totalSupply = _supply

    self._update_liquidity_limit(msg.sender, _balance, _supply)

    assert ERC20(self.lp_token).transfer(msg.sender, _value),"withdraw failed"

    log Withdraw(msg.sender, _value)