# Vesting









## Methods

### claim

```solidity
function claim() external nonpayable
```

claim available tokens

*claim works for msg.sender*


### claimOwnership

```solidity
function claimOwnership() external nonpayable
```

Needs to be called by `pendingOwner` to claim ownership.




### claimable

```solidity
function claimable(address _user) external view returns (uint256)
```

returns total claimable for user



#### Parameters

| Name | Type | Description |
|---|---|---|
| _user | address | the user address |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### claimable

```solidity
function claimable() external view returns (uint256)
```

returns total claimable




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### cliff

```solidity
function cliff() external view returns (uint256)
```

returns the cliff period




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### duration

```solidity
function duration() external view returns (uint256)
```

returns total vesting duration




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### init

```solidity
function init(contract IERC20 _token, uint256 _seededAmount) external nonpayable
```

inits the contract with total amount

*sets the start time to block.timestamp*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _token | contract IERC20 | undefined |
| _seededAmount | uint256 | total vested amount |

### owner

```solidity
function owner() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### pendingOwner

```solidity
function pendingOwner() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### registerUser

```solidity
function registerUser(address _user, uint256 _amount) external nonpayable
```

adds a new user

*should be called before init*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _user | address | the user address |
| _amount | uint256 | user weight |

### seeded

```solidity
function seeded() external view returns (uint256)
```

returns total available tokens




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### start

```solidity
function start() external view returns (uint256)
```

returns the start time for vesting




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### token

```solidity
function token() external view returns (contract IERC20)
```

the vested token




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract IERC20 | undefined |

### totalClaimed

```solidity
function totalClaimed() external view returns (uint256)
```

returns total claimed




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

### users

```solidity
function users(address) external view returns (uint256 amount, uint256 claimed, uint256 latestClaimTimestamp, bool revoked)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| amount | uint256 | undefined |
| claimed | uint256 | undefined |
| latestClaimTimestamp | uint256 | undefined |
| revoked | bool | undefined |

### vested

```solidity
function vested(address _user) external view returns (uint256)
```

returns total vested amount for user



#### Parameters

| Name | Type | Description |
|---|---|---|
| _user | address | the user address |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### vested

```solidity
function vested() external view returns (uint256)
```

returns total vested amount




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |



## Events

### Claimed

```solidity
event Claimed(address indexed user, uint256 amount)
```

event emitted when someone claims available tokens



#### Parameters

| Name | Type | Description |
|---|---|---|
| user `indexed` | address | undefined |
| amount  | uint256 | undefined |

### OwnershipTransferred

```solidity
event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| previousOwner `indexed` | address | undefined |
| newOwner `indexed` | address | undefined |

### UserRegistered

```solidity
event UserRegistered(address indexed user, uint256 amount)
```

event emitted when a new user is registered



#### Parameters

| Name | Type | Description |
|---|---|---|
| user `indexed` | address | undefined |
| amount  | uint256 | undefined |



## Errors

### AddressNotValid

```solidity
error AddressNotValid()
```






### AlreadyRegistered

```solidity
error AlreadyRegistered()
```






### AmountNotValid

```solidity
error AmountNotValid()
```






### BalanceTooLow

```solidity
error BalanceTooLow()
```






### Initialized

```solidity
error Initialized()
```






### NoTokens

```solidity
error NoTokens()
```






### NotEnough

```solidity
error NotEnough()
```






### NotStarted

```solidity
error NotStarted()
```






### NothingToClaim

```solidity
error NothingToClaim()
```






### VestingDurationNotValid

```solidity
error VestingDurationNotValid()
```







