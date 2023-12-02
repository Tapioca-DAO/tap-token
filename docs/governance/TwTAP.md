# TwTAP









## Methods

### DOMAIN_SEPARATOR

```solidity
function DOMAIN_SEPARATOR() external view returns (bytes32)
```



*See {IERC20Permit-DOMAIN_SEPARATOR}.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes32 | undefined |

### EPOCH_DURATION

```solidity
function EPOCH_DURATION() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### addRewardToken

```solidity
function addRewardToken(contract IERC20 token) external nonpayable returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| token | contract IERC20 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### advanceWeek

```solidity
function advanceWeek(uint256 _limit) external nonpayable
```

Indicate that (a) week(s) have passed and update running totalsReverts if called in week 0. Let it.



#### Parameters

| Name | Type | Description |
|---|---|---|
| _limit | uint256 | Maximum number of weeks to process in one call |

### approve

```solidity
function approve(address to, uint256 tokenId) external nonpayable
```



*See {IERC721-approve}.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| to | address | undefined |
| tokenId | uint256 | undefined |

### balanceOf

```solidity
function balanceOf(address owner) external view returns (uint256)
```



*See {IERC721-balanceOf}.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| owner | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### claimAndSendRewards

```solidity
function claimAndSendRewards(uint256 _tokenId, contract IERC20[] _rewardTokens) external nonpayable
```

claims all rewards distributed since token mint or last claim, and send them to another chain.



#### Parameters

| Name | Type | Description |
|---|---|---|
| _tokenId | uint256 | The tokenId of the twTAP position |
| _rewardTokens | contract IERC20[] | The address of the reward token |

### claimOwnership

```solidity
function claimOwnership() external nonpayable
```

Needs to be called by `pendingOwner` to claim ownership.




### claimRewards

```solidity
function claimRewards(uint256 _tokenId, address _to) external nonpayable
```

claims all rewards distributed since token mint or last claim.



#### Parameters

| Name | Type | Description |
|---|---|---|
| _tokenId | uint256 | tokenId whose rewards to claim |
| _to | address | address to receive the rewards |

### claimable

```solidity
function claimable(uint256 _tokenId) external view returns (uint256[])
```

Amount currently claimable for each reward token

*index 0 will ALWAYS return 0, as it&#39;s used by address(0x0)*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _tokenId | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256[] | claimable amounts mapped by reward token |

### claimed

```solidity
function claimed(uint256, uint256) external view returns (uint256)
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

### creation

```solidity
function creation() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### currentWeek

```solidity
function currentWeek() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### distributeReward

```solidity
function distributeReward(uint256 _rewardTokenId, uint256 _amount) external nonpayable
```

distributes a reward among all tokens, weighted by voting powerThe reward gets allocated to all positions that have locked inthe current week. Fails, intentionally, if this number is zero.Total rewards cannot exceed 2^128 tokens.



#### Parameters

| Name | Type | Description |
|---|---|---|
| _rewardTokenId | uint256 | index of the reward in `rewardTokens` |
| _amount | uint256 | amount of reward token to distribute. |

### eip712Domain

```solidity
function eip712Domain() external view returns (bytes1 fields, string name, string version, uint256 chainId, address verifyingContract, bytes32 salt, uint256[] extensions)
```



*See {EIP-5267}. _Available since v4.9._*


#### Returns

| Name | Type | Description |
|---|---|---|
| fields | bytes1 | undefined |
| name | string | undefined |
| version | string | undefined |
| chainId | uint256 | undefined |
| verifyingContract | address | undefined |
| salt | bytes32 | undefined |
| extensions | uint256[] | undefined |

### exitPosition

```solidity
function exitPosition(uint256 _tokenId) external nonpayable
```

Exit a twAML participation and delete the voting power if existing



#### Parameters

| Name | Type | Description |
|---|---|---|
| _tokenId | uint256 | The tokenId of the twTAP position |

### exitPositionAndSendTap

```solidity
function exitPositionAndSendTap(uint256 _tokenId) external nonpayable returns (uint256)
```

Exit a twAML participation and send the withdrawn TAP to tapOFT to send it to another chain.



#### Parameters

| Name | Type | Description |
|---|---|---|
| _tokenId | uint256 | The tokenId of the twTAP position |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### getApproved

```solidity
function getApproved(uint256 tokenId) external view returns (address)
```



*See {IERC721-getApproved}.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| tokenId | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### getParticipation

```solidity
function getParticipation(uint256 _tokenId) external view returns (struct Participation participant)
```

Return the participation of a token. Returns 0 votes for expired tokens.



#### Parameters

| Name | Type | Description |
|---|---|---|
| _tokenId | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| participant | Participation | undefined |

### isApprovedForAll

```solidity
function isApprovedForAll(address owner, address operator) external view returns (bool)
```



*See {IERC721-isApprovedForAll}.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| owner | address | undefined |
| operator | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### lastProcessedWeek

```solidity
function lastProcessedWeek() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### maxRewardTokens

```solidity
function maxRewardTokens() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### mintedTWTap

```solidity
function mintedTWTap() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### name

```solidity
function name() external view returns (string)
```



*See {IERC721Metadata-name}.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | string | undefined |

### nonces

```solidity
function nonces(address owner) external view returns (uint256)
```



*See {IERC20Permit-nonces}.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| owner | address | undefined |

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

### ownerOf

```solidity
function ownerOf(uint256 tokenId) external view returns (address)
```



*See {IERC721-ownerOf}.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| tokenId | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### participants

```solidity
function participants(uint256) external view returns (uint256 averageMagnitude, bool hasVotingPower, bool divergenceForce, bool tapReleased, uint56 expiry, uint88 tapAmount, uint24 multiplier, uint40 lastInactive, uint40 lastActive)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| averageMagnitude | uint256 | undefined |
| hasVotingPower | bool | undefined |
| divergenceForce | bool | undefined |
| tapReleased | bool | undefined |
| expiry | uint56 | undefined |
| tapAmount | uint88 | undefined |
| multiplier | uint24 | undefined |
| lastInactive | uint40 | undefined |
| lastActive | uint40 | undefined |

### participate

```solidity
function participate(address _participant, uint256 _amount, uint256 _duration) external nonpayable returns (uint256 tokenId)
```

Participate in twAMl voting and mint an oTAP position



#### Parameters

| Name | Type | Description |
|---|---|---|
| _participant | address | The address of the participant |
| _amount | uint256 | The amount of TAP to participate with |
| _duration | uint256 | The duration of the lock |

#### Returns

| Name | Type | Description |
|---|---|---|
| tokenId | uint256 | undefined |

### paused

```solidity
function paused() external view returns (bool)
```



*Returns true if the contract is paused, and false otherwise.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### pendingOwner

```solidity
function pendingOwner() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### permit

```solidity
function permit(address spender, uint256 tokenId, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| spender | address | undefined |
| tokenId | uint256 | undefined |
| deadline | uint256 | undefined |
| v | uint8 | undefined |
| r | bytes32 | undefined |
| s | bytes32 | undefined |

### releaseTap

```solidity
function releaseTap(uint256 _tokenId, address _to) external nonpayable
```

claims the TAP locked in a position whose votes have expired,and undoes the effect on the twAML calculations.



#### Parameters

| Name | Type | Description |
|---|---|---|
| _tokenId | uint256 | tokenId whose locked TAP to claim |
| _to | address | address to receive the TAP |

### rewardTokenIndex

```solidity
function rewardTokenIndex(contract IERC20) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | contract IERC20 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### rewardTokens

```solidity
function rewardTokens(uint256) external view returns (contract IERC20)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract IERC20 | undefined |

### safeTransferFrom

```solidity
function safeTransferFrom(address from, address to, uint256 tokenId) external nonpayable
```



*See {IERC721-safeTransferFrom}.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| from | address | undefined |
| to | address | undefined |
| tokenId | uint256 | undefined |

### safeTransferFrom

```solidity
function safeTransferFrom(address from, address to, uint256 tokenId, bytes data) external nonpayable
```



*See {IERC721-safeTransferFrom}.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| from | address | undefined |
| to | address | undefined |
| tokenId | uint256 | undefined |
| data | bytes | undefined |

### setApprovalForAll

```solidity
function setApprovalForAll(address operator, bool approved) external nonpayable
```



*See {IERC721-setApprovalForAll}.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| operator | address | undefined |
| approved | bool | undefined |

### setMaxRewardTokensLength

```solidity
function setMaxRewardTokensLength(uint256 _length) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _length | uint256 | undefined |

### supportsInterface

```solidity
function supportsInterface(bytes4 interfaceId) external view returns (bool)
```



*See {IERC165-supportsInterface}.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| interfaceId | bytes4 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### symbol

```solidity
function symbol() external view returns (string)
```



*See {IERC721Metadata-symbol}.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | string | undefined |

### tapOFT

```solidity
function tapOFT() external view returns (contract TapOFT)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract TapOFT | undefined |

### tokenURI

```solidity
function tokenURI(uint256 tokenId) external view returns (string)
```



*See {IERC721Metadata-tokenURI}.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| tokenId | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | string | undefined |

### transferFrom

```solidity
function transferFrom(address from, address to, uint256 tokenId) external nonpayable
```



*See {IERC721-transferFrom}.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| from | address | undefined |
| to | address | undefined |
| tokenId | uint256 | undefined |

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
function twAML() external view returns (uint256 totalParticipants, uint256 averageMagnitude, uint256 totalDeposited, uint256 cumulative)
```

===== TWAML ======




#### Returns

| Name | Type | Description |
|---|---|---|
| totalParticipants | uint256 | undefined |
| averageMagnitude | uint256 | undefined |
| totalDeposited | uint256 | undefined |
| cumulative | uint256 | undefined |

### weekTotals

```solidity
function weekTotals(uint256) external view returns (int256 netActiveVotes)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| netActiveVotes | int256 | undefined |



## Events

### AMLDivergence

```solidity
event AMLDivergence(uint256 indexed cumulative, uint256 indexed averageMagnitude, uint256 indexed totalParticipants)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| cumulative `indexed` | uint256 | undefined |
| averageMagnitude `indexed` | uint256 | undefined |
| totalParticipants `indexed` | uint256 | undefined |

### Approval

```solidity
event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId)
```



*Emitted when `owner` enables `approved` to manage the `tokenId` token.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| owner `indexed` | address | undefined |
| approved `indexed` | address | undefined |
| tokenId `indexed` | uint256 | undefined |

### ApprovalForAll

```solidity
event ApprovalForAll(address indexed owner, address indexed operator, bool approved)
```



*Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| owner `indexed` | address | undefined |
| operator `indexed` | address | undefined |
| approved  | bool | undefined |

### EIP712DomainChanged

```solidity
event EIP712DomainChanged()
```



*MAY be emitted to signal that the domain could have changed.*


### ExitPosition

```solidity
event ExitPosition(uint256 indexed tokenId, uint256 indexed amount)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| tokenId `indexed` | uint256 | undefined |
| amount `indexed` | uint256 | undefined |

### LogMaxRewardsLength

```solidity
event LogMaxRewardsLength(uint256 indexed _oldLength, uint256 indexed _newLength, uint256 indexed _currentLength)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _oldLength `indexed` | uint256 | undefined |
| _newLength `indexed` | uint256 | undefined |
| _currentLength `indexed` | uint256 | undefined |

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
event Participate(address indexed participant, uint256 indexed tapAmount, uint256 indexed multiplier)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| participant `indexed` | address | undefined |
| tapAmount `indexed` | uint256 | undefined |
| multiplier `indexed` | uint256 | undefined |

### Paused

```solidity
event Paused(address account)
```



*Emitted when the pause is triggered by `account`.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| account  | address | undefined |

### Transfer

```solidity
event Transfer(address indexed from, address indexed to, uint256 indexed tokenId)
```



*Emitted when `tokenId` token is transferred from `from` to `to`.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| from `indexed` | address | undefined |
| to `indexed` | address | undefined |
| tokenId `indexed` | uint256 | undefined |

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

### AdvanceWeekFirst

```solidity
error AdvanceWeekFirst()
```






### CannotCalim

```solidity
error CannotCalim()
```






### Duplicate

```solidity
error Duplicate()
```






### InvalidShortString

```solidity
error InvalidShortString()
```






### LockNotAWeek

```solidity
error LockNotAWeek()
```






### LockNotExpired

```solidity
error LockNotExpired()
```






### NotAuthorized

```solidity
error NotAuthorized()
```






### NotValid

```solidity
error NotValid()
```






### Registered

```solidity
error Registered()
```






### StringTooLong

```solidity
error StringTooLong(string str)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| str | string | undefined |

### TokenLimitReached

```solidity
error TokenLimitReached()
```







