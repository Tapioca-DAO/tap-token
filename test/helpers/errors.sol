// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

contract Errors {
    error PaymentTokenNotValid();
    error OptionExpired();
    error TooHigh();
    error TooLow();
    error NotStarted();
    error Ended();
    error TooSoon();
    error Failed();
    error TokenBeneficiaryNotSet();
    error NotEligible();
    error AlreadyParticipated();
    error PaymentAmountNotValid();
    error TapAmountNotValid();
    error PaymentTokenValuationNotValid();
    error OnlyBroker();
    error OnlyOnce();
    error NotAuthorized();
    error AdvanceWeekFirst();
    error NotValid();
    error Registered();
    error TokenLimitReached();
    error NotApproved(uint256 tokenId, address owner, address spender);
    error Duplicate();
    error LockNotAWeek();
    error NoActiveSingularities();
    error NoLiquidity();
    error NotRegistered();
    error InvalidSingularity();
    error DurationTooShort();
    error SharesNotValid();
    error SingularityInRescueMode();
    error SingularityNotActive();
    error PositionExpired();
    error LockNotExpired();
    error AlreadyActive();
    error AssetIdNotValid();
    error DuplicateAssetId();
    error NotInRescueMode();
    error NothingToClaim();
    error Initialized();
    error AddressNotValid();
    error AmountNotValid();
    error AlreadyRegistered();
    error NoTokens();
    error NotEnough();
    error BalanceTooLow();
    error VestingDurationNotValid();
    error Overflow();
    error StillLocked();
    error TooLate();
}
