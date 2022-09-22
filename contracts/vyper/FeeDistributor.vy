# @version ^0.2.0
"""
@title Fee Distribution
@author Curve Finance
@license MIT
"""

from vyper.interfaces import ERC20


interface VotingEscrow:
    def user_point_epoch(addr: address) -> uint256: view
    def epoch() -> uint256: view
    def user_point_history(addr: address, loc: uint256) -> Point: view
    def point_history(loc: uint256) -> Point: view
    def checkpoint(): nonpayable
    def deposit_for(addr: address, amount: uint256): nonpayable


interface EsTap:
    def mintFor(_for: address, amount: uint256): nonpayable

interface EsTapVesting:
    def vestFor(esTapAmount: uint256, _for: address): nonpayable

event CommitAdmin:
    admin: address

event ApplyAdmin:
    admin: address

event ToggleAllowCheckpointToken:
    toggle_flag: bool

event CheckpointToken:
    time: uint256
    tokens: uint256

event Claimed:
    recipient: indexed(address)
    amount: uint256
    claim_epoch: uint256
    max_epoch: uint256

event EsTapSet:
    newAddr: indexed(address)

event EsTapVestingSet:
    newAddr: indexed(address)


struct Point:
    bias: int128
    slope: int128  # - dweight / dt
    ts: uint256
    blk: uint256  # block


TWO_WEEKS: constant(uint256) = 14 * 86400
TOKEN_CHECKPOINT_DEADLINE: constant(uint256) = 86400

start_time: public(uint256)
time_cursor: public(uint256)
time_cursor_of: public(HashMap[address, uint256])
user_epoch_of: public(HashMap[address, uint256])

last_token_time: public(uint256)
tokens_per_week: public(uint256[1000000000000000])

estap_token: public(address)
estap_vesting: public(address)
voting_escrow: public(address)
token: public(address)
total_received: public(uint256)
token_last_balance: public(uint256)

ve_supply: public(uint256[1000000000000000])  # VE total supply at week bounds

admin: public(address)
future_admin: public(address)
emergency_return: public(address)
is_killed: public(bool)


@external
def __init__(
    _voting_escrow: address,
    _start_time: uint256,
    _token: address,
    _admin: address,
    _emergency_return: address
):
    """
    @notice Contract constructor
    @param _voting_escrow VotingEscrow contract address
    @param _start_time Epoch time for fee distribution to start
    @param _token Fee token address (3CRV)
    @param _admin Admin address
    @param _emergency_return Address to transfer `_token` balance to
                             if this contract is killed
    """
    t: uint256 = _start_time / TWO_WEEKS * TWO_WEEKS
    self.start_time = t
    self.last_token_time = t
    self.time_cursor = t
    self.token = _token
    self.voting_escrow = _voting_escrow
    self.admin = _admin
    self.emergency_return = _emergency_return


# Internal methods
@internal
def _checkpoint_token():
    token_balance: uint256 = ERC20(self.token).balanceOf(self)
    to_distribute: uint256 = token_balance - self.token_last_balance
    self.token_last_balance = token_balance

    t: uint256 = self.last_token_time
    since_last: uint256 = block.timestamp - t
    self.last_token_time = block.timestamp
    this_week: uint256 = t / TWO_WEEKS * TWO_WEEKS
    next_week: uint256 = 0

    for i in range(20):
        next_week = this_week + TWO_WEEKS
        if block.timestamp < next_week:
            if since_last == 0 and block.timestamp == t:
                self.tokens_per_week[this_week] += to_distribute
            else:
                self.tokens_per_week[this_week] += to_distribute * (block.timestamp - t) / since_last
            break
        else:
            if since_last == 0 and next_week == t:
                self.tokens_per_week[this_week] += to_distribute
            else:
                self.tokens_per_week[this_week] += to_distribute * (next_week - t) / since_last
        t = next_week
        this_week = next_week

    log CheckpointToken(block.timestamp, to_distribute)

@internal
def _find_timestamp_epoch(ve: address, _timestamp: uint256) -> uint256:
    _min: uint256 = 0
    _max: uint256 = VotingEscrow(ve).epoch()
    for i in range(128):
        if _min >= _max:
            break
        _mid: uint256 = (_min + _max + 2) / 2
        pt: Point = VotingEscrow(ve).point_history(_mid)
        if pt.ts <= _timestamp:
            _min = _mid
        else:
            _max = _mid - 1
    return _min

@internal
def _transfer_to(_receiver:address, _coin:address, _amount: uint256):
    response: Bytes[32] = raw_call(
        _coin,
        concat(
            method_id("transfer(address,uint256)"),
            convert(_receiver, bytes32),
            convert(_amount, bytes32),
        ),
        max_outsize=32,
    )
    if len(response) != 0:
        assert convert(response, bool)

@internal
def _transfer_from_to_self(_addr: address, _token: address, _amount: uint256):
    response: Bytes[32] = raw_call(
        _token,
        concat(
            method_id("transferFrom(address,address,uint256)"),
            convert(_addr, bytes32),
            convert(self, bytes32),
            convert(_amount, bytes32),
        ),
        max_outsize=32,
    )
    if len(response) != 0:
        assert convert(response, bool)

@view
@internal
def _find_timestamp_user_epoch(ve: address, user: address, _timestamp: uint256, max_user_epoch: uint256) -> uint256:
    _min: uint256 = 0
    _max: uint256 = max_user_epoch
    for i in range(128):
        if _min >= _max:
            break
        _mid: uint256 = (_min + _max + 2) / 2
        pt: Point = VotingEscrow(ve).user_point_history(user, _mid)
        if pt.ts <= _timestamp:
            _min = _mid
        else:
            _max = _mid - 1
    return _min

@internal
def _checkpoint_total_supply():
    ve: address = self.voting_escrow
    t: uint256 = self.time_cursor
    rounded_timestamp: uint256 = block.timestamp / TWO_WEEKS * TWO_WEEKS
    VotingEscrow(ve).checkpoint()
    zero: int128 = 0

    for i in range(20):
        if t > rounded_timestamp:
            break
        else:
            epoch: uint256 = self._find_timestamp_epoch(ve, t)
            pt: Point = VotingEscrow(ve).point_history(epoch)
            dt: int128 = 0
            if t > pt.ts:
                # If the point is at 0 epoch, it can actually be earlier than the first deposit
                # Then make dt 0
                dt = convert(t - pt.ts, int128)
            self.ve_supply[t] = convert(max(pt.bias - pt.slope * dt, zero), uint256)
        t += TWO_WEEKS

    self.time_cursor = t

@internal
def _claim(addr: address, ve: address, _last_token_time: uint256) -> uint256:
    # Minimal user_epoch is 0 (if user had no point)
    user_epoch: uint256 = 0
    to_distribute: uint256 = 0

    max_user_epoch: uint256 = VotingEscrow(ve).user_point_epoch(addr)
    _start_time: uint256 = self.start_time

    if max_user_epoch == 0:
        # No lock = no fees
        return 0

    week_cursor: uint256 = self.time_cursor_of[addr]
    if week_cursor == 0:
        # Need to do the initial binary search
        user_epoch = self._find_timestamp_user_epoch(ve, addr, _start_time, max_user_epoch)
    else:
        user_epoch = self.user_epoch_of[addr]

    if user_epoch == 0:
        user_epoch = 1

    user_point: Point = VotingEscrow(ve).user_point_history(addr, user_epoch)

    if week_cursor == 0:
        week_cursor = (user_point.ts + TWO_WEEKS - 1) / TWO_WEEKS * TWO_WEEKS

    if week_cursor >= _last_token_time:
        return 0

    if week_cursor < _start_time:
        week_cursor = _start_time
    old_user_point: Point = empty(Point)
    zero: int128 = 0
    # Iterate over weeks
    for i in range(50):
        if week_cursor >= _last_token_time:
            break

        if week_cursor >= user_point.ts and user_epoch <= max_user_epoch:
            user_epoch += 1
            old_user_point = user_point
            if user_epoch > max_user_epoch:
                user_point = empty(Point)
            else:
                user_point = VotingEscrow(ve).user_point_history(addr, user_epoch)

        else:
            # Calc
            # + i * 2 is for rounding errors
            dt: int128 = convert(week_cursor - old_user_point.ts, int128)
            balance_of: uint256 = convert(max(old_user_point.bias - dt * old_user_point.slope, zero), uint256)
            if balance_of == 0 and user_epoch > max_user_epoch:
                break
            if balance_of > 0 and self.ve_supply[week_cursor] > 0:
                to_distribute += balance_of * self.tokens_per_week[week_cursor] / self.ve_supply[week_cursor]

            week_cursor += TWO_WEEKS

    user_epoch = min(max_user_epoch, user_epoch - 1)
    self.user_epoch_of[addr] = user_epoch
    self.time_cursor_of[addr] = week_cursor

    log Claimed(addr, to_distribute, user_epoch, max_user_epoch)

    return to_distribute

# Owner methods
@external
def setEsTapToken(_addr: address):
    """
    @notice sets the esTap token address
    @param _addr the esTap token address
    """

    assert msg.sender == self.admin,"unauthorized"  # dev: access denied
    assert _addr != ZERO_ADDRESS,"not valid"
    self.estap_token = _addr
    log EsTapSet(_addr)

@external
def setEsTapVesting(_addr: address):
    """
    @notice sets the esTapVesting token address
    @param _addr the esTapVesting address
    """

    assert msg.sender == self.admin,"unauthorized"  # dev: access denied
    assert _addr != ZERO_ADDRESS,"not valid"
    self.estap_vesting = _addr
    log EsTapVestingSet(_addr)


@external
def commit_admin(_addr: address):
    """
    @notice Commit transfer of ownership
    @param _addr New admin address
    """
    assert msg.sender == self.admin,"unauthorized"  # dev: access denied
    assert self.future_admin == ZERO_ADDRESS,"admin not valid"
    self.future_admin = _addr
    log CommitAdmin(_addr)


@external
def apply_admin():
    """
    @notice Apply transfer of ownership
    """
    assert msg.sender == self.admin,"unauthorized"
    assert self.future_admin != ZERO_ADDRESS,"admin not valid"
    future_admin: address = self.future_admin
    self.admin = future_admin
    self.future_admin = ZERO_ADDRESS
    log ApplyAdmin(future_admin)


@external
def kill_me():
    """
    @notice Kill the contract
    @dev Killing transfers the entire token balance to the emergency return address
         and blocks the ability to claim or burn. The contract cannot be unkilled.
    """
    assert msg.sender == self.admin,"unauthorized"

    self.is_killed = True

    token: address = self.token
    amount: uint256 = ERC20(token).balanceOf(self)
    if amount > 0:
        # _transfer_to(_receiver:address, _coin:address, _amount: uint256):
        self._transfer_to(self.emergency_return, token, amount)



@external
def recover_balance(_coin: address) -> bool:
    """
    @notice Recover ERC20 tokens from this contract
    @dev Tokens are sent to the emergency return address.
    @param _coin Token address
    @return bool success
    """
    assert msg.sender == self.admin,"unauthorized" #dev: !authorized
    assert _coin != self.token,"token not valid" #dev: protected token

    amount: uint256 = ERC20(_coin).balanceOf(self)
    # _transfer_to(_receiver:address, _coin:address, _amount: uint256):
    self._transfer_to(self.emergency_return, _coin, amount)

    return True

# View methods
@view
@external
def ve_for_at(_user: address, _timestamp: uint256) -> uint256:
    """
    @notice Get the veTap balance for `_user` at `_timestamp`
    @param _user Address to query balance for
    @param _timestamp Epoch time
    @return uint256 veTap balance
    """
    ve: address = self.voting_escrow
    max_user_epoch: uint256 = VotingEscrow(ve).user_point_epoch(_user)
    epoch: uint256 = self._find_timestamp_user_epoch(ve, _user, _timestamp, max_user_epoch)
    pt: Point = VotingEscrow(ve).user_point_history(_user, epoch)

    zero: int128 = 0
    return convert(max(pt.bias - pt.slope * convert(_timestamp - pt.ts, int128), zero), uint256)



# Write methods
@external
def checkpoint_token():
    """
    @notice Update the token checkpoint
    @dev Calculates the total number of tokens to be distributed in a given week.
         During setup for the initial distribution this function is only callable
         by the contract owner. Beyond initial distro, it can be enabled for anyone
         to call.
    """
    assert (msg.sender == self.admin) or\
           ((block.timestamp > self.last_token_time + TOKEN_CHECKPOINT_DEADLINE))
    self._checkpoint_token()


@external
def checkpoint_total_supply():
    """
    @notice Update the veCRV total supply checkpoint
    @dev The checkpoint is also updated by the first claimant each
         new epoch week. This function may be called independently
         of a claim, to reduce claiming gas costs.
    """
    self._checkpoint_total_supply()



@external
@nonreentrant('lock')
def claim(_addr: address = msg.sender, _lock: bool = False) -> uint256:
    """
    @notice Claim fees for `_addr`
    @dev Each call to claim look at a maximum of 50 user veCRV points.
         For accounts with many veCRV related actions, this function
         may need to be called more than once to claim all available
         fees. In the `Claimed` event that fires, if `claim_epoch` is
         less than `max_epoch`, the account may claim again.
    @param _addr Address to claim fees for
    @return uint256 Amount of fees claimed in the call
    """
    assert not self.is_killed
    assert self.estap_vesting != ZERO_ADDRESS,"vesting not set"
    assert self.estap_token != ZERO_ADDRESS,"esTap not set"

    if _lock:
        assert _addr == msg.sender,"unauthorized"

    if block.timestamp >= self.time_cursor:
        self._checkpoint_total_supply()

    last_token_time: uint256 = self.last_token_time

    if (block.timestamp > last_token_time + TOKEN_CHECKPOINT_DEADLINE):
        self._checkpoint_token()
        last_token_time = block.timestamp

    last_token_time = last_token_time / TWO_WEEKS * TWO_WEEKS

    amount: uint256 = self._claim(_addr, self.voting_escrow, last_token_time)
    if amount != 0:

        token: address = self.token
        if _lock:
            ERC20(self.token).transfer(self.estap_vesting, amount)
            EsTap(self.estap_token).mintFor(self, amount)
            ERC20(self.estap_token).approve(self.estap_vesting, amount)
            EsTapVesting(self.estap_vesting).vestFor(amount, _addr)

        else:
            EsTap(self.estap_token).mintFor(_addr, amount)
            ERC20(self.token).transfer(self.estap_vesting, amount)

        self.token_last_balance -= amount

    return amount



@external
@nonreentrant('lock')
def claim_many(_receivers: address[20]) -> bool:
    """
    @notice Make multiple fee claims in a single call
    @dev Used to claim for many accounts at once, or to make
         multiple claims for the same address when that address
         has significant veCRV history
    @param _receivers List of addresses to claim for. Claiming
                      terminates at the first `ZERO_ADDRESS`.
    @return bool success
    """
    assert not self.is_killed

    if block.timestamp >= self.time_cursor:
        self._checkpoint_total_supply()

    last_token_time: uint256 = self.last_token_time

    if (block.timestamp > last_token_time + TOKEN_CHECKPOINT_DEADLINE):
        self._checkpoint_token()
        last_token_time = block.timestamp

    last_token_time = last_token_time / TWO_WEEKS * TWO_WEEKS
    voting_escrow: address = self.voting_escrow
    token: address = self.token
    total: uint256 = 0

    for addr in _receivers:
        if addr == ZERO_ADDRESS:
            break

        amount: uint256 = self._claim(addr, voting_escrow, last_token_time)
        if amount != 0:
            #self._transfer_to(addr, token, amount)
            assert ERC20(token).transfer(addr, amount)
            total += amount

    if total != 0:
        self.token_last_balance -= total

    return True


@external
def queueNewRewards(_amount: uint256) -> bool:
    """
    @notice Receive Tokens into the contract and trigger a token checkpoint
    @param _amount Amount to transfer
    @return bool success
    """
    assert _amount > 0,"amount not valid"
    assert not self.is_killed,"was killed"

    self._transfer_from_to_self(msg.sender, self.token, _amount)

    if (block.timestamp > self.last_token_time + TOKEN_CHECKPOINT_DEADLINE):
        self._checkpoint_token()

    return True