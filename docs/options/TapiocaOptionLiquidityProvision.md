# TapiocaOptionLiquidityProvision









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

### activeSingularities

```solidity
function activeSingularities(contract IERC20) external view returns (uint256 sglAssetID, uint256 totalDeposited, uint256 poolWeight)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | contract IERC20 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| sglAssetID | uint256 | undefined |
| totalDeposited | uint256 | undefined |
| poolWeight | uint256 | undefined |

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

### batch

```solidity
function batch(bytes[] calls, bool revertOnFail) external payable
```

Allows batched call to self (this contract).



#### Parameters

| Name | Type | Description |
|---|---|---|
| calls | bytes[] | An array of inputs for each call. |
| revertOnFail | bool | If True then reverts after a failed call and stops doing further calls. |

### claimOwnership

```solidity
function claimOwnership() external nonpayable
```

Needs to be called by `pendingOwner` to claim ownership.




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

### getLock

```solidity
function getLock(uint256 _tokenId) external view returns (struct LockPosition)
```

Returns the lock position of a given tOLP NFT and if it&#39;s active



#### Parameters

| Name | Type | Description |
|---|---|---|
| _tokenId | uint256 | tOLP NFT ID |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | LockPosition | undefined |

### getSingularities

```solidity
function getSingularities() external view returns (uint256[])
```

Returns the active singularity YieldBox ID markets




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256[] | undefined |

### getSingularityPools

```solidity
function getSingularityPools() external view returns (struct SingularityPool[])
```

Returns the active singularity pool data




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | SingularityPool[] | undefined |

### getTotalPoolDeposited

```solidity
function getTotalPoolDeposited(uint256 _sglAssetId) external view returns (uint256 shares, uint256 amount)
```

Returns the total amount of locked YieldBox shares for a given singularity market



#### Parameters

| Name | Type | Description |
|---|---|---|
| _sglAssetId | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| shares | uint256 | Amount of YieldBox shares locked |
| amount | uint256 | Amount of YieldBox shares locked converted in amount |

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

### isApprovedOrOwner

```solidity
function isApprovedOrOwner(address _spender, uint256 _tokenId) external view returns (bool)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _spender | address | undefined |
| _tokenId | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### lock

```solidity
function lock(address _to, contract IERC20 _singularity, uint128 _lockDuration, uint128 _ybShares) external nonpayable returns (uint256 tokenId)
```

Locks YieldBox shares for a given duration



#### Parameters

| Name | Type | Description |
|---|---|---|
| _to | address | Address to mint the tOLP NFT to |
| _singularity | contract IERC20 | Singularity market address |
| _lockDuration | uint128 | Duration of the lock |
| _ybShares | uint128 | Amount of YieldBox shares to lock |

#### Returns

| Name | Type | Description |
|---|---|---|
| tokenId | uint256 | The ID of the minted NFT |

### lockPositions

```solidity
function lockPositions(uint256) external view returns (uint128 sglAssetID, uint128 ybShares, uint128 lockTime, uint128 lockDuration)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| sglAssetID | uint128 | undefined |
| ybShares | uint128 | undefined |
| lockTime | uint128 | undefined |
| lockDuration | uint128 | undefined |

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

### registerSingularity

```solidity
function registerSingularity(contract IERC20 singularity, uint256 assetID, uint256 weight) external nonpayable
```

Registers a new singularity market



#### Parameters

| Name | Type | Description |
|---|---|---|
| singularity | contract IERC20 | Singularity market address |
| assetID | uint256 | YieldBox asset ID of the singularity market |
| weight | uint256 | Weight of the pool |

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

### setSGLPoolWEight

```solidity
function setSGLPoolWEight(contract IERC20 singularity, uint256 weight) external nonpayable
```

Sets the pool weight of a given singularity market



#### Parameters

| Name | Type | Description |
|---|---|---|
| singularity | contract IERC20 | Singularity market address |
| weight | uint256 | Weight of the pool |

### sglAssetIDToAddress

```solidity
function sglAssetIDToAddress(uint256) external view returns (contract IERC20)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract IERC20 | undefined |

### singularities

```solidity
function singularities(uint256) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

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

### tokenCounter

```solidity
function tokenCounter() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

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

### totalSingularityPoolWeights

```solidity
function totalSingularityPoolWeights() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

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

### unlock

```solidity
function unlock(uint256 _tokenId, contract IERC20 _singularity, address _to) external nonpayable
```

Unlocks tOLP tokens



#### Parameters

| Name | Type | Description |
|---|---|---|
| _tokenId | uint256 | ID of the position to unlock |
| _singularity | contract IERC20 | Singularity market address |
| _to | address | Address to send the tokens to |

### unregisterSingularity

```solidity
function unregisterSingularity(contract IERC20 singularity) external nonpayable
```

Un-registers a singularity market



#### Parameters

| Name | Type | Description |
|---|---|---|
| singularity | contract IERC20 | Singularity market address |

### yieldBox

```solidity
function yieldBox() external view returns (contract IYieldBox)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract IYieldBox | undefined |



## Events

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

### Burn

```solidity
event Burn(address indexed to, uint128 indexed sglAssetID, LockPosition lockPosition)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| to `indexed` | address | undefined |
| sglAssetID `indexed` | uint128 | undefined |
| lockPosition  | LockPosition | undefined |

### Mint

```solidity
event Mint(address indexed to, uint128 indexed sglAssetID, LockPosition lockPosition)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| to `indexed` | address | undefined |
| sglAssetID `indexed` | uint128 | undefined |
| lockPosition  | LockPosition | undefined |

### OwnershipTransferred

```solidity
event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| previousOwner `indexed` | address | undefined |
| newOwner `indexed` | address | undefined |

### Paused

```solidity
event Paused(address account)
```



*Emitted when the pause is triggered by `account`.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| account  | address | undefined |

### RegisterSingularity

```solidity
event RegisterSingularity(address indexed sgl, uint256 indexed assetID)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| sgl `indexed` | address | undefined |
| assetID `indexed` | uint256 | undefined |

### SetSGLPoolWeight

```solidity
event SetSGLPoolWeight(address indexed sgl, uint256 poolWeight)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| sgl `indexed` | address | undefined |
| poolWeight  | uint256 | undefined |

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

### UnregisterSingularity

```solidity
event UnregisterSingularity(address indexed sgl, uint256 indexed assetID)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| sgl `indexed` | address | undefined |
| assetID `indexed` | uint256 | undefined |

### UpdateTotalSingularityPoolWeights

```solidity
event UpdateTotalSingularityPoolWeights(uint256 totalSingularityPoolWeights)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| totalSingularityPoolWeights  | uint256 | undefined |



