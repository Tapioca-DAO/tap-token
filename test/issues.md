## Findings

1. Medium - No check for expiry time on aoTAP

Description: aoTAP::mint doesn't have a check for the expiry time passed in. See `test_mint_past_expiry_time` for an example

Impact: this could allow a user to mint with an expiry time that has already passed.

Recommendation: Add a check in aoTAP::mint for expiry time, should also enforce minimum time if applicable. 

2. Low/Informational - TapiocaOptionBroker::newEpoch can't be called for epoch

Description: the function reverts if `block.timestamp <=` epoch therefore if the timestamp == epoch (7 days) it would revert which doesn't seem lik it should happen.

Impact: can't update when epoch == timestamp

Suggestion: replace the <= in the above with <> 

```solidity
if (_timestampToWeek(block.timestamp) < epoch) revert TooSoon();
```

2. Low - `timestampToWeek` return value isn't as expected 

Description: In `test_timestamp` the return value of `timestampToWeek` in the originally defined test is expected to be 0 if passing in a value less than the length of an epoch but if `emissionsStartTime` is unset it's > 0. 

See `test_timestamp` failing case. 

3. Informational - circular constructor arguments in TapiocaOptionLiquidityProvision and TapiocaOptionBroker 

Description: TapiocaOptionLiquidityProvision and TapiocaOptionBroker must each be set in their corresponding constructors but are set as immutable variables which therefore requires them to be setup behind a proxy initially pointed to an empty address, then switched once the corresponding contract is deployed. 

Impact: This could complicate deployment and makes it easier to switch implementations

Recommendation: Implement an owner restricted function that allows setting each of these implementations in their corresponding contracts to make deployment easier. 