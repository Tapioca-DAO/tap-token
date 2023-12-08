# AirdropBroker





More details found here https://docs.tapioca.xyz/tapioca/launch/option-airdrop



## Methods

### EPOCH_DURATION

```solidity
function EPOCH_DURATION() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### LAST_EPOCH

```solidity
function LAST_EPOCH() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### PCNFT

```solidity
function PCNFT() external view returns (contract IERC721)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract IERC721 | undefined |

### PHASE_1_DISCOUNT

```solidity
function PHASE_1_DISCOUNT() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### PHASE_2_AMOUNT_PER_USER

```solidity
function PHASE_2_AMOUNT_PER_USER(uint256) external view returns (uint8)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint8 | undefined |

### PHASE_2_DISCOUNT_PER_USER

```solidity
function PHASE_2_DISCOUNT_PER_USER(uint256) external view returns (uint8)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint8 | undefined |

### PHASE_3_AMOUNT_PER_USER

```solidity
function PHASE_3_AMOUNT_PER_USER() external view returns (uint256)
```

=====-------======      Phase 3 =====-------======




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### PHASE_3_DISCOUNT

```solidity
function PHASE_3_DISCOUNT() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### PHASE_4_DISCOUNT

```solidity
function PHASE_4_DISCOUNT() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### aoTAP

```solidity
function aoTAP() external view returns (contract AOTAP)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract AOTAP | undefined |

### aoTAPBrokerClaim

```solidity
function aoTAPBrokerClaim() external nonpayable
```

Claim the Broker role of the aoTAP contract




### aoTAPCalls

```solidity
function aoTAPCalls(uint256, uint256) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |
| _1 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### claimOwnership

```solidity
function claimOwnership() external nonpayable
```

Needs to be called by `pendingOwner` to claim ownership.




### collectPaymentTokens

```solidity
function collectPaymentTokens(address[] _paymentTokens) external nonpayable
```

Collect the payment tokens from the OTC deals



#### Parameters

| Name | Type | Description |
|---|---|---|
| _paymentTokens | address[] | The payment tokens to collect |

### daoRecoverTAP

```solidity
function daoRecoverTAP() external nonpayable
```

Recover the unclaimed TAP from the contract. Should occur after the end of the airdrop, which is 8 epochs, or 41 days long.




### epoch

```solidity
function epoch() external view returns (uint64)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint64 | undefined |

### epochTAPValuation

```solidity
function epochTAPValuation() external view returns (uint128)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint128 | undefined |

### exerciseOption

```solidity
function exerciseOption(uint256 _aoTAPTokenID, contract ERC20 _paymentToken, uint256 _tapAmount) external nonpayable
```

Exercise an aoTAP position



#### Parameters

| Name | Type | Description |
|---|---|---|
| _aoTAPTokenID | uint256 | tokenId of the aoTAP position, position must be active |
| _paymentToken | contract ERC20 | Address of the payment token to use, must be whitelisted |
| _tapAmount | uint256 | Amount of TAP to exercise. If 0, the full amount is exercised |

### getOTCDealDetails

```solidity
function getOTCDealDetails(uint256 _aoTAPTokenID, contract ERC20 _paymentToken, uint256 _tapAmount) external view returns (uint256 eligibleTapAmount, uint256 paymentTokenAmount, uint256 tapAmount)
```

Returns the details of an OTC deal for a given oTAP token ID and a payment token.         The oracle uses the last peeked value, and not the latest one, so the payment amount may be different.



#### Parameters

| Name | Type | Description |
|---|---|---|
| _aoTAPTokenID | uint256 | The aoTAP token ID |
| _paymentToken | contract ERC20 | The payment token |
| _tapAmount | uint256 | The amount of TAP to be exchanged. If 0 it will use the full amount of TAP eligible for the deal |

#### Returns

| Name | Type | Description |
|---|---|---|
| eligibleTapAmount | uint256 | The amount of TAP eligible for the deal |
| paymentTokenAmount | uint256 | The amount of payment tokens required for the deal |
| tapAmount | uint256 | The amount of TAP to be exchanged |

### lastEpochUpdate

```solidity
function lastEpochUpdate() external view returns (uint64)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint64 | undefined |

### newEpoch

```solidity
function newEpoch() external nonpayable
```

Start a new epoch, extract TAP from the TapOFT contract,         emit it to the active singularities and get the price of TAP for the epoch.




### owner

```solidity
function owner() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### participate

```solidity
function participate(bytes _data) external nonpayable returns (uint256 aoTAPTokenID)
```

Participate in the airdrop



#### Parameters

| Name | Type | Description |
|---|---|---|
| _data | bytes | The data to be used for the participation, varies by phases |

#### Returns

| Name | Type | Description |
|---|---|---|
| aoTAPTokenID | uint256 | undefined |

### paused

```solidity
function paused() external view returns (bool)
```



*Returns true if the contract is paused, and false otherwise.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### paymentTokenBeneficiary

```solidity
function paymentTokenBeneficiary() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### paymentTokens

```solidity
function paymentTokens(contract ERC20) external view returns (contract IOracle oracle, bytes oracleData)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | contract ERC20 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| oracle | contract IOracle | undefined |
| oracleData | bytes | undefined |

### pendingOwner

```solidity
function pendingOwner() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### phase1Users

```solidity
function phase1Users(address) external view returns (uint256)
```

user address =&gt; eligible TAP amount, 0 means no eligibility



#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### phase2MerkleRoots

```solidity
function phase2MerkleRoots(uint256) external view returns (bytes32)
```

=====-------======      Phase 2 =====-------======



#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes32 | undefined |

### phase4Users

```solidity
function phase4Users(address) external view returns (uint256)
```

user address =&gt; eligible TAP amount, 0 means no eligibility



#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### registerUserForPhase

```solidity
function registerUserForPhase(uint256 _phase, address[] _users, uint256[] _amounts) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _phase | uint256 | undefined |
| _users | address[] | undefined |
| _amounts | uint256[] | undefined |

### setPaymentToken

```solidity
function setPaymentToken(contract ERC20 _paymentToken, contract IOracle _oracle, bytes _oracleData) external nonpayable
```

Activate or deactivate a payment token

*set the oracle to address(0) to deactivate, expect the same decimal precision as TAP oracle*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _paymentToken | contract ERC20 | undefined |
| _oracle | contract IOracle | undefined |
| _oracleData | bytes | undefined |

### setPaymentTokenBeneficiary

```solidity
function setPaymentTokenBeneficiary(address _paymentTokenBeneficiary) external nonpayable
```

Set the payment token beneficiary



#### Parameters

| Name | Type | Description |
|---|---|---|
| _paymentTokenBeneficiary | address | The new payment token beneficiary |

### setPhase2MerkleRoots

```solidity
function setPhase2MerkleRoots(bytes32[4] _merkleRoots) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _merkleRoots | bytes32[4] | undefined |

### setTapOracle

```solidity
function setTapOracle(contract IOracle _tapOracle, bytes _tapOracleData) external nonpayable
```

Set the TapOFT Oracle address and data



#### Parameters

| Name | Type | Description |
|---|---|---|
| _tapOracle | contract IOracle | The new TapOFT Oracle address |
| _tapOracleData | bytes | The new TapOFT Oracle data |

### tapOFT

```solidity
function tapOFT() external view returns (contract TapOFT)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract TapOFT | undefined |

### tapOracle

```solidity
function tapOracle() external view returns (contract IOracle)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract IOracle | undefined |

### tapOracleData

```solidity
function tapOracleData() external view returns (bytes)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes | undefined |

### transferOwnership

```solidity
function transferOwnership(address newOwner, bool direct, bool renounce) external nonpayable
```

Transfers ownership to `newOwner`. Either directly or claimable by the new pending owner. Can only be invoked by the current `owner`.



#### Parameters

| Name | Type | Description |
|---|---|---|
| newOwner | address | Address of the new owner. |
| direct | bool | True if `newOwner` should be set immediately. False if `newOwner` needs to use `claimOwnership`. |
| renounce | bool | Allows the `newOwner` to be `address(0)` if `direct` and `renounce` is True. Has no effect otherwise. |

### userParticipation

```solidity
function userParticipation(address, uint256) external view returns (bool)
```

Record of participation in phase 2 airdrop Only applicable for phase 2. To get subphases on phase 2 we do userParticipation[_user][20+roles]



#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |
| _1 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |



## Events

### ExerciseOption

```solidity
event ExerciseOption(uint256 indexed epoch, address indexed to, contract ERC20 indexed paymentToken, uint256 aoTapTokenID, uint256 amount)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| epoch `indexed` | uint256 | undefined |
| to `indexed` | address | undefined |
| paymentToken `indexed` | contract ERC20 | undefined |
| aoTapTokenID  | uint256 | undefined |
| amount  | uint256 | undefined |

### NewEpoch

```solidity
event NewEpoch(uint256 indexed epoch, uint256 epochTAPValuation)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| epoch `indexed` | uint256 | undefined |
| epochTAPValuation  | uint256 | undefined |

### OwnershipTransferred

```solidity
event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| previousOwner `indexed` | address | undefined |
| newOwner `indexed` | address | undefined |

### Participate

```solidity
event Participate(uint256 indexed epoch, uint256 aoTAPTokenID)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| epoch `indexed` | uint256 | undefined |
| aoTAPTokenID  | uint256 | undefined |

### Paused

```solidity
event Paused(address account)
```



*Emitted when the pause is triggered by `account`.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| account  | address | undefined |

### SetPaymentToken

```solidity
event SetPaymentToken(contract ERC20 paymentToken, contract IOracle oracle, bytes oracleData)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| paymentToken  | contract ERC20 | undefined |
| oracle  | contract IOracle | undefined |
| oracleData  | bytes | undefined |

### SetTapOracle

```solidity
event SetTapOracle(contract IOracle oracle, bytes oracleData)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| oracle  | contract IOracle | undefined |
| oracleData  | bytes | undefined |

### Unpaused

```solidity
event Unpaused(address account)
```



*Emitted when the pause is lifted by `account`.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| account  | address | undefined |



## Errors

### AlreadyParticipated

```solidity
error AlreadyParticipated()
```






### Ended

```solidity
error Ended()
```






### Failed

```solidity
error Failed()
```






### NotAuthorized

```solidity
error NotAuthorized()
```






### NotEligible

```solidity
error NotEligible()
```






### NotStarted

```solidity
error NotStarted()
```






### NotValid

```solidity
error NotValid()
```






### OptionExpired

```solidity
error OptionExpired()
```






### PaymentAmountNotValid

```solidity
error PaymentAmountNotValid()
```






### PaymentTokenNotValid

```solidity
error PaymentTokenNotValid()
```

=====-------======




### PaymentTokenValuationNotValid

```solidity
error PaymentTokenValuationNotValid()
```






### TapAmountNotValid

```solidity
error TapAmountNotValid()
```






### TokenBeneficiaryNotSet

```solidity
error TokenBeneficiaryNotSet()
```






### TooHigh

```solidity
error TooHigh()
```






### TooLow

```solidity
error TooLow()
```






### TooSoon

```solidity
error TooSoon()
```







