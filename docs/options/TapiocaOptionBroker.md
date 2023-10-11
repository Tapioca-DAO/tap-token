# TapiocaOptionBroker









## Methods

### EPOCH_DURATION

```solidity
function EPOCH_DURATION() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### MIN_WEIGHT_FACTOR

```solidity
function MIN_WEIGHT_FACTOR() external view returns (uint256)
```






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

### emissionsStartTime

```solidity
function emissionsStartTime() external view returns (uint256)
```

starts time for emissions

*initialized in the constructor with block.timestamp*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### epoch

```solidity
function epoch() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### epochTAPValuation

```solidity
function epochTAPValuation() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### exerciseOption

```solidity
function exerciseOption(uint256 _oTAPTokenID, contract ERC20 _paymentToken, uint256 _tapAmount) external nonpayable
```

Exercise an oTAP position



#### Parameters

| Name | Type | Description |
|---|---|---|
| _oTAPTokenID | uint256 | tokenId of the oTAP position, position must be active |
| _paymentToken | contract ERC20 | Address of the payment token to use, must be whitelisted |
| _tapAmount | uint256 | Amount of TAP to exercise. If 0, the full amount is exercised |

### exitPosition

```solidity
function exitPosition(uint256 _oTAPTokenID) external nonpayable
```

Exit a twAML participation and delete the voting power if existing



#### Parameters

| Name | Type | Description |
|---|---|---|
| _oTAPTokenID | uint256 | The tokenId of the oTAP position |

### getCurrentWeek

```solidity
function getCurrentWeek() external view returns (uint256)
```

Returns the current week




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### getOTCDealDetails

```solidity
function getOTCDealDetails(uint256 _oTAPTokenID, contract ERC20 _paymentToken, uint256 _tapAmount) external view returns (uint256 eligibleTapAmount, uint256 paymentTokenAmount, uint256 tapAmount)
```

Returns the details of an OTC deal for a given oTAP token ID and a payment token.         The oracle uses the last peeked value, and not the latest one, so the payment amount may be different.



#### Parameters

| Name | Type | Description |
|---|---|---|
| _oTAPTokenID | uint256 | The oTAP token ID |
| _paymentToken | contract ERC20 | The payment token |
| _tapAmount | uint256 | The amount of TAP to be exchanged. If 0 it will use the full amount of TAP eligible for the deal |

#### Returns

| Name | Type | Description |
|---|---|---|
| eligibleTapAmount | uint256 | The amount of TAP eligible for the deal |
| paymentTokenAmount | uint256 | The amount of payment tokens required for the deal |
| tapAmount | uint256 | The amount of TAP to be exchanged |

### netDepositedForEpoch

```solidity
function netDepositedForEpoch(uint256 epoch, uint256 sglAssetID) external view returns (int256 netAmount)
```

Total amount of participation per epoch



#### Parameters

| Name | Type | Description |
|---|---|---|
| epoch | uint256 | undefined |
| sglAssetID | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| netAmount | int256 | undefined |

### newEpoch

```solidity
function newEpoch() external nonpayable
```

Start a new epoch, extract TAP from the TapOFT contract,         emit it to the active singularities and get the price of TAP for the epoch.




### oTAP

```solidity
function oTAP() external view returns (contract OTAP)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract OTAP | undefined |

### oTAPBrokerClaim

```solidity
function oTAPBrokerClaim() external nonpayable
```

Claim the Broker role of the oTAP contract




### oTAPCalls

```solidity
function oTAPCalls(uint256, uint256) external view returns (uint256)
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

### owner

```solidity
function owner() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### participants

```solidity
function participants(uint256) external view returns (bool hasVotingPower, bool divergenceForce, uint256 averageMagnitude)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| hasVotingPower | bool | undefined |
| divergenceForce | bool | undefined |
| averageMagnitude | uint256 | undefined |

### participate

```solidity
function participate(uint256 _tOLPTokenID) external nonpayable returns (uint256 oTAPTokenID)
```

Participate in twAMl voting and mint an oTAP position.         Exercising the option is not possible on participation week.



#### Parameters

| Name | Type | Description |
|---|---|---|
| _tOLPTokenID | uint256 | The tokenId of the tOLP position |

#### Returns

| Name | Type | Description |
|---|---|---|
| oTAPTokenID | uint256 | undefined |

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

### setMinWeightFactor

```solidity
function setMinWeightFactor(uint256 _minWeightFactor) external nonpayable
```

Set the minimum weight factor



#### Parameters

| Name | Type | Description |
|---|---|---|
| _minWeightFactor | uint256 | The new minimum weight factor |

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

### singularityGauges

```solidity
function singularityGauges(uint256, uint256) external view returns (uint256)
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

### tOLP

```solidity
function tOLP() external view returns (contract TapiocaOptionLiquidityProvision)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract TapiocaOptionLiquidityProvision | undefined |

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

### timestampToWeek

```solidity
function timestampToWeek(uint256 timestamp) external view returns (uint256)
```

Returns the current week given a timestamp



#### Parameters

| Name | Type | Description |
|---|---|---|
| timestamp | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

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

### twAML

```solidity
function twAML(uint256) external view returns (uint256 totalParticipants, uint256 averageMagnitude, uint256 totalDeposited, uint256 cumulative)
```

===== TWAML ======



#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| totalParticipants | uint256 | undefined |
| averageMagnitude | uint256 | undefined |
| totalDeposited | uint256 | undefined |
| cumulative | uint256 | undefined |



## Events

### AMLDivergence

```solidity
event AMLDivergence(uint256 indexed epoch, uint256 indexed cumulative, uint256 indexed averageMagnitude, uint256 totalParticipants)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| epoch `indexed` | uint256 | undefined |
| cumulative `indexed` | uint256 | undefined |
| averageMagnitude `indexed` | uint256 | undefined |
| totalParticipants  | uint256 | undefined |

### ExerciseOption

```solidity
event ExerciseOption(uint256 indexed epoch, address indexed to, contract ERC20 indexed paymentToken, uint256 oTapTokenID, uint256 amount)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| epoch `indexed` | uint256 | undefined |
| to `indexed` | address | undefined |
| paymentToken `indexed` | contract ERC20 | undefined |
| oTapTokenID  | uint256 | undefined |
| amount  | uint256 | undefined |

### ExitPosition

```solidity
event ExitPosition(uint256 indexed epoch, uint256 indexed tokenId, uint256 indexed amount)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| epoch `indexed` | uint256 | undefined |
| tokenId `indexed` | uint256 | undefined |
| amount `indexed` | uint256 | undefined |

### NewEpoch

```solidity
event NewEpoch(uint256 indexed epoch, uint256 indexed extractedTAP, uint256 indexed epochTAPValuation)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| epoch `indexed` | uint256 | undefined |
| extractedTAP `indexed` | uint256 | undefined |
| epochTAPValuation `indexed` | uint256 | undefined |

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
event Participate(uint256 indexed epoch, uint256 indexed sglAssetID, uint256 indexed totalDeposited, LockPosition lock, uint256 discount)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| epoch `indexed` | uint256 | undefined |
| sglAssetID `indexed` | uint256 | undefined |
| totalDeposited `indexed` | uint256 | undefined |
| lock  | LockPosition | undefined |
| discount  | uint256 | undefined |

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
event SetPaymentToken(contract ERC20 indexed paymentToken, contract IOracle indexed oracle, bytes indexed oracleData)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| paymentToken `indexed` | contract ERC20 | undefined |
| oracle `indexed` | contract IOracle | undefined |
| oracleData `indexed` | bytes | undefined |

### SetTapOracle

```solidity
event SetTapOracle(contract IOracle indexed oracle, bytes indexed oracleData)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| oracle `indexed` | contract IOracle | undefined |
| oracleData `indexed` | bytes | undefined |

### Unpaused

```solidity
event Unpaused(address account)
```



*Emitted when the pause is lifted by `account`.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| account  | address | undefined |



