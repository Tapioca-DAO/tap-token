# TapOFT



> Tapioca OFT token

OFT compatible TAP token

*Latest size: 17.663  KiBEmissions E(x)= E(x-1) - E(x-1) * D with E being total supply a x week, and D the initial decay rate*

## Methods

### DEFAULT_PAYLOAD_SIZE_LIMIT

```solidity
function DEFAULT_PAYLOAD_SIZE_LIMIT() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### DOMAIN_SEPARATOR

```solidity
function DOMAIN_SEPARATOR() external view returns (bytes32)
```



*See {IERC20Permit-DOMAIN_SEPARATOR}.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes32 | undefined |

### INITIAL_SUPPLY

```solidity
function INITIAL_SUPPLY() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### NO_EXTRA_GAS

```solidity
function NO_EXTRA_GAS() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### PT_SEND

```solidity
function PT_SEND() external view returns (uint8)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint8 | undefined |

### PT_SEND_AND_CALL

```solidity
function PT_SEND_AND_CALL() external view returns (uint8)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint8 | undefined |

### WEEK

```solidity
function WEEK() external view returns (uint256)
```

seconds in a week




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

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

### callOnOFTReceived

```solidity
function callOnOFTReceived(uint16 _srcChainId, bytes _srcAddress, uint64 _nonce, bytes32 _from, address _to, uint256 _amount, bytes _payload, uint256 _gasForCall) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _srcChainId | uint16 | undefined |
| _srcAddress | bytes | undefined |
| _nonce | uint64 | undefined |
| _from | bytes32 | undefined |
| _to | address | undefined |
| _amount | uint256 | undefined |
| _payload | bytes | undefined |
| _gasForCall | uint256 | undefined |

### circulatingSupply

```solidity
function circulatingSupply() external view returns (uint256)
```



*returns the circulating amount of tokens on current chain*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### claimRewards

```solidity
function claimRewards(address to, uint256 tokenID, address[] rewardTokens, uint16 lzDstChainId, address zroPaymentAddress, bytes adapterParams, IRewardClaimSendFromParams[] rewardClaimSendParams) external payable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| to | address | undefined |
| tokenID | uint256 | undefined |
| rewardTokens | address[] | undefined |
| lzDstChainId | uint16 | undefined |
| zroPaymentAddress | address | undefined |
| adapterParams | bytes | undefined |
| rewardClaimSendParams | IRewardClaimSendFromParams[] | undefined |

### creditedPackets

```solidity
function creditedPackets(uint16, bytes, uint64) external view returns (bool)
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
| _0 | bool | undefined |

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

### dso_supply

```solidity
function dso_supply() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### emissionForWeek

```solidity
function emissionForWeek(uint256) external view returns (uint256)
```

returns the amount of emitted TAP for a specific week

*week is computed using (timestamp - emissionStartTime) / WEEK*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

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
function emitForWeek() external nonpayable returns (uint256)
```

-- Write methods --Emit the TAP for the current week. Follow the emission function. If there are unclaimed emissions from the previous week, they are added to the current week. If there are some TAP in the contract, use it as boosted TAP.




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | the emitted amount |

### estimateSendAndCallFee

```solidity
function estimateSendAndCallFee(uint16 _dstChainId, bytes32 _toAddress, uint256 _amount, bytes _payload, uint64 _dstGasForCall, bool _useZro, bytes _adapterParams) external view returns (uint256 nativeFee, uint256 zroFee)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _dstChainId | uint16 | undefined |
| _toAddress | bytes32 | undefined |
| _amount | uint256 | undefined |
| _payload | bytes | undefined |
| _dstGasForCall | uint64 | undefined |
| _useZro | bool | undefined |
| _adapterParams | bytes | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| nativeFee | uint256 | undefined |
| zroFee | uint256 | undefined |

### estimateSendFee

```solidity
function estimateSendFee(uint16 _dstChainId, bytes32 _toAddress, uint256 _amount, bool _useZro, bytes _adapterParams) external view returns (uint256 nativeFee, uint256 zroFee)
```



*estimate send token `_tokenId` to (`_dstChainId`, `_toAddress`) _dstChainId - L0 defined chain id to send tokens too _toAddress - dynamic bytes array which contains the address to whom you are sending tokens to on the dstChain _amount - amount of the tokens to transfer _useZro - indicates to use zro to pay L0 fees _adapterParam - flexible bytes array to indicate messaging adapter services in L0*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _dstChainId | uint16 | undefined |
| _toAddress | bytes32 | undefined |
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
| _to | address | Address to send the minted TAP to |
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

### getCurrentWeek

```solidity
function getCurrentWeek() external view returns (uint256)
```

Returns the current week




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### getCurrentWeekEmission

```solidity
function getCurrentWeekEmission() external view returns (uint256)
```

Returns the current week emission




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### getTrustedRemoteAddress

```solidity
function getTrustedRemoteAddress(uint16 _remoteChainId) external view returns (bytes)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _remoteChainId | uint16 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes | undefined |

### governanceChainIdentifier

```solidity
function governanceChainIdentifier() external view returns (uint256)
```

LayerZero governance chain identifier




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

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

### lockTwTapPosition

```solidity
function lockTwTapPosition(address to, uint256 amount, uint256 duration, uint16 lzDstChainId, address zroPaymentAddress, bytes adapterParams) external payable
```

Opens a twTAP by participating in twAML.



#### Parameters

| Name | Type | Description |
|---|---|---|
| to | address | The address to add the twTAP position to. |
| amount | uint256 | The amount to add. |
| duration | uint256 | undefined |
| lzDstChainId | uint16 | The destination chain id. |
| zroPaymentAddress | address | The address to send the ZRO payment to. |
| adapterParams | bytes | The adapter params. |

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

### minDstGasLookup

```solidity
function minDstGasLookup(uint16, uint16) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint16 | undefined |
| _1 | uint16 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### mintedInWeek

```solidity
function mintedInWeek(uint256) external view returns (uint256)
```

returns the amount minted for a specific week

*week is computed using (timestamp - emissionStartTime) / WEEK*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

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



*Returns the address of the current owner.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### paused

```solidity
function paused() external view returns (bool)
```

returns the pause state of the contract




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### payloadSizeLimitLookup

```solidity
function payloadSizeLimitLookup(uint16) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint16 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### permit

```solidity
function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external nonpayable
```



*See {IERC20Permit-permit}.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| owner | address | undefined |
| spender | address | undefined |
| value | uint256 | undefined |
| deadline | uint256 | undefined |
| v | uint8 | undefined |
| r | bytes32 | undefined |
| s | bytes32 | undefined |

### precrime

```solidity
function precrime() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### removeTAP

```solidity
function removeTAP(uint256 _amount) external nonpayable
```

burns TAP



#### Parameters

| Name | Type | Description |
|---|---|---|
| _amount | uint256 | TAP amount |

### renounceOwnership

```solidity
function renounceOwnership() external nonpayable
```



*Leaves the contract without owner. It will not be possible to call `onlyOwner` functions anymore. Can only be called by the current owner. NOTE: Renouncing ownership will leave the contract without an owner, thereby removing any functionality that is only available to the owner.*


### rescueEth

```solidity
function rescueEth(uint256 amount, address to) external nonpayable
```

rescues unused ETH from the contract



#### Parameters

| Name | Type | Description |
|---|---|---|
| amount | uint256 | the amount to rescue |
| to | address | the recipient |

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

### sendAndCall

```solidity
function sendAndCall(address _from, uint16 _dstChainId, bytes32 _toAddress, uint256 _amount, bytes _payload, uint64 _dstGasForCall, ICommonOFT.LzCallParams _callParams) external payable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _from | address | undefined |
| _dstChainId | uint16 | undefined |
| _toAddress | bytes32 | undefined |
| _amount | uint256 | undefined |
| _payload | bytes | undefined |
| _dstGasForCall | uint64 | undefined |
| _callParams | ICommonOFT.LzCallParams | undefined |

### sendFrom

```solidity
function sendFrom(address _from, uint16 _dstChainId, bytes32 _toAddress, uint256 _amount, ICommonOFT.LzCallParams _callParams) external payable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _from | address | undefined |
| _dstChainId | uint16 | undefined |
| _toAddress | bytes32 | undefined |
| _amount | uint256 | undefined |
| _callParams | ICommonOFT.LzCallParams | undefined |

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
function setGovernanceChainIdentifier(uint256 _identifier) external nonpayable
```

-- Owner methods --sets the governance chain identifier



#### Parameters

| Name | Type | Description |
|---|---|---|
| _identifier | uint256 | LayerZero chain identifier |

### setMinDstGas

```solidity
function setMinDstGas(uint16 _dstChainId, uint16 _packetType, uint256 _minGas) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _dstChainId | uint16 | undefined |
| _packetType | uint16 | undefined |
| _minGas | uint256 | undefined |

### setMinter

```solidity
function setMinter(address _minter) external nonpayable
```

sets a new minter address



#### Parameters

| Name | Type | Description |
|---|---|---|
| _minter | address | the new address |

### setPayloadSizeLimit

```solidity
function setPayloadSizeLimit(uint16 _dstChainId, uint256 _size) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _dstChainId | uint16 | undefined |
| _size | uint256 | undefined |

### setPrecrime

```solidity
function setPrecrime(address _precrime) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _precrime | address | undefined |

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
function setTrustedRemote(uint16 _srcChainId, bytes _path) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _srcChainId | uint16 | undefined |
| _path | bytes | undefined |

### setTrustedRemoteAddress

```solidity
function setTrustedRemoteAddress(uint16 _remoteChainId, bytes _remoteAddress) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _remoteChainId | uint16 | undefined |
| _remoteAddress | bytes | undefined |

### setTwTap

```solidity
function setTwTap(address _twTap) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _twTap | address | undefined |

### setUseCustomAdapterParams

```solidity
function setUseCustomAdapterParams(bool _useCustomAdapterParams) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _useCustomAdapterParams | bool | undefined |

### sharedDecimals

```solidity
function sharedDecimals() external view returns (uint8)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint8 | undefined |

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

### token

```solidity
function token() external view returns (address)
```



*returns the address of the ERC20 token*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

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

### twTap

```solidity
function twTap() external view returns (contract TwTAP)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract TwTAP | undefined |

### unlockTwTapPosition

```solidity
function unlockTwTapPosition(address to, uint256 tokenID, uint16 lzDstChainId, address zroPaymentAddress, bytes adapterParams, ICommonOFT.LzCallParams twTapSendBackAdapterParams) external payable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| to | address | undefined |
| tokenID | uint256 | undefined |
| lzDstChainId | uint16 | undefined |
| zroPaymentAddress | address | undefined |
| adapterParams | bytes | undefined |
| twTapSendBackAdapterParams | ICommonOFT.LzCallParams | undefined |

### updatePause

```solidity
function updatePause(bool val) external nonpayable
```

updates the pause state of the contract



#### Parameters

| Name | Type | Description |
|---|---|---|
| val | bool | the new value |

### useCustomAdapterParams

```solidity
function useCustomAdapterParams() external view returns (bool)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |



## Events

### Approval

```solidity
event Approval(address indexed owner, address indexed spender, uint256 value)
```



*Emitted when the allowance of a `spender` for an `owner` is set by a call to {approve}. `value` is the new allowance.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| owner `indexed` | address | undefined |
| spender `indexed` | address | undefined |
| value  | uint256 | undefined |

### BoostedTAP

```solidity
event BoostedTAP(uint256 indexed _amount)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _amount `indexed` | uint256 | undefined |

### Burned

```solidity
event Burned(address indexed _from, uint256 indexed _amount)
```

event emitted when new TAP is burned



#### Parameters

| Name | Type | Description |
|---|---|---|
| _from `indexed` | address | undefined |
| _amount `indexed` | uint256 | undefined |

### CallFailedBytes

```solidity
event CallFailedBytes(uint16 indexed _srcChainId, bytes indexed _payload, bytes indexed _reason)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _srcChainId `indexed` | uint16 | undefined |
| _payload `indexed` | bytes | undefined |
| _reason `indexed` | bytes | undefined |

### CallFailedStr

```solidity
event CallFailedStr(uint16 indexed _srcChainId, bytes indexed _payload, string indexed _reason)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _srcChainId `indexed` | uint16 | undefined |
| _payload `indexed` | bytes | undefined |
| _reason `indexed` | string | undefined |

### CallOFTReceivedSuccess

```solidity
event CallOFTReceivedSuccess(uint16 indexed _srcChainId, bytes _srcAddress, uint64 _nonce, bytes32 _hash)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _srcChainId `indexed` | uint16 | undefined |
| _srcAddress  | bytes | undefined |
| _nonce  | uint64 | undefined |
| _hash  | bytes32 | undefined |

### Emitted

```solidity
event Emitted(uint256 indexed week, uint256 indexed amount)
```

event emitted when a new emission is called



#### Parameters

| Name | Type | Description |
|---|---|---|
| week `indexed` | uint256 | undefined |
| amount `indexed` | uint256 | undefined |

### GovernanceChainIdentifierUpdated

```solidity
event GovernanceChainIdentifierUpdated(uint256 indexed _old, uint256 indexed _new)
```

event emitted when the governance chain identifier is updated



#### Parameters

| Name | Type | Description |
|---|---|---|
| _old `indexed` | uint256 | undefined |
| _new `indexed` | uint256 | undefined |

### MessageFailed

```solidity
event MessageFailed(uint16 _srcChainId, bytes _srcAddress, uint64 _nonce, bytes _payload, bytes _reason)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _srcChainId  | uint16 | undefined |
| _srcAddress  | bytes | undefined |
| _nonce  | uint64 | undefined |
| _payload  | bytes | undefined |
| _reason  | bytes | undefined |

### Minted

```solidity
event Minted(address indexed _by, address indexed _to, uint256 indexed _amount)
```

event emitted when new TAP is minted



#### Parameters

| Name | Type | Description |
|---|---|---|
| _by `indexed` | address | undefined |
| _to `indexed` | address | undefined |
| _amount `indexed` | uint256 | undefined |

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

### NonContractAddress

```solidity
event NonContractAddress(address _address)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _address  | address | undefined |

### OwnershipTransferred

```solidity
event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| previousOwner `indexed` | address | undefined |
| newOwner `indexed` | address | undefined |

### PausedUpdated

```solidity
event PausedUpdated(bool indexed oldState, bool indexed newState)
```

event emitted when pause state is changed



#### Parameters

| Name | Type | Description |
|---|---|---|
| oldState `indexed` | bool | undefined |
| newState `indexed` | bool | undefined |

### ReceiveFromChain

```solidity
event ReceiveFromChain(uint16 indexed _srcChainId, address indexed _to, uint256 _amount)
```



*Emitted when `_amount` tokens are received from `_srcChainId` into the `_toAddress` on the local chain. `_nonce` is the inbound nonce.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _srcChainId `indexed` | uint16 | undefined |
| _to `indexed` | address | undefined |
| _amount  | uint256 | undefined |

### RetryMessageSuccess

```solidity
event RetryMessageSuccess(uint16 _srcChainId, bytes _srcAddress, uint64 _nonce, bytes32 _payloadHash)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _srcChainId  | uint16 | undefined |
| _srcAddress  | bytes | undefined |
| _nonce  | uint64 | undefined |
| _payloadHash  | bytes32 | undefined |

### SendToChain

```solidity
event SendToChain(uint16 indexed _dstChainId, address indexed _from, bytes32 indexed _toAddress, uint256 _amount)
```



*Emitted when `_amount` tokens are moved from the `_sender` to (`_dstChainId`, `_toAddress`) `_nonce` is the outbound nonce*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _dstChainId `indexed` | uint16 | undefined |
| _from `indexed` | address | undefined |
| _toAddress `indexed` | bytes32 | undefined |
| _amount  | uint256 | undefined |

### SetMinDstGas

```solidity
event SetMinDstGas(uint16 _dstChainId, uint16 _type, uint256 _minDstGas)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _dstChainId  | uint16 | undefined |
| _type  | uint16 | undefined |
| _minDstGas  | uint256 | undefined |

### SetPrecrime

```solidity
event SetPrecrime(address precrime)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| precrime  | address | undefined |

### SetTrustedRemote

```solidity
event SetTrustedRemote(uint16 _remoteChainId, bytes _path)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _remoteChainId  | uint16 | undefined |
| _path  | bytes | undefined |

### SetTrustedRemoteAddress

```solidity
event SetTrustedRemoteAddress(uint16 _remoteChainId, bytes _remoteAddress)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _remoteChainId  | uint16 | undefined |
| _remoteAddress  | bytes | undefined |

### SetUseCustomAdapterParams

```solidity
event SetUseCustomAdapterParams(bool _useCustomAdapterParams)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _useCustomAdapterParams  | bool | undefined |

### Transfer

```solidity
event Transfer(address indexed from, address indexed to, uint256 value)
```



*Emitted when `value` tokens are moved from one account (`from`) to another (`to`). Note that `value` may be zero.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| from `indexed` | address | undefined |
| to `indexed` | address | undefined |
| value  | uint256 | undefined |



## Errors

### AllowanceNotValid

```solidity
error AllowanceNotValid()
```






### Failed

```solidity
error Failed()
```






### LengthMismatch

```solidity
error LengthMismatch()
```






### NotAuthorized

```solidity
error NotAuthorized()
```






### NotValid

```solidity
error NotValid()
```






### OnlyMinter

```solidity
error OnlyMinter()
```






### Paused

```solidity
error Paused()
```






### SupplyNotValid

```solidity
error SupplyNotValid()
```






### TooSmall

```solidity
error TooSmall()
```







