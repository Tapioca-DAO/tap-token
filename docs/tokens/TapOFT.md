# TapOFT



> Tapioca OFT token

OFT compatible TAP token

*Latest size: 17.663  KiBEmissions calculator: https://www.desmos.com/calculator/1fa0zen2ut*

## Methods

### INCREASE_AMOUNT

```solidity
function INCREASE_AMOUNT() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### INITIAL_SUPPLY

```solidity
function INITIAL_SUPPLY() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### LOCK

```solidity
function LOCK() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### WEEK

```solidity
function WEEK() external view returns (uint256)
```

seconds in a week




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### a_param

```solidity
function a_param() external view returns (int256)
```

the a parameter used in the emission function; can be changed by governance

*formula: b(xe^(c-f(x))) where f(x)=x/a*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | int256 | undefined |

### allowance

```solidity
function allowance(address owner, address spender) external view returns (uint256)
```



*See {IERC20-allowance}.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| owner | address | undefined |
| spender | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### approve

```solidity
function approve(address spender, uint256 amount) external nonpayable returns (bool)
```



*See {IERC20-approve}. NOTE: If `amount` is the maximum `uint256`, the allowance is not updated on `transferFrom`. This is semantically equivalent to an infinite approval. Requirements: - `spender` cannot be the zero address.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| spender | address | undefined |
| amount | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### availableForWeek

```solidity
function availableForWeek(uint256 timestamp) external view returns (uint256)
```

returns available emissions for a specific timestamp



#### Parameters

| Name | Type | Description |
|---|---|---|
| timestamp | uint256 | the moment in time to emit for |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### b_param

```solidity
function b_param() external view returns (int256)
```

the b parameter used in the emission function; can be changed by governance

*formula: b(xe^(c-f(x))) where f(x)=x/a*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | int256 | undefined |

### balanceOf

```solidity
function balanceOf(address account) external view returns (uint256)
```



*See {IERC20-balanceOf}.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| account | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### c_param

```solidity
function c_param() external view returns (int256)
```

the c parameter used in the emission function; can be changed by governance

*formula: b(xe^(c-f(x))) where f(x)=x/a*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | int256 | undefined |

### circulatingSupply

```solidity
function circulatingSupply() external view returns (uint256)
```



*returns the circulating amount of tokens on current chain*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### decimals

```solidity
function decimals() external pure returns (uint8)
```

returns token&#39;s decimals




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint8 | undefined |

### decreaseAllowance

```solidity
function decreaseAllowance(address spender, uint256 subtractedValue) external nonpayable returns (bool)
```



*Atomically decreases the allowance granted to `spender` by the caller. This is an alternative to {approve} that can be used as a mitigation for problems described in {IERC20-approve}. Emits an {Approval} event indicating the updated allowance. Requirements: - `spender` cannot be the zero address. - `spender` must have allowance for the caller of at least `subtractedValue`.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| spender | address | undefined |
| subtractedValue | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

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

### emitForWeek

```solidity
function emitForWeek(uint256 timestamp) external nonpayable returns (uint256)
```

-- Write methods --returns the available emissions for a specific week

*formula: b(xe^(c-f(x))) where f(x)=x/a*

#### Parameters

| Name | Type | Description |
|---|---|---|
| timestamp | uint256 | the moment in time to emit for |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### estimateSendFee

```solidity
function estimateSendFee(uint16 _dstChainId, bytes _toAddress, uint256 _amount, bool _useZro, bytes _adapterParams) external view returns (uint256 nativeFee, uint256 zroFee)
```



*estimate send token `_tokenId` to (`_dstChainId`, `_toAddress`) _dstChainId - L0 defined chain id to send tokens too _toAddress - dynamic bytes array which contains the address to whom you are sending tokens to on the dstChain _amount - amount of the tokens to transfer _useZro - indicates to use zro to pay L0 fees _adapterParam - flexible bytes array to indicate messaging adapter services in L0*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _dstChainId | uint16 | undefined |
| _toAddress | bytes | undefined |
| _amount | uint256 | undefined |
| _useZro | bool | undefined |
| _adapterParams | bytes | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| nativeFee | uint256 | undefined |
| zroFee | uint256 | undefined |

### extractTAP

```solidity
function extractTAP(address _to, uint256 _amount) external nonpayable
```

extracts from the minted TAP



#### Parameters

| Name | Type | Description |
|---|---|---|
| _to | address | the receiver address |
| _amount | uint256 | TAP amount |

### failedMessages

```solidity
function failedMessages(uint16, bytes, uint64) external view returns (bytes32)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint16 | undefined |
| _1 | bytes | undefined |
| _2 | uint64 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes32 | undefined |

### forceResumeReceive

```solidity
function forceResumeReceive(uint16 _srcChainId, bytes _srcAddress) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _srcChainId | uint16 | undefined |
| _srcAddress | bytes | undefined |

### getConfig

```solidity
function getConfig(uint16 _version, uint16 _chainId, address, uint256 _configType) external view returns (bytes)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _version | uint16 | undefined |
| _chainId | uint16 | undefined |
| _2 | address | undefined |
| _configType | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes | undefined |

### getVotingPower

```solidity
function getVotingPower(uint256 _amount, uint256 _time, uint256 _action) external payable
```

lock TapOFT and get veTap on Optimism

*cannot be called on Optimism; use VeTap directly*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _amount | uint256 | the amount of TAP to lock for voting power |
| _time | uint256 | lock duration |
| _action | uint256 | undefined |

### governanceChainIdentifier

```solidity
function governanceChainIdentifier() external view returns (uint16)
```

LayerZero governance chain identifier




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint16 | undefined |

### increaseAllowance

```solidity
function increaseAllowance(address spender, uint256 addedValue) external nonpayable returns (bool)
```



*Atomically increases the allowance granted to `spender` by the caller. This is an alternative to {approve} that can be used as a mitigation for problems described in {IERC20-approve}. Emits an {Approval} event indicating the updated allowance. Requirements: - `spender` cannot be the zero address.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| spender | address | undefined |
| addedValue | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### isTrustedRemote

```solidity
function isTrustedRemote(uint16 _srcChainId, bytes _srcAddress) external view returns (bool)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _srcChainId | uint16 | undefined |
| _srcAddress | bytes | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### lzEndpoint

```solidity
function lzEndpoint() external view returns (contract ILayerZeroEndpoint)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract ILayerZeroEndpoint | undefined |

### lzReceive

```solidity
function lzReceive(uint16 _srcChainId, bytes _srcAddress, uint64 _nonce, bytes _payload) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _srcChainId | uint16 | undefined |
| _srcAddress | bytes | undefined |
| _nonce | uint64 | undefined |
| _payload | bytes | undefined |

### mintedInWeek

```solidity
function mintedInWeek(int256) external view returns (uint256)
```

returns the amount minted for a specific week

*week is computed using (timestamp - emissionStartTime) / WEEK*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | int256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### minter

```solidity
function minter() external view returns (address)
```

returns the minter address




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### name

```solidity
function name() external view returns (string)
```



*Returns the name of the token.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | string | undefined |

### nonblockingLzReceive

```solidity
function nonblockingLzReceive(uint16 _srcChainId, bytes _srcAddress, uint64 _nonce, bytes _payload) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _srcChainId | uint16 | undefined |
| _srcAddress | bytes | undefined |
| _nonce | uint64 | undefined |
| _payload | bytes | undefined |

### owner

```solidity
function owner() external view returns (address)
```



*Returns the address of the current owner.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### pauseSendTokens

```solidity
function pauseSendTokens(bool pause) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| pause | bool | undefined |

### paused

```solidity
function paused() external view returns (bool)
```



*Returns true if the contract is paused, and false otherwise.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### removeTAP

```solidity
function removeTAP(address _from, uint256 _amount) external nonpayable
```

burns TAP



#### Parameters

| Name | Type | Description |
|---|---|---|
| _from | address | the address to burn from |
| _amount | uint256 | TAP amount |

### renounceOwnership

```solidity
function renounceOwnership() external nonpayable
```



*Leaves the contract without owner. It will not be possible to call `onlyOwner` functions anymore. Can only be called by the current owner. NOTE: Renouncing ownership will leave the contract without an owner, thereby removing any functionality that is only available to the owner.*


### retryMessage

```solidity
function retryMessage(uint16 _srcChainId, bytes _srcAddress, uint64 _nonce, bytes _payload) external payable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _srcChainId | uint16 | undefined |
| _srcAddress | bytes | undefined |
| _nonce | uint64 | undefined |
| _payload | bytes | undefined |

### sendFrom

```solidity
function sendFrom(address _from, uint16 _dstChainId, bytes _toAddress, uint256 _amount, address payable _refundAddress, address _zroPaymentAddress, bytes _adapterParams) external payable
```



*send `_amount` amount of token to (`_dstChainId`, `_toAddress`) from `_from` `_from` the owner of token `_dstChainId` the destination chain identifier `_toAddress` can be any size depending on the `dstChainId`. `_amount` the quantity of tokens in wei `_refundAddress` the address LayerZero refunds if too much message fee is sent `_zroPaymentAddress` set to address(0x0) if not paying in ZRO (LayerZero Token) `_adapterParams` is a flexible bytes array to indicate messaging adapter services*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _from | address | undefined |
| _dstChainId | uint16 | undefined |
| _toAddress | bytes | undefined |
| _amount | uint256 | undefined |
| _refundAddress | address payable | undefined |
| _zroPaymentAddress | address | undefined |
| _adapterParams | bytes | undefined |

### setAParam

```solidity
function setAParam(int256 val) external nonpayable
```

sets a new value for parameter



#### Parameters

| Name | Type | Description |
|---|---|---|
| val | int256 | the new value |

### setBParam

```solidity
function setBParam(int256 val) external nonpayable
```

sets a new value for parameter



#### Parameters

| Name | Type | Description |
|---|---|---|
| val | int256 | the new value |

### setCParam

```solidity
function setCParam(int256 val) external nonpayable
```

sets a new value for parameter



#### Parameters

| Name | Type | Description |
|---|---|---|
| val | int256 | the new value |

### setConfig

```solidity
function setConfig(uint16 _version, uint16 _chainId, uint256 _configType, bytes _config) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _version | uint16 | undefined |
| _chainId | uint16 | undefined |
| _configType | uint256 | undefined |
| _config | bytes | undefined |

### setGovernanceChainIdentifier

```solidity
function setGovernanceChainIdentifier(uint16 _identifier) external nonpayable
```

-- Onwer methods --sets the governance chain identifier



#### Parameters

| Name | Type | Description |
|---|---|---|
| _identifier | uint16 | LayerZero chain identifier |

### setMinter

```solidity
function setMinter(address _minter) external nonpayable
```

sets a new minter address



#### Parameters

| Name | Type | Description |
|---|---|---|
| _minter | address | the new address |

### setReceiveVersion

```solidity
function setReceiveVersion(uint16 _version) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _version | uint16 | undefined |

### setSendVersion

```solidity
function setSendVersion(uint16 _version) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _version | uint16 | undefined |

### setTrustedRemote

```solidity
function setTrustedRemote(uint16 _srcChainId, bytes _srcAddress) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _srcChainId | uint16 | undefined |
| _srcAddress | bytes | undefined |

### setVeTap

```solidity
function setVeTap(address addr) external nonpayable
```

sets the VotingEscrow address



#### Parameters

| Name | Type | Description |
|---|---|---|
| addr | address | the VotingEscrow address |

### supportsInterface

```solidity
function supportsInterface(bytes4 interfaceId) external view returns (bool)
```





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



*Returns the symbol of the token, usually a shorter version of the name.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | string | undefined |

### totalSupply

```solidity
function totalSupply() external view returns (uint256)
```



*See {IERC20-totalSupply}.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### transfer

```solidity
function transfer(address to, uint256 amount) external nonpayable returns (bool)
```



*See {IERC20-transfer}. Requirements: - `to` cannot be the zero address. - the caller must have a balance of at least `amount`.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| to | address | undefined |
| amount | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### transferFrom

```solidity
function transferFrom(address from, address to, uint256 amount) external nonpayable returns (bool)
```



*See {IERC20-transferFrom}. Emits an {Approval} event indicating the updated allowance. This is not required by the EIP. See the note at the beginning of {ERC20}. NOTE: Does not update the allowance if the current allowance is the maximum `uint256`. Requirements: - `from` and `to` cannot be the zero address. - `from` must have a balance of at least `amount`. - the caller must have allowance for ``from``&#39;s tokens of at least `amount`.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| from | address | undefined |
| to | address | undefined |
| amount | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### transferOwnership

```solidity
function transferOwnership(address newOwner) external nonpayable
```



*Transfers ownership of the contract to a new account (`newOwner`). Can only be called by the current owner.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| newOwner | address | undefined |

### trustedRemoteLookup

```solidity
function trustedRemoteLookup(uint16) external view returns (bytes)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint16 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes | undefined |

### veTap

```solidity
function veTap() external view returns (address)
```

returns the voting escrow address

*veTap is deployed only on Optimism*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |



## Events

### AParamUpdated

```solidity
event AParamUpdated(int256 _old, int256 _new)
```

event emitted when the A parameter of the emission formula is updated



#### Parameters

| Name | Type | Description |
|---|---|---|
| _old  | int256 | undefined |
| _new  | int256 | undefined |

### Approval

```solidity
event Approval(address indexed owner, address indexed spender, uint256 value)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| owner `indexed` | address | undefined |
| spender `indexed` | address | undefined |
| value  | uint256 | undefined |

### BParamUpdated

```solidity
event BParamUpdated(int256 _old, int256 _new)
```

event emitted when the B parameter of the emission formula is updated



#### Parameters

| Name | Type | Description |
|---|---|---|
| _old  | int256 | undefined |
| _new  | int256 | undefined |

### Burned

```solidity
event Burned(address indexed _by, address indexed _from, uint256 _amount)
```

event emitted when new TAP is burned



#### Parameters

| Name | Type | Description |
|---|---|---|
| _by `indexed` | address | undefined |
| _from `indexed` | address | undefined |
| _amount  | uint256 | undefined |

### CParamUpdated

```solidity
event CParamUpdated(int256 _old, int256 _new)
```

event emitted when the C parameter of the emission formula is updated



#### Parameters

| Name | Type | Description |
|---|---|---|
| _old  | int256 | undefined |
| _new  | int256 | undefined |

### GovernanceChainIdentifierUpdated

```solidity
event GovernanceChainIdentifierUpdated(uint16 _old, uint16 _new)
```

event emitted when the governance chain identifier is updated



#### Parameters

| Name | Type | Description |
|---|---|---|
| _old  | uint16 | undefined |
| _new  | uint16 | undefined |

### IncreasedVeAmount

```solidity
event IncreasedVeAmount(address indexed forAddr, uint256 amount)
```

event emitted when TAP amount from veTap is increased



#### Parameters

| Name | Type | Description |
|---|---|---|
| forAddr `indexed` | address | undefined |
| amount  | uint256 | undefined |

### MessageFailed

```solidity
event MessageFailed(uint16 _srcChainId, bytes _srcAddress, uint64 _nonce, bytes _payload)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _srcChainId  | uint16 | undefined |
| _srcAddress  | bytes | undefined |
| _nonce  | uint64 | undefined |
| _payload  | bytes | undefined |

### Minted

```solidity
event Minted(address indexed _by, address indexed _to, uint256 _amount)
```

event emitted when new TAP is minted



#### Parameters

| Name | Type | Description |
|---|---|---|
| _by `indexed` | address | undefined |
| _to `indexed` | address | undefined |
| _amount  | uint256 | undefined |

### MinterUpdated

```solidity
event MinterUpdated(address indexed _old, address indexed _new)
```

event emitted when a new minter is set



#### Parameters

| Name | Type | Description |
|---|---|---|
| _old `indexed` | address | undefined |
| _new `indexed` | address | undefined |

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





#### Parameters

| Name | Type | Description |
|---|---|---|
| account  | address | undefined |

### ReceiveFromChain

```solidity
event ReceiveFromChain(uint16 indexed _srcChainId, bytes indexed _srcAddress, address indexed _toAddress, uint256 _amount, uint64 _nonce)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _srcChainId `indexed` | uint16 | undefined |
| _srcAddress `indexed` | bytes | undefined |
| _toAddress `indexed` | address | undefined |
| _amount  | uint256 | undefined |
| _nonce  | uint64 | undefined |

### SendToChain

```solidity
event SendToChain(address indexed _sender, uint16 indexed _dstChainId, bytes indexed _toAddress, uint256 _amount, uint64 _nonce)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _sender `indexed` | address | undefined |
| _dstChainId `indexed` | uint16 | undefined |
| _toAddress `indexed` | bytes | undefined |
| _amount  | uint256 | undefined |
| _nonce  | uint64 | undefined |

### SetTrustedRemote

```solidity
event SetTrustedRemote(uint16 _srcChainId, bytes _srcAddress)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _srcChainId  | uint16 | undefined |
| _srcAddress  | bytes | undefined |

### Transfer

```solidity
event Transfer(address indexed from, address indexed to, uint256 value)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| from `indexed` | address | undefined |
| to `indexed` | address | undefined |
| value  | uint256 | undefined |

### Unpaused

```solidity
event Unpaused(address account)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| account  | address | undefined |

### UpdateMiningParameters

```solidity
event UpdateMiningParameters(uint256 _blockTimestmap, uint256 _rate, uint256 _startEpochSupply)
```

event emitted when mining parameters are updated



#### Parameters

| Name | Type | Description |
|---|---|---|
| _blockTimestmap  | uint256 | undefined |
| _rate  | uint256 | undefined |
| _startEpochSupply  | uint256 | undefined |

### VeLockedFor

```solidity
event VeLockedFor(address indexed forAddr, uint256 amount, uint256 time)
```

event emitted when TAP is locked for voting



#### Parameters

| Name | Type | Description |
|---|---|---|
| forAddr `indexed` | address | undefined |
| amount  | uint256 | undefined |
| time  | uint256 | undefined |

### VeTapUpdated

```solidity
event VeTapUpdated(address indexed _old, address indexed _new)
```

event emitted when veTap address is updated



#### Parameters

| Name | Type | Description |
|---|---|---|
| _old `indexed` | address | undefined |
| _new `indexed` | address | undefined |



## Errors

### PRBMathSD59x18__DivInputTooSmall

```solidity
error PRBMathSD59x18__DivInputTooSmall()
```

Emitted when one of the inputs is MIN_SD59x18.




### PRBMathSD59x18__DivOverflow

```solidity
error PRBMathSD59x18__DivOverflow(uint256 rAbs)
```

Emitted when one of the intermediary unsigned results overflows SD59x18.



#### Parameters

| Name | Type | Description |
|---|---|---|
| rAbs | uint256 | undefined |

### PRBMathSD59x18__Exp2InputTooBig

```solidity
error PRBMathSD59x18__Exp2InputTooBig(int256 x)
```

Emitted when the input is greater than 192.



#### Parameters

| Name | Type | Description |
|---|---|---|
| x | int256 | undefined |

### PRBMathSD59x18__FromIntOverflow

```solidity
error PRBMathSD59x18__FromIntOverflow(int256 x)
```

Emitted when converting a basic integer to the fixed-point format overflows SD59x18.



#### Parameters

| Name | Type | Description |
|---|---|---|
| x | int256 | undefined |

### PRBMathSD59x18__FromIntUnderflow

```solidity
error PRBMathSD59x18__FromIntUnderflow(int256 x)
```

Emitted when converting a basic integer to the fixed-point format underflows SD59x18.



#### Parameters

| Name | Type | Description |
|---|---|---|
| x | int256 | undefined |

### PRBMathSD59x18__LogInputTooSmall

```solidity
error PRBMathSD59x18__LogInputTooSmall(int256 x)
```

Emitted when the input is less than or equal to zero.



#### Parameters

| Name | Type | Description |
|---|---|---|
| x | int256 | undefined |

### PRBMathSD59x18__MulInputTooSmall

```solidity
error PRBMathSD59x18__MulInputTooSmall()
```

Emitted when one of the inputs is MIN_SD59x18.




### PRBMathSD59x18__MulOverflow

```solidity
error PRBMathSD59x18__MulOverflow(uint256 rAbs)
```

Emitted when the intermediary absolute result overflows SD59x18.



#### Parameters

| Name | Type | Description |
|---|---|---|
| rAbs | uint256 | undefined |

### PRBMath__MulDivFixedPointOverflow

```solidity
error PRBMath__MulDivFixedPointOverflow(uint256 prod1)
```

Emitted when the result overflows uint256.



#### Parameters

| Name | Type | Description |
|---|---|---|
| prod1 | uint256 | undefined |

### PRBMath__MulDivOverflow

```solidity
error PRBMath__MulDivOverflow(uint256 prod1, uint256 denominator)
```

Emitted when the result overflows uint256.



#### Parameters

| Name | Type | Description |
|---|---|---|
| prod1 | uint256 | undefined |
| denominator | uint256 | undefined |


