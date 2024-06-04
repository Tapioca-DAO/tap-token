## Findings

1. Low/Informational - TapiocaOptionBroker::newEpoch can't be called for epoch

Description: the function reverts if `block.timestamp <=` epoch therefore if the timestamp == epoch (7 days) it would revert which doesn't seem lik it should happen.

Impact: can't update when epoch == timestamp

Suggestion: replace the <= in the above with <> 

```solidity
if (_timestampToWeek(block.timestamp) < epoch) revert TooSoon();
```

2. Low - `timestampToWeek` return value isn't as expected 

Description: In `test_timestamp` the return value of `timestampToWeek` in the originally defined test is expected to be 0 if passing in a value less than the length of an epoch but if `emissionsStartTime` is unset it's > 0. 

See `test_timestamp` failing case. 